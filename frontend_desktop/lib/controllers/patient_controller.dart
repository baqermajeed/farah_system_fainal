import 'dart:async';
import 'package:get/get.dart';
import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/repositories/patient_repository.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/core/logging/app_logger.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';

class PatientController extends GetxController {
  final _patientService = PatientService();
  final _doctorService = DoctorService();
  final _cacheService = CacheService();
  final _patientRepository = PatientRepository();

  final RxList<PatientModel> patients = <PatientModel>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<PatientModel?> selectedPatient = Rx<PatientModel?>(null);
  // for patient usage, currently we focus on doctor usage
  final Rx<PatientModel?> myProfile = Rx<PatientModel?>(null);

  // ⭐ متغيرات Pagination - بنفس طريقة eversheen
  var currentPage = 1;
  var totalPages = 1;
  var isLoadingMorePatients = false.obs;
  var hasMorePatients = true.obs;
  final int pageLimit = 25; // 25 مريض في كل مرة (بدلاً من 10 في eversheen)

  // ⭐ متغيرات البحث - بنفس طريقة eversheen
  RxList<PatientModel> searchResults = <PatientModel>[].obs;
  RxBool isSearching = false.obs;
  var searchPage = 1;
  var hasMoreSearchResults = true.obs;
  var isLoadingMoreSearch = false.obs;
  var lastSearchQuery = ''.obs;

  // ⭐ متغيرات للجلب الذكي (للتوافق مع الكود القديم)
  final RxInt loadedPatientsCount = 0.obs;
  final RxString loadingProgress = ''.obs;
  final RxBool isFetchingInBackground = false.obs;
  Worker? _reconnectWorker;

  @override
  void onInit() {
    super.onInit();
    _bindReconnectAutoReload();
  }

  @override
  void onClose() {
    _reconnectWorker?.dispose();
    super.onClose();
  }

  void _bindReconnectAutoReload() {
    if (!Get.isRegistered<AuthController>()) return;
    final authController = Get.find<AuthController>();
    _reconnectWorker = ever<int>(authController.reconnectVersion, (_) {
      unawaited(_reloadAfterReconnect());
    });
  }

  Future<void> _reloadAfterReconnect() async {
    try {
      await loadPatients(isInitial: true, isRefresh: true);
      AppLogger.info(
        'Data refreshed after reconnect',
        scope: 'PatientController',
      );
    } catch (e) {
      AppLogger.warning(
        'Reconnect refresh failed',
        scope: 'PatientController',
        error: e,
      );
    }
  }

