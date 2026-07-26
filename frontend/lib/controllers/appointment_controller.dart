import 'dart:io';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';

class AppointmentController extends GetxController {
  final _patientService = PatientService();
  final _doctorService = DoctorService();
  
  final RxList<AppointmentModel> appointments = <AppointmentModel>[].obs;
  final RxList<AppointmentModel> primaryAppointments = <AppointmentModel>[].obs;
  final RxList<AppointmentModel> secondaryAppointments =
      <AppointmentModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt appointmentsTotalCount = 0.obs;

  // Pagination — نفس frontend_desktop
  int currentPage = 1;
  final RxBool isLoadingMoreAppointments = false.obs;
  final RxBool hasMoreAppointments = true.obs;
  final int pageLimit = 25;

  String? _currentFilter;
  DateTime? _customFilterStart;
  DateTime? _customFilterEnd;

  String? get currentFilter => _currentFilter;

  // جلب مواعيد المريض أو جميع المواعيد للاستقبال
  Future<void> loadPatientAppointments() async {
    try {
      print('📅 [AppointmentController] loadPatientAppointments called');
      isLoading.value = true;

      // 1) محاولة التحميل من الكاش أولاً (Hive)
      final box = Hive.box('appointments');
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;
      final activePatientId = authController.patientProfileId.value;
      // كاش منفصل لكل فرد عائلة حتى لا تظهر مواعيد شخص آخر بعد التبديل
      final cacheKey = userType == 'patient' &&
              activePatientId != null &&
              activePatientId.isNotEmpty
          ? 'patient_${userType}_$activePatientId'
          : 'patient_${userType ?? 'unknown'}';
      
      final cachedList = box.get(cacheKey);
      if (cachedList != null && cachedList is List) {
        try {
          final cachedAppointments = cachedList
              .map(
                (json) => AppointmentModel.fromJson(
                  Map<String, dynamic>.from(json as Map),
                ),
              )
              .toList();
          
          if (userType == 'receptionist') {
            appointments.value = cachedAppointments;
            primaryAppointments.clear();
            secondaryAppointments.clear();
          } else {
            // للمريض، نحتاج لفصل primary و secondary - لكن سنستخدم جميع المواعيد من الكاش
            appointments.value = cachedAppointments;
            primaryAppointments.value = cachedAppointments;
            secondaryAppointments.value = [];
          }
          
          print('✅ [AppointmentController] Loaded ${appointments.length} appointments from cache');
        } catch (e) {
          print('❌ [AppointmentController] Error parsing cached appointments: $e');
        }
      }

      print('📅 [AppointmentController] User type: $userType');

      if (userType == 'receptionist') {
        // موظف الاستقبال: يجلب جميع المواعيد من /reception/appointments
        print('📅 [AppointmentController] Loading appointments for receptionist');
        final result = await _doctorService.getAllAppointmentsForReception();
        appointments.value = result.items;
        appointmentsTotalCount.value = result.total;
        primaryAppointments.clear();
        secondaryAppointments.clear();
        print('📅 [AppointmentController] Loaded ${result.items.length} appointments for receptionist');
      } else {
        // المريض: يجلب مواعيده الخاصة من /patient/appointments
        print('📅 [AppointmentController] Loading appointments for patient');
        final result = await _patientService.getMyAppointments(
          patientId: authController.patientProfileId.value,
        );
        primaryAppointments.value = result['primary'] ?? [];
        secondaryAppointments.value = result['secondary'] ?? [];

        // دمج المواعيد
        appointments.value = [...primaryAppointments, ...secondaryAppointments];
        print('📅 [AppointmentController] Loaded ${primaryAppointments.length} primary and ${secondaryAppointments.length} secondary appointments');
        print('📅 [AppointmentController] Total appointments: ${appointments.length}');
      }

      // 2) تحديث الكاش بعد نجاح الجلب من API
      try {
        await box.put(cacheKey, appointments.map((a) => a.toJson()).toList());
        await box.put('${cacheKey}_lastUpdated', DateTime.now().toIso8601String());
        print('💾 [AppointmentController] Cache updated with ${appointments.length} appointments');
      } catch (e) {
        print('❌ [AppointmentController] Error updating cache: $e');
      }
    } on ApiException catch (e) {
      print('❌ [AppointmentController] ApiException: ${e.message}');
      await NetworkUtils.showError(e);
    } catch (e, stackTrace) {
      print('❌ [AppointmentController] Error loading appointments: $e');
      print('❌ [AppointmentController] Stack trace: $stackTrace');
      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء تحميل المواعيد');
    } finally {
      isLoading.value = false;
      print('📅 [AppointmentController] loadPatientAppointments finished');
    }
  }

