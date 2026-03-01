import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:frontend_desktop/models/appointment_model.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';

class AppointmentController extends GetxController {
  final _patientService = PatientService();
  final _doctorService = DoctorService();
  final _cacheService = CacheService();

  final RxList<AppointmentModel> appointments = <AppointmentModel>[].obs;
  final RxList<AppointmentModel> primaryAppointments = <AppointmentModel>[].obs;
  final RxList<AppointmentModel> secondaryAppointments =
      <AppointmentModel>[].obs;
  final RxBool isLoading = false.obs;

  // ⭐ متغيرات Pagination - بنفس طريقة eversheen
  var currentPage = 1;
  var isLoadingMoreAppointments = false.obs;
  var hasMoreAppointments = true.obs;
  final int pageLimit = 25; // 25 موعد في كل مرة (بدلاً من 10 في eversheen)
  
  // متغيرات لتتبع الفلتر الحالي
  String? _currentFilter; // 'اليوم', 'هذا الشهر', 'المتأخرون', 'تصفية مخصصة'
  DateTime? _customFilterStart;
  DateTime? _customFilterEnd;

  /// Cache patient appointments by patientId so leaving the patient file
  /// (and loading doctor appointments) doesn't wipe the patient's view.
  final RxMap<String, List<AppointmentModel>> patientAppointmentsCache =
      <String, List<AppointmentModel>>{}.obs;

  // Prevent request storms when ensure-loading from build() repeatedly
  final Set<String> _inFlightPatientAppointments = <String>{};
  final Set<String> _loadedOncePatientAppointments = <String>{};

  AppointmentModel _withScheduledAt(
    AppointmentModel appointment,
    DateTime scheduledAt,
  ) {
    return AppointmentModel(
      id: appointment.id,
      patientId: appointment.patientId,
      patientName: appointment.patientName,
      patientPhone: appointment.patientPhone,
      doctorId: appointment.doctorId,
      doctorName: appointment.doctorName,
      date: scheduledAt,
      time:
          '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}',
      status: appointment.status,
      notes: appointment.notes,
      imagePath: appointment.imagePath,
      imagePaths: appointment.imagePaths,
    );
  }

  AppointmentModel _normalizeServerAppointmentTime(
    AppointmentModel appointment,
    DateTime scheduledAt,
  ) {
    final adjusted =
        appointment.date.subtract(DateTime.now().timeZoneOffset);
    if (_isSameSlot(adjusted, scheduledAt)) {
      return _withScheduledAt(appointment, scheduledAt);
    }
    return appointment;
  }

  bool _isSameSlot(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  List<AppointmentModel> getCachedPatientAppointments(String patientId) {
    return patientAppointmentsCache[patientId] ?? const <AppointmentModel>[];
  }

  /// Ensures we have loaded appointments for this patient at least once.
  /// Safe to call from build/Obx without spamming the backend.
  void ensurePatientAppointmentsLoadedById(String patientId) {
    if (patientId.isEmpty) return;
    if (_loadedOncePatientAppointments.contains(patientId) ||
        _inFlightPatientAppointments.contains(patientId)) {
      return;
    }

    _inFlightPatientAppointments.add(patientId);
    // Fire and forget; UI will react via Rx updates
    loadPatientAppointmentsById(patientId).whenComplete(() {
      _inFlightPatientAppointments.remove(patientId);
      _loadedOncePatientAppointments.add(patientId);
    });
  }

  // جلب مواعيد المريض أو جميع المواعيد للاستقبال
  Future<void> loadPatientAppointments() async {
    try {
      print('📅 [AppointmentController] loadPatientAppointments called');
      isLoading.value = true;

      // 1) محاولة التحميل من الكاش أولاً (Hive) - بنفس طريقة eversheen
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;
      
      final cachedAppointments = _cacheService.getAllAppointments();
      if (cachedAppointments.isNotEmpty) {
        if (userType == 'receptionist') {
          appointments.value = cachedAppointments;
          primaryAppointments.clear();
          secondaryAppointments.clear();
        } else {
          appointments.value = cachedAppointments;
          primaryAppointments.value = cachedAppointments;
            secondaryAppointments.value = [];
          }

          print(
            '✅ [AppointmentController] Loaded ${appointments.length} appointments from cache',
          );
      }

      final userTypeForRequest =
          Get.find<AuthController>().currentUser.value?.userType;
      print('📅 [AppointmentController] User type: $userTypeForRequest');

      if (userTypeForRequest == 'receptionist') {
        // موظف الاستقبال: يجلب جميع المواعيد من /reception/appointments
        print(
          '📅 [AppointmentController] Loading appointments for receptionist',
        );
        final list = await _doctorService.getAllAppointmentsForReception();
        appointments.value = list;
        primaryAppointments.clear();
        secondaryAppointments.clear();
        print(
          '📅 [AppointmentController] Loaded ${list.length} appointments for receptionist',
        );
      } else {
        // المريض: يجلب مواعيده الخاصة من /patient/appointments
        print('📅 [AppointmentController] Loading appointments for patient');
        final result = await _patientService.getMyAppointments();
        primaryAppointments.value = result['primary'] ?? [];
        secondaryAppointments.value = result['secondary'] ?? [];

        // دمج المواعيد
        appointments.value = [...primaryAppointments, ...secondaryAppointments];
        print(
          '📅 [AppointmentController] Loaded ${primaryAppointments.length} primary and ${secondaryAppointments.length} secondary appointments',
        );
        print(
          '📅 [AppointmentController] Total appointments: ${appointments.length}',
        );
      }

      // 2) تحديث الكاش بعد نجاح الجلب من API - بنفس طريقة eversheen
      try {
        await _cacheService.saveAppointments(appointments.toList());
        print(
          '💾 [AppointmentController] Cache updated with ${appointments.length} appointments',
        );
      } catch (e) {
        print('❌ [AppointmentController] Error updating cache: $e');
      }
    } on ApiException catch (e) {
      print('❌ [AppointmentController] ApiException: ${e.message}');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e, stackTrace) {
      print('❌ [AppointmentController] Error loading appointments: $e');
      print('❌ [AppointmentController] Stack trace: $stackTrace');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المواعيد');
      }
    } finally {
      isLoading.value = false;
      print('📅 [AppointmentController] loadPatientAppointments finished');
    }
  }