  // جلب قائمة المرضى (للطبيب) - بنفس طريقة eversheen مع Pagination
  Future<void> loadPatients({
    bool isInitial = false,
    bool isRefresh = false,
  }) async {
    try {
      if (isRefresh || isInitial) {
        currentPage = 1;
        hasMorePatients.value = true;
        isLoading.value = true;
        patients.clear();
      } else {
        if (!hasMorePatients.value || isLoadingMorePatients.value) return;
        isLoadingMorePatients.value = true;
      }

      print(
        '📋 [PatientController] Loading patients - page: $currentPage, limit: $pageLimit',
      );

      // 1) محاولة التحميل من الكاش أولاً (Hive) - بنفس طريقة eversheen
      if (isInitial || isRefresh) {
        try {
          // ✅ حل نهائي: تحميل فقط أول 25 مريض من Cache لتجنب تحميل آلاف السجلات
          final cachedPatients = _cacheService.getFirstPatients(pageLimit);
          if (cachedPatients.isNotEmpty) {
            patients.assignAll(cachedPatients);
            print(
              '✅ [PatientController] Loaded ${patients.length} patients from cache',
            );
          }
        } catch (e) {
          print('❌ [PatientController] Error loading from cache: $e');
          // مسح Cache التالف
          try {
            await _cacheService.clearPatients();
          } catch (_) {}
        }
      }

      // 2) جلب من API
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      final patientsList = await _patientRepository.fetchPatients(
        userType: userType,
        skip: (currentPage - 1) * pageLimit,
        limit: pageLimit,
      );

      if (isRefresh || isInitial) {
        patients.assignAll(patientsList);
      } else {
        patients.addAll(patientsList);
      }

      // تحديث حالة Pagination
      // افتراض أن هناك المزيد إذا كان عدد النتائج = pageLimit
      hasMorePatients.value = patientsList.length >= pageLimit;

      if (hasMorePatients.value) {
        currentPage++;
      }

      print(
        '✅ [PatientController] Loaded ${patientsList.length} patients from API (total: ${patients.length})',
      );

      // 3) تحديث الكاش بعد نجاح الجلب من API - بنفس طريقة eversheen
      // تشغيل في الخلفية بدون انتظار لتجنب blocking UI thread
      unawaited(
        _cacheService
            .savePatients(patients.toList())
            .then((_) {
              print(
                '💾 [PatientController] Cache updated with ${patients.length} patients',
              );
            })
            .catchError((e, stackTrace) {
              print('❌ [PatientController] Error updating cache: $e');
              print('❌ [PatientController] Stack trace: $stackTrace');
            }),
      );
    } on ApiException catch (e) {
      print('❌ [PatientController] ApiException: ${e.message}');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e) {
      print('❌ [PatientController] Error: $e');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المرضى');
      }
    } finally {
      isLoading.value = false;
      isLoadingMorePatients.value = false;
    }
  }

  // جلب المزيد من المرضى - بنفس طريقة eversheen
  Future<void> loadMorePatients() async {
    if (!hasMorePatients.value || isLoadingMorePatients.value) return;
    await loadPatients(isInitial: false, isRefresh: false);
  }

  // توافق خلفي: المسار الذكي القديم أصبح يوجّه مباشرة لمسار API pagination.
  Future<void> loadPatientsSmart({
    int initialBatchSize = 100,
    int batchSize = 100,
    int maxBatches = 200,
    int recentPatientsCheck = 200,
  }) async {
    // Keep signature for backward compatibility with existing callers.
    final compatibilityChecksum =
        initialBatchSize + batchSize + maxBatches + recentPatientsCheck;
    if (compatibilityChecksum < 0) {
      // No-op guard to silence analyzer in a deterministic way.
      return;
    }
    await loadPatients(isInitial: true, isRefresh: true);
  }

  void selectPatient(PatientModel? patient) {
    selectedPatient.value = patient;
  }

  Future<void> setTreatmentType({
    required String patientId,
    required String treatmentType,
  }) async {
    PatientModel? oldPatient;

    try {
      isLoading.value = true;

      // 1) حفظ نسخة قديمة (لأجل التراجع) + تحديث متفائل في الواجهة والكاش
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        oldPatient = patients[index];

        // بناء نسخة محدثة بشكل متفائل
        final optimisticPatient = PatientModel(
          id: oldPatient.id,
          name: oldPatient.name,
          phoneNumber: oldPatient.phoneNumber,
          gender: oldPatient.gender,
          age: oldPatient.age,
          city: oldPatient.city,
          visitType: oldPatient.visitType,
          imageUrl: oldPatient.imageUrl,
          doctorIds: oldPatient.doctorIds,
          treatmentHistory: <String>[
            ...?oldPatient.treatmentHistory,
            treatmentType,
          ],
          qrCodeData: oldPatient.qrCodeData,
          qrImagePath: oldPatient.qrImagePath,
          paymentMethods: oldPatient.paymentMethods,
          activityStatus: oldPatient.activityStatus,
          createdAt: oldPatient.createdAt,
        );

        patients[index] = optimisticPatient;
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = optimisticPatient;
        }

        // تحديث الكاش بشكل متفائل - بنفس طريقة eversheen
        try {
          await _cacheService.savePatient(optimisticPatient);
        } catch (_) {}
      }

      // 2) إرسال الطلب إلى السيرفر
      final updatedPatient = await _doctorService.setTreatmentType(
        patientId: patientId,
        treatmentType: treatmentType,
      );

      // تحديث القائمة
      final newIndex = patients.indexWhere((p) => p.id == patientId);
      if (newIndex != -1) {
        patients[newIndex] = updatedPatient;
      }

      // تحديث المريض المحدد إذا كان هو نفسه
      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }

      // تحديث الكاش بالبيانات المؤكدة من السيرفر - بنفس طريقة eversheen
      try {
        await _cacheService.savePatient(updatedPatient);
      } catch (_) {}

      Get.snackbar('نجح', 'تم تحديث نوع العلاج');
    } on ApiException catch (e) {
      // تراجع (Rollback) إلى الحالة القديمة
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          await _cacheService.savePatient(oldPatient);
        } catch (_) {}
      }

      // حوار تحذير للمستخدم أو سناك بار حسب نوع الخطأ
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e) {
      // تراجع (Rollback) إلى الحالة القديمة
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          await _cacheService.savePatient(oldPatient);
        } catch (_) {}
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث نوع العلاج');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setPaymentMethods({
    required String patientId,
    required List<String> methods,
  }) async {
    PatientModel? oldPatient;

    try {
      isLoading.value = true;

      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        oldPatient = patients[index];

        final optimisticPatient = PatientModel(
          id: oldPatient.id,
          name: oldPatient.name,
          phoneNumber: oldPatient.phoneNumber,
          gender: oldPatient.gender,
          age: oldPatient.age,
          city: oldPatient.city,
          visitType: oldPatient.visitType,
          imageUrl: oldPatient.imageUrl,
          doctorIds: oldPatient.doctorIds,
          treatmentHistory: oldPatient.treatmentHistory,
          qrCodeData: oldPatient.qrCodeData,
          qrImagePath: oldPatient.qrImagePath,
          paymentMethods: methods,
          activityStatus: oldPatient.activityStatus,
          createdAt: oldPatient.createdAt,
        );

        patients[index] = optimisticPatient;
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = optimisticPatient;
        }

        try {
          await _cacheService.savePatient(optimisticPatient);
        } catch (_) {}
      }

      final updatedPatient = await _doctorService.setPaymentMethods(
        patientId: patientId,
        methods: methods,
      );

      final newIndex = patients.indexWhere((p) => p.id == patientId);
      if (newIndex != -1) {
        patients[newIndex] = updatedPatient;
      }

      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }

      try {
        await _cacheService.savePatient(updatedPatient);
      } catch (_) {}

      Get.snackbar('نجح', 'تم تحديث طرق الدفع');
    } on ApiException catch (e) {
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          await _cacheService.savePatient(oldPatient);
        } catch (_) {}
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e) {
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          await _cacheService.savePatient(oldPatient);
        } catch (_) {}
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث طرق الدفع');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updatePatientProfile({
    required String patientId,
    String? name,
    String? phone,
    String? gender,
    int? age,
    String? city,
  }) async {
    PatientModel? oldPatient;
    try {
      isLoading.value = true;
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        oldPatient = patients[index];
      }

      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType.toLowerCase();

      final PatientModel updatedPatient;
      if (userType == 'receptionist' || userType == 'admin') {
        updatedPatient = await _patientService.updatePatientByReception(
          patientId: patientId,
          name: name,
          phone: phone,
          gender: gender,
          age: age,
          city: city,
        );
      } else {
        updatedPatient = await _doctorService.updatePatientProfile(
          patientId: patientId,
          name: name,
          gender: gender,
          age: age,
          city: city,
        );
      }

      final newIndex = patients.indexWhere((p) => p.id == patientId);
      if (newIndex != -1) {
        patients[newIndex] = updatedPatient;
      }

      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }

      final searchIndex = searchResults.indexWhere((p) => p.id == patientId);
      if (searchIndex != -1) {
        searchResults[searchIndex] = updatedPatient;
      }

      try {
        await _cacheService.savePatient(updatedPatient);
      } catch (_) {}
    } on ApiException catch (e) {
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
      }
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', e.message);
      }
      rethrow;
    } catch (e) {
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
      }
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث بيانات المريض');
      }
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // تحديث الأطباء المرتبطين بمريض معين في الواجهة بدون إعادة تحميل كاملة
  Future<void> updatePatientDoctorIds(
    String patientId,
    List<String> doctorIds,
  ) async {
    final index = patients.indexWhere((p) => p.id == patientId);
    if (index == -1) return;

    final patient = patients[index];
    final updatedPatient = PatientModel(
      id: patient.id,
      name: patient.name,
      phoneNumber: patient.phoneNumber,
      gender: patient.gender,
      age: patient.age,
      city: patient.city,
      visitType: patient.visitType,
      imageUrl: patient.imageUrl,
      doctorIds: doctorIds,
      treatmentHistory: patient.treatmentHistory,
      qrCodeData: patient.qrCodeData,
      qrImagePath: patient.qrImagePath,
      paymentMethods: patient.paymentMethods,
      activityStatus: patient.activityStatus,
      createdAt: patient.createdAt,
    );

    patients[index] = updatedPatient;

    if (selectedPatient.value?.id == patientId) {
      selectedPatient.value = updatedPatient;
    }

    // تحديث الكاش - بنفس طريقة eversheen
    try {
      await _cacheService.savePatient(updatedPatient);
    } catch (_) {}
  }

  Future<void> activatePatientByReception(String patientId) async {
    try {
      isLoading.value = true;
      final updatedPatient = await _patientService.activatePatient(patientId);
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        patients[index] = updatedPatient;
      }
      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }
      try {
        await _cacheService.savePatient(updatedPatient);
      } catch (_) {}
      Get.snackbar('نجح', 'تم تنشيط المريض');
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', e.message);
      }
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'فشل تنشيط المريض');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updatePatientActivityStatus({
    required String patientId,
    required String status,
  }) async {
    try {
      isLoading.value = true;
      final updatedPatient = await _patientService.updatePatientActivityStatus(
        patientId: patientId,
        status: status,
      );
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        patients[index] = updatedPatient;
      }
      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }
      try {
        await _cacheService.savePatient(updatedPatient);
      } catch (_) {}
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', e.message);
      }
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'فشل تحديث حالة المريض');
      }
    } finally {
      isLoading.value = false;
    }
  }

  PatientModel? getPatientById(String patientId) {
    try {
      return patients.firstWhere((p) => p.id == patientId);
    } catch (_) {}

    // Fallback to search results for cases where the patient was opened via search/QR.
    try {
      return searchResults.firstWhere((p) => p.id == patientId);
    } catch (_) {}

    // Final fallback: currently selected patient.
    final selected = selectedPatient.value;
    if (selected?.id == patientId) {
      return selected;
    }

    return null;
  }

  // إضافة مريض جديد إلى القائمة وتعيينه كمريض محدد بدون إعادة تحميل كاملة
  Future<void> addPatient(PatientModel patient) async {
    // ⭐ التحقق إذا كان المريض موجود بالفعل
    final existingIndex = patients.indexWhere((p) => p.id == patient.id);

    if (existingIndex != -1) {
      // ⭐ إذا كان موجود، نحدثه بدلاً من إضافته
      patients[existingIndex] = patient;
      print('✅ [PatientController] Patient updated: ${patient.name}');
    } else {
      // ⭐ إذا لم يكن موجود، نضيفه في بداية القائمة
      patients.insert(0, patient);
      loadedPatientsCount.value = patients.length; // ⭐ تحديث العداد
      print('✅ [PatientController] Patient added: ${patient.name}');
    }

    selectedPatient.value = patient;

    // تحديث الكاش بعد الإضافة/التحديث - بنفس طريقة eversheen
    try {
      await _cacheService.savePatient(patient);
    } catch (_) {}
  }

  // ⭐ دوال البحث - بنفس طريقة eversheen
  Future<void> searchPatients({required String searchQuery}) async {
    try {
      if (searchQuery.trim().isEmpty) {
        clearSearch();
        return;
      }

      // إذا كان نفس البحث، لا تعيد البحث
      if (searchQuery == lastSearchQuery.value && searchResults.isNotEmpty) {
        return;
      }

      // بحث جديد
      searchPage = 1;
      hasMoreSearchResults.value = true;
      lastSearchQuery.value = searchQuery;
      isSearching.value = true;
      searchResults.clear();

      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      final results = await _patientRepository.searchPatients(
        userType: userType,
        query: searchQuery.trim(),
        skip: (searchPage - 1) * pageLimit,
        limit: pageLimit,
      );

      searchResults.assignAll(results);

      // تحقق من وجود المزيد
      hasMoreSearchResults.value = results.length >= pageLimit;
      if (hasMoreSearchResults.value) {
        searchPage = 2; // الصفحة التالية
      }
    } catch (e) {
      print('❌ [PatientController] Error searching patients: $e');
    } finally {
      isSearching.value = false;
    }
  }

  // ⭐ دالة لتحميل المزيد من نتائج البحث
  Future<void> loadMoreSearchResults() async {
    if (isLoadingMoreSearch.value || !hasMoreSearchResults.value) {
      return;
    }

    isLoadingMoreSearch.value = true;

    try {
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      final results = await _patientRepository.searchPatients(
        userType: userType,
        query: lastSearchQuery.value,
        skip: (searchPage - 1) * pageLimit,
        limit: pageLimit,
      );

      if (results.isNotEmpty) {
        searchResults.addAll(results);
        searchPage++;

        // تحقق من وجود المزيد
        hasMoreSearchResults.value = results.length >= pageLimit;
      } else {
        hasMoreSearchResults.value = false;
      }
    } catch (e) {
      print('❌ [PatientController] Error loading more search results: $e');
    } finally {
      isLoadingMoreSearch.value = false;
    }
  }

  // ⭐ مسح البحث والعودة للقائمة العادية
  void clearSearch() {
    lastSearchQuery.value = '';
    searchPage = 1;
    hasMoreSearchResults.value = true;
    isLoadingMoreSearch.value = false;
    isSearching.value = false;
    searchResults.clear();
  }
}