  // جلب مواعيد الطبيب أو جميع المواعيد للاستقبال — تصفية من السيرفر + pagination
  Future<void> loadDoctorAppointments({
    String? day,
    String? dateFrom,
    String? dateTo,
    String? status,
    bool isInitial = false,
    bool isRefresh = false,
    String? filter,
    DateTime? customFilterStart,
    DateTime? customFilterEnd,
  }) async {
    try {
      if (filter != null) {
        _currentFilter = filter;
        _customFilterStart = customFilterStart;
        _customFilterEnd = customFilterEnd;
      }

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
              calculatedDateFrom =
                  DateFormat('yyyy-MM-dd').format(_customFilterStart!);
              final endDate = _customFilterEnd!.add(const Duration(days: 1));
              calculatedDateTo = DateFormat('yyyy-MM-dd').format(endDate);
            }
            break;
        }
      }

      if (isRefresh || isInitial) {
        currentPage = 1;
        hasMoreAppointments.value = true;
        if (appointments.isEmpty) {
          isLoading.value = true;
        }
      } else {
        if (!hasMoreAppointments.value || isLoadingMoreAppointments.value) {
          return;
        }
        isLoadingMoreAppointments.value = true;
      }

      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;
      final skip = (currentPage - 1) * pageLimit;

      AppointmentsQueryResult queryResult;
      if (userType == 'receptionist') {
        queryResult = await _doctorService.getAllAppointmentsForReception(
          day: calculatedDay ?? day,
          dateFrom: calculatedDateFrom,
          dateTo: calculatedDateTo,
          status: calculatedStatus ?? status,
          skip: skip,
          limit: pageLimit,
        );
      } else {
        queryResult = await _doctorService.getMyAppointments(
          day: calculatedDay ?? day,
          dateFrom: calculatedDateFrom,
          dateTo: calculatedDateTo,
          status: calculatedStatus ?? status,
          skip: skip,
          limit: pageLimit,
        );
      }
      final appointmentsList = queryResult.items;

      if (isRefresh || isInitial) {
        appointments.assignAll(appointmentsList);
        appointmentsTotalCount.value = queryResult.total;
      } else {
        appointments.addAll(appointmentsList);
      }

      hasMoreAppointments.value = appointmentsList.length >= pageLimit;
      if (hasMoreAppointments.value) {
        currentPage++;
      }
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
    } catch (e) {
      await NetworkUtils.showError(
        e,
        fallbackMessage: 'حدث خطأ أثناء تحميل المواعيد',
      );
    } finally {
      isLoading.value = false;
      isLoadingMoreAppointments.value = false;
    }
  }

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

  // جلب مواعيد مريض محدد (للطبيب)
  Future<void> loadPatientAppointmentsById(String patientId) async {
    try {
      isLoading.value = true;
      final appointmentsList = await _doctorService.getPatientAppointments(
        patientId,
      );
      // Filter by patient ID
      appointments.value = appointmentsList
          .where((apt) => apt.patientId == patientId)
          .toList();
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
    } catch (e) {
      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء تحميل المواعيد');
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
        Get.snackbar('نجح', 'تم حذف الموعد بنجاح');
      } else {
        throw ApiException('فشل حذف الموعد');
      }
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
      rethrow;
    } catch (e) {
      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء حذف الموعد');
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

      appointments.add(tempAppointment);

      // 2) استدعاء السيرفر
      final appointment = await _doctorService.addAppointment(
        patientId: patientId,
        scheduledAt: scheduledAt,
        note: note,
        imageFile: imageFile,
        imageFiles: imageFiles,
      );

      // 3) استبدال الموعد المؤقت بالموعد الحقيقي
      final index =
          appointments.indexWhere((apt) => apt.id == tempAppointment!.id);
      if (index != -1) {
        appointments[index] = appointment;
      } else {
        appointments.add(appointment);
      }

      Get.snackbar('نجح', 'تم إضافة الموعد بنجاح');
    } on ApiException catch (e) {
      // Rollback: إزالة الموعد المؤقت
      if (tempAppointment != null) {
        appointments.removeWhere((apt) => apt.id == tempAppointment!.id);
      }

      await NetworkUtils.showError(e);
      rethrow;
    } catch (e) {
      if (tempAppointment != null) {
        appointments.removeWhere((apt) => apt.id == tempAppointment!.id);
      }

      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء إضافة الموعد');
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

      Get.snackbar('نجح', 'تم تحديث حالة الموعد بنجاح');
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
      rethrow;
    } catch (e) {
      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء تحديث حالة الموعد');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  List<AppointmentModel> getUpcomingAppointments() {
    final now = DateTime.now();
    return appointments.where((appointment) {
      return appointment.date.isAfter(now) && 
          (appointment.status == 'pending' ||
              appointment.status == 'scheduled');
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  List<AppointmentModel> getPastAppointments() {
    final now = DateTime.now();
    return appointments.where((appointment) {
      return appointment.date.isBefore(now) || 
             appointment.status == 'completed' ||
             appointment.status == 'cancelled';
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  // مواعيد اليوم
  List<AppointmentModel> getTodayAppointments() {
    final now = DateTime.now();

    return appointments.where((appointment) {
      final d = appointment.date;
      final isToday =
          d.year == now.year && d.month == now.month && d.day == now.day;
      return isToday &&
          (appointment.status == 'pending' ||
              appointment.status == 'scheduled');
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // المواعيد المتأخرة (مواعيد فاتت ولم تكتمل)
  List<AppointmentModel> getLateAppointments() {
    final now = DateTime.now();
    return appointments.where((appointment) {
      return appointment.date.isBefore(now) && 
          (appointment.status == 'pending' ||
              appointment.status == 'scheduled');
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  // مواعيد هذا الشهر
  List<AppointmentModel> getThisMonthAppointments() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    
    return appointments.where((appointment) {
      final appointmentDate = appointment.date;
      return appointmentDate.isAfter(monthStart) && 
             appointmentDate.isBefore(monthEnd) &&
          (appointment.status == 'pending' ||
              appointment.status == 'scheduled');
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }
}