  // جلب مواعيد الطبيب أو جميع المواعيد للاستقبال - بنفس طريقة eversheen مع Pagination
  Future<void> loadDoctorAppointments({
    String? day,
    String? dateFrom,
    String? dateTo,
    String? status,
    bool isInitial = false,
    bool isRefresh = false,
    String? filter, // 'اليوم', 'هذا الشهر', 'المتأخرون', 'تصفية مخصصة'
    DateTime? customFilterStart,
    DateTime? customFilterEnd,
  }) async {
    try {
      // تحديث الفلتر الحالي إذا تم تمريره
      if (filter != null) {
        _currentFilter = filter;
        _customFilterStart = customFilterStart;
        _customFilterEnd = customFilterEnd;
      }
      
      // حساب day و status و dateFrom/dateTo حسب الفلتر المحدد أولاً
      String? calculatedDay;
      String? calculatedStatus;
      String? calculatedDateFrom = dateFrom;
      String? calculatedDateTo = dateTo;
      
      if (_currentFilter != null) {
        switch (_currentFilter) {
          case 'اليوم':
            calculatedDay = 'today';
            break;
          case 'هذا الشهر':
            calculatedDay = 'month';
            break;
          case 'المتأخرون':
            calculatedStatus = 'late';
            break;
          case 'تصفية مخصصة':
            if (_customFilterStart != null && _customFilterEnd != null) {
              calculatedDateFrom = DateFormat('yyyy-MM-dd').format(_customFilterStart!);
              // ⭐ إضافة يوم واحد ليشمل اليوم الأخير في الفلتر
              final endDate = _customFilterEnd!.add(const Duration(days: 1));
              calculatedDateTo = DateFormat('yyyy-MM-dd').format(endDate);
              print('📅 [AppointmentController] Custom filter dates: $calculatedDateFrom to $calculatedDateTo');
            } else {
              print('⚠️ [AppointmentController] Custom filter selected but dates are null!');
            }
            break;
        }
      }

      if (isRefresh || isInitial) {
        currentPage = 1;
        hasMoreAppointments.value = true;
        isLoading.value = true;
        // ⭐ مسح القائمة فوراً عند تغيير التبويب/الفلتر لضمان عدم عرض بيانات قديمة
        appointments.clear();
        primaryAppointments.clear();
        secondaryAppointments.clear();
      } else {
        if (!hasMoreAppointments.value || isLoadingMoreAppointments.value) return;
        isLoadingMoreAppointments.value = true;
      }

      print('📅 [AppointmentController] Loading appointments - page: $currentPage, limit: $pageLimit, filter: $_currentFilter');

      // ⭐ الاعتماد على API فقط - لا نستخدم الكاش لتجنب عرض بيانات قديمة من تبويب سابق
      
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      List<AppointmentModel> appointmentsList;
      final skip = (currentPage - 1) * pageLimit;

      if (userType == 'receptionist') {
        // موظف الاستقبال: يجلب جميع المواعيد من جميع الأطباء
        print(
          '📅 [AppointmentController] Loading all appointments for receptionist',
        );
        appointmentsList = await _doctorService.getAllAppointmentsForReception(
          day: calculatedDay ?? day,
          dateFrom: calculatedDateFrom,
          dateTo: calculatedDateTo,
          status: calculatedStatus ?? status,
          skip: skip,
          limit: pageLimit,
        );
      } else {
        // الطبيب: يجلب مواعيده الخاصة
        print('📅 [AppointmentController] Loading appointments for doctor');
        appointmentsList = await _doctorService.getMyAppointments(
          day: calculatedDay ?? day,
          dateFrom: calculatedDateFrom,
          dateTo: calculatedDateTo,
          status: calculatedStatus ?? status,
          skip: skip,
          limit: pageLimit,
        );
      }
      
      // ترتيب المواعيد حسب التاريخ (من الأقدم للأحدث) - Backend يرتبها بالفعل، لكن للتأكد
      appointmentsList.sort((a, b) => a.date.compareTo(b.date));

      if (isRefresh || isInitial) {
        // ⭐ استبدال القائمة بالبيانات الجديدة من API
        appointments.assignAll(appointmentsList);
      } else {
        // إضافة المواعيد الجديدة فقط (تجنب التكرار)
        final existingIds = appointments.map((a) => a.id).toSet();
        final newAppointments = appointmentsList.where((a) => !existingIds.contains(a.id)).toList();
        appointments.addAll(newAppointments);
      }

      // تحديث حالة Pagination - بناءً على عدد المواعيد الجديدة فقط
      hasMoreAppointments.value = appointmentsList.length >= pageLimit;

      if (hasMoreAppointments.value) {
        currentPage++;
      } else {
        // لا توجد مواعيد أكثر، توقف عن الجلب
        print('📅 [AppointmentController] No more appointments available. Stopping pagination.');
      }

      print('✅ [AppointmentController] Loaded ${appointmentsList.length} appointments from API (total: ${appointments.length})');
      
      // ⭐ طباعة تفصيلية للمواعيد المحملة للتأكد من وجودها
      if (appointmentsList.isNotEmpty) {
        print('📋 [AppointmentController] Sample appointments:');
        for (var apt in appointmentsList.take(3)) {
          print('  - ${apt.patientName} on ${apt.date} at ${apt.time} (status: ${apt.status})');
        }
      } else {
        print('⚠️ [AppointmentController] No appointments returned from API!');
      }
      
      // ⭐ تم حذف حفظ الكاش - الاعتماد على API فقط لتجنب عرض بيانات قديمة
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المواعيد');
      }
    } finally {
      isLoading.value = false;
      isLoadingMoreAppointments.value = false;
    }
  }

  // جلب المزيد من المواعيد - بنفس طريقة eversheen
  Future<void> loadMoreAppointments({
    String? day,
    String? dateFrom,
    String? dateTo,
    String? status,
    String? filter,
    DateTime? customFilterStart,
    DateTime? customFilterEnd,
  }) async {
    if (!hasMoreAppointments.value || isLoadingMoreAppointments.value) return;
    await loadDoctorAppointments(
      day: day,
      dateFrom: dateFrom,
      dateTo: dateTo,
      status: status,
      isInitial: false,
      isRefresh: false,
      filter: filter ?? _currentFilter,
      customFilterStart: customFilterStart ?? _customFilterStart,
      customFilterEnd: customFilterEnd ?? _customFilterEnd,
    );
  }

  // جلب مواعيد مريض محدد (للطبيب) مع فلترتها للطبيب الحالي
  Future<void> loadPatientAppointmentsById(String patientId) async {
    try {
      isLoading.value = true;
      
      // محاولة قراءة من Cache أولاً - بنفس طريقة eversheen
      final cachedAppointments = _cacheService.getPatientAppointments(patientId);
      if (cachedAppointments.isNotEmpty) {
        patientAppointmentsCache[patientId] = cachedAppointments;
        patientAppointmentsCache.refresh();
        appointments.value = cachedAppointments;
        isLoading.value = false;
      }
      
      final appointmentsList = await _doctorService.getPatientAppointments(
        patientId,
      );

      // نفس مبدأ frontend: فلترة فقط حسب patientId (الـ backend يحدد الصلاحيات)
      final list =
          appointmentsList.where((apt) => apt.patientId == patientId).toList();

      patientAppointmentsCache[patientId] = list;
      patientAppointmentsCache.refresh();
      appointments.value = list;
      
      // حفظ في Cache - بنفس طريقة eversheen
      try {
        for (var apt in list) {
          await _cacheService.saveAppointment(apt);
        }
      } catch (e) {
        print('❌ [AppointmentController] Error updating cache: $e');
      }
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المواعيد');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // حذف موعد (للطبيب)
  Future<void> deleteAppointment(String patientId, String appointmentId) async {
    try {
      isLoading.value = true;
      final success = await _doctorService.deleteAppointment(
        patientId,
        appointmentId,
      );

      if (success) {
        appointments.removeWhere((apt) => apt.id == appointmentId);
        
        // حذف من Cache - بنفس طريقة eversheen
        try {
          await _cacheService.deleteAppointment(appointmentId);
        } catch (e) {
          print('❌ [AppointmentController] Error deleting from cache: $e');
        }
        
        Get.snackbar('نجح', 'تم حذف الموعد بنجاح');
      } else {
        throw ApiException('فشل حذف الموعد');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء حذف الموعد');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // إضافة موعد جديد (للطبيب)
  Future<void> addAppointment({
    required String patientId,
    required DateTime scheduledAt,
    String? note,
    File? imageFile,
    List<File>? imageFiles,
  }) async {
    AppointmentModel? tempAppointment;

    try {
      // 1) إنشاء موعد مؤقت (تحديث متفائل في الواجهة)
      tempAppointment = AppointmentModel(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        patientId: patientId,
        patientName: '',
        doctorId: '',
        doctorName: '',
        date: scheduledAt,
        time:
            '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}',
        status: 'pending',
        notes: note,
        imagePath: null,
        imagePaths: const [],
      );

      // إضافة الموعد المؤقت إلى قائمة المواعيد العامة
      appointments.add(tempAppointment);

      // إضافة الموعد المؤقت أيضاً إلى كاش المواعيد الخاصة بالمريض (إن وجد)
      final cachedForPatient = patientAppointmentsCache[patientId];
      if (cachedForPatient != null) {
        final newList = List<AppointmentModel>.from(cachedForPatient)
          ..add(tempAppointment);
        patientAppointmentsCache[patientId] = newList;
        patientAppointmentsCache.refresh();
      }

      // 2) استدعاء السيرفر
      var appointment = await _doctorService.addAppointment(
        patientId: patientId,
        scheduledAt: scheduledAt,
        note: note,
        imageFile: imageFile,
        imageFiles: imageFiles,
      );
      appointment = _normalizeServerAppointmentTime(appointment, scheduledAt);

      // Remove any temp appointment for the same patient/time slot
      appointments.removeWhere((apt) =>
          apt.id.startsWith('temp-') &&
          apt.patientId == patientId &&
          _isSameSlot(apt.date, scheduledAt));

      // 3) استبدال الموعد المؤقت بالموعد الحقيقي في قائمة المواعيد العامة
      final index =
          appointments.indexWhere((apt) => apt.id == tempAppointment!.id);
      if (index != -1) {
        appointments[index] = appointment;
      } else {
        appointments.add(appointment);
      }

      // 4) استبدال الموعد المؤقت بالموعد الحقيقي في كاش المريض (إن وجد)
      final cachedAfterAdd = patientAppointmentsCache[patientId];
      if (cachedAfterAdd != null &&
          cachedAfterAdd.isNotEmpty) {
        final list = List<AppointmentModel>.from(cachedAfterAdd);
        list.removeWhere((apt) =>
            apt.id.startsWith('temp-') &&
            apt.patientId == patientId &&
            _isSameSlot(apt.date, scheduledAt));
        final cachedIndex =
            list.indexWhere((apt) => apt.id == tempAppointment!.id);
        if (cachedIndex != -1) {
          list[cachedIndex] = appointment;
        } else {
          list.add(appointment);
        }
        patientAppointmentsCache[patientId] = list;
        patientAppointmentsCache.refresh();
      }

      // حفظ في Cache - بنفس طريقة eversheen
      try {
        await _cacheService.saveAppointment(appointment);
      } catch (e) {
        print('❌ [AppointmentController] Error updating cache: $e');
      }

      Get.snackbar('نجح', 'تم إضافة الموعد بنجاح');
    } on ApiException catch (e) {
      // Rollback: إزالة الموعد المؤقت
      if (tempAppointment != null) {
        appointments.removeWhere((apt) => apt.id == tempAppointment!.id);

        // إزالة الموعد المؤقت من كاش المريض أيضاً (إن وجد)
        final cached = patientAppointmentsCache[patientId];
        if (cached != null && cached.isNotEmpty) {
          final list = List<AppointmentModel>.from(cached)
            ..removeWhere((apt) => apt.id == tempAppointment!.id);
          patientAppointmentsCache[patientId] = list;
          patientAppointmentsCache.refresh();
        }
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
      rethrow;
    } catch (e) {
      if (tempAppointment != null) {
        appointments.removeWhere((apt) => apt.id == tempAppointment!.id);

        // إزالة الموعد المؤقت من كاش المريض أيضاً (إن وجد)
        final cached = patientAppointmentsCache[patientId];
        if (cached != null && cached.isNotEmpty) {
          final list = List<AppointmentModel>.from(cached)
            ..removeWhere((apt) => apt.id == tempAppointment!.id);
          patientAppointmentsCache[patientId] = list;
          patientAppointmentsCache.refresh();
        }
      }

      NetworkUtils.showNetworkErrorDialog();
      rethrow;
    } finally {
      // لا نستخدم isLoading هنا حتى لا نظهر تحميل عام على كامل الشاشة
    }
  }

  // تحديث حالة الموعد (للطبيب)
  Future<void> updateAppointmentStatus(
    String patientId,
    String appointmentId,
    String status,
  ) async {
    try {
      isLoading.value = true;
      final updatedAppointment = await _doctorService.updateAppointmentStatus(
        patientId,
        appointmentId,
        status,
      );

      // تحديث الموعد في القائمة
      final index = appointments.indexWhere((apt) => apt.id == appointmentId);
      if (index != -1) {
        appointments[index] = updatedAppointment;
      }

      // حفظ في Cache - بنفس طريقة eversheen
      try {
        await _cacheService.saveAppointment(updatedAppointment);
      } catch (e) {
        print('❌ [AppointmentController] Error updating cache: $e');
      }

      // تحديث الموعد في كاش المريض (إن وجد)
      final cached = patientAppointmentsCache[patientId];
      if (cached != null && cached.isNotEmpty) {
        final cachedIndex = cached.indexWhere((apt) => apt.id == appointmentId);
        if (cachedIndex != -1) {
          final newList = List<AppointmentModel>.from(cached);
          newList[cachedIndex] = updatedAppointment;
          patientAppointmentsCache[patientId] = newList;
          patientAppointmentsCache.refresh();
        }
      }

      Get.snackbar('نجح', 'تم تحديث حالة الموعد بنجاح');
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
      rethrow;
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث حالة الموعد');
      }
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // تحديث تاريخ ووقت الموعد
  Future<void> updateAppointmentDateTime(
    String patientId,
    String appointmentId,
    DateTime scheduledAt,
  ) async {
    try {
      isLoading.value = true;
      final updatedAppointment = await _doctorService.updateAppointmentDateTime(
        patientId,
        appointmentId,
        scheduledAt,
      );

      // تحديث الموعد في القائمة
      final index = appointments.indexWhere((apt) => apt.id == appointmentId);
      if (index != -1) {
        appointments[index] = updatedAppointment;
      }

      // حفظ في Cache - بنفس طريقة eversheen
      try {
        await _cacheService.saveAppointment(updatedAppointment);
      } catch (e) {
        print('❌ [AppointmentController] Error updating cache: $e');
      }

      // تحديث الموعد في كاش المريض (إن وجد)
      final cached = patientAppointmentsCache[patientId];
      if (cached != null && cached.isNotEmpty) {
        final cachedIndex = cached.indexWhere((apt) => apt.id == appointmentId);
        if (cachedIndex != -1) {
          final newList = List<AppointmentModel>.from(cached);
          newList[cachedIndex] = updatedAppointment;
          patientAppointmentsCache[patientId] = newList;
          patientAppointmentsCache.refresh();
        }
      }

      Get.snackbar('نجح', 'تم تحديث تاريخ الموعد بنجاح');
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
      rethrow;
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث تاريخ الموعد');
      }
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // تم إزالة الدوال getTodayAppointments, getLateAppointments, getThisMonthAppointments
  // لأننا نستخدم pagination فقط - الفلترة تتم في الـ backend
}
