import 'dart:io';

import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/presence_controller.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';

class PatientController extends GetxController {
  final _patientService = PatientService();
  final _doctorService = DoctorService();

  final RxList<PatientModel> patients = <PatientModel>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<PatientModel?> selectedPatient = Rx<PatientModel?>(null);
  final Rx<PatientModel?> myProfile = Rx<PatientModel?>(null);
  final Rx<Map<String, dynamic>?> myDoctor = Rx<Map<String, dynamic>?>(null);
  final RxList<Map<String, dynamic>> myDoctors = <Map<String, dynamic>>[].obs;
  /// يصبح true بعد أول جلب للأطباء (حتى لو كانت القائمة فارغة).
  final RxBool myDoctorsReady = false.obs;

  // Doctor pagination (مثل frontend_desktop)
  var doctorCurrentPage = 1;
  final int doctorPageLimit = 25;
  final RxBool isLoadingMorePatients = false.obs;
  final RxBool hasMorePatients = true.obs;

  // Doctor server-side search
  final RxList<PatientModel> searchResults = <PatientModel>[].obs;
  final RxBool isSearching = false.obs;
  var doctorSearchPage = 1;
  final RxBool hasMoreSearchResults = true.obs;
  final RxBool isLoadingMoreSearch = false.obs;
  final RxString lastSearchQuery = ''.obs;

  bool get _isDoctorUser =>
      Get.find<AuthController>().currentUser.value?.userType == 'doctor';

  /// القائمة المعروضة للطبيب: نتائج البحث من السيرفر أو الصفحات المحمّلة.
  List<PatientModel> get doctorDisplayedPatients {
    if (lastSearchQuery.value.trim().isNotEmpty) {
      return searchResults;
    }
    return patients;
  }

  bool get isDoctorSearching => lastSearchQuery.value.trim().isNotEmpty;

  Future<List<PatientModel>> _fetchAllPages({
    required Future<List<PatientModel>> Function(int skip, int limit) fetchPage,
    int pageSize = 100,
    int maxItems = 200000,
  }) async {
    final all = <PatientModel>[];
    var currentSkip = 0;

    while (true) {
      final page = await fetchPage(currentSkip, pageSize);
      if (page.isEmpty) break;

      all.addAll(page);
      if (page.length < pageSize) break;

      if (all.length >= maxItems) {
        print(
          '⚠️ [PatientController] Reached maxItems=$maxItems while fetching patients. Stopping pagination to avoid memory issues.',
        );
        break;
      }

      currentSkip += pageSize;
    }

    final seen = <String>{};
    final deduped = <PatientModel>[];
    for (final p in all) {
      if (seen.add(p.id)) deduped.add(p);
    }
    return deduped;
  }

  // جلب قائمة المرضى (للطبيب: pagination من API | للاستقبال: كاش + جلب كامل)
  Future<void> loadPatients({
    int skip = 0,
    int limit = 50,
    bool fetchAll = true,
    bool isInitial = false,
    bool isRefresh = false,
  }) async {
    if (_isDoctorUser) {
      await _loadDoctorPatientsPaginated(
        isInitial: isInitial,
        isRefresh: isRefresh,
      );
      return;
    }

    try {
      isLoading.value = true;
      print('📋 [PatientController] Loading patients with cache...');

      // 1) محاولة التحميل من الكاش أولاً (Hive)
      try {
        final box = Hive.box('patients');
        final cachedList = box.get('list');
        if (cachedList != null && cachedList is List) {
          final cachedPatients = cachedList
              .map(
                (json) => PatientModel.fromJson(
                  Map<String, dynamic>.from(json as Map),
                ),
              )
              .toList();
          if (cachedPatients.isNotEmpty) {
            patients.assignAll(cachedPatients);
            print(
              '✅ [PatientController] Loaded ${patients.length} patients from cache',
            );
          }
        }
      } catch (e) {
        print('❌ [PatientController] Error reading cache: $e');
      }

      // 2) جلب من الـ API وتحديث الكاش
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;
      print('📋 [PatientController] Current user type: $userType');

      List<PatientModel> patientsList;
      if (userType == 'receptionist') {
        // موظف الاستقبال: يجلب جميع المرضى من /reception/patients
        print('📋 [PatientController] Loading all patients (receptionist, API)...');
        if (fetchAll && skip == 0) {
          patientsList = await _fetchAllPages(
            fetchPage: (s, l) =>
                _patientService.getAllPatients(skip: s, limit: l),
            pageSize: 100,
          );
        } else {
          patientsList = await _patientService.getAllPatients(
            skip: skip,
            limit: limit,
          );
        }
      } else {
        // الطبيب — يُدار عبر _loadDoctorPatientsPaginated (لا يصل هنا)
        patientsList = await _doctorService.getMyPatients(
          skip: skip,
          limit: limit,
        );
      }

      patients.assignAll(patientsList);
      print('✅ [PatientController] Loaded ${patients.length} patients from API');

      // تحديث الكاش
      try {
        final box = Hive.box('patients');
        await box.put(
          'list',
          patients.map((p) => p.toJson()).toList(),
        );
        await box.put('lastUpdated', DateTime.now().toIso8601String());
        print(
          '💾 [PatientController] Cache updated with ${patients.length} patients',
        );
      } catch (e) {
        print('❌ [PatientController] Error updating cache: $e');
      }
    } on ApiException catch (e) {
      print('❌ [PatientController] ApiException: ${e.message}');
      await NetworkUtils.showError(e);
    } catch (e) {
      print('❌ [PatientController] Error: $e');
      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء تحميل المرضى');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadDoctorPatientsPaginated({
    required bool isInitial,
    required bool isRefresh,
  }) async {
    try {
      if (isRefresh || isInitial) {
        doctorCurrentPage = 1;
        hasMorePatients.value = true;
        // لا نُظهر سبينر إن وُجدت بيانات — يمنع وميض الواجهة (مثل desktop)
        if (patients.isEmpty) {
          isLoading.value = true;
        }
      } else {
        if (!hasMorePatients.value || isLoadingMorePatients.value) return;
        isLoadingMorePatients.value = true;
      }

      print(
        '📋 [PatientController] Loading doctor patients - page: $doctorCurrentPage, limit: $doctorPageLimit',
      );

      final patientsList = await _doctorService.getMyPatients(
        skip: (doctorCurrentPage - 1) * doctorPageLimit,
        limit: doctorPageLimit,
      );

      if (isRefresh || isInitial) {
        patients.assignAll(patientsList);
      } else {
        patients.addAll(patientsList);
      }

      hasMorePatients.value = patientsList.length >= doctorPageLimit;
      if (hasMorePatients.value) {
        doctorCurrentPage++;
      }

      print(
        '✅ [PatientController] Loaded ${patientsList.length} patients (total: ${patients.length}, hasMore: ${hasMorePatients.value})',
      );
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
    } catch (e) {
      await NetworkUtils.showError(
        e,
        fallbackMessage: 'حدث خطأ أثناء تحميل المرضى',
      );
    } finally {
      isLoading.value = false;
      isLoadingMorePatients.value = false;
    }
  }

  Future<void> loadMorePatients() async {
    if (!_isDoctorUser) return;
    if (!hasMorePatients.value || isLoadingMorePatients.value) return;
    await _loadDoctorPatientsPaginated(isInitial: false, isRefresh: false);
  }

  Future<void> searchDoctorPatients({required String searchQuery}) async {
    if (!_isDoctorUser) return;

    final query = searchQuery.trim();
    if (query.isEmpty) {
      clearDoctorSearch();
      return;
    }

    if (query == lastSearchQuery.value && searchResults.isNotEmpty) {
      return;
    }

    try {
      doctorSearchPage = 1;
      hasMoreSearchResults.value = true;
      lastSearchQuery.value = query;
      isSearching.value = true;
      searchResults.clear();

      final results = await _doctorService.searchMyPatients(
        searchQuery: query,
        skip: 0,
        limit: doctorPageLimit,
      );

      searchResults.assignAll(results);
      hasMoreSearchResults.value = results.length >= doctorPageLimit;
      if (hasMoreSearchResults.value) {
        doctorSearchPage = 2;
      }
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
    } catch (e) {
      await NetworkUtils.showError(
        e,
        fallbackMessage: 'حدث خطأ أثناء البحث',
      );
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> loadMoreSearchResults() async {
    if (!_isDoctorUser) return;
    if (isLoadingMoreSearch.value || !hasMoreSearchResults.value) return;
    if (lastSearchQuery.value.trim().isEmpty) return;

    isLoadingMoreSearch.value = true;
    try {
      final results = await _doctorService.searchMyPatients(
        searchQuery: lastSearchQuery.value,
        skip: (doctorSearchPage - 1) * doctorPageLimit,
        limit: doctorPageLimit,
      );

      if (results.isNotEmpty) {
        searchResults.addAll(results);
        doctorSearchPage++;
        hasMoreSearchResults.value = results.length >= doctorPageLimit;
      } else {
        hasMoreSearchResults.value = false;
      }
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
    } catch (e) {
      await NetworkUtils.showError(
        e,
        fallbackMessage: 'حدث خطأ أثناء تحميل نتائج البحث',
      );
    } finally {
      isLoadingMoreSearch.value = false;
    }
  }

  void clearDoctorSearch() {
    lastSearchQuery.value = '';
    doctorSearchPage = 1;
    hasMoreSearchResults.value = true;
    isLoadingMoreSearch.value = false;
    isSearching.value = false;
    searchResults.clear();
  }

  Future<void> refreshDoctorPatients() async {
    clearDoctorSearch();
    await loadPatients(isInitial: false, isRefresh: true);
  }

  /// تطبيق ملف فرد العائلة المختار فوراً (بدون انتظار إعادة تحميل الشاشة).
  void applyActiveFamilyProfile(PatientModel profile) {
    myProfile.value = profile;
    myDoctor.value = null;
    myDoctors.clear();
    myDoctorsReady.value = false;
  }

  void resetHomeData() {
    myProfile.value = null;
    myDoctor.value = null;
    myDoctors.clear();
    myDoctorsReady.value = false;
  }

  /// يحمّل الملف والأطباء والمواعيد قبل فتح الرئيسية حتى لا تظهر حالة التصميم الفارغة.
  Future<void> loadHomeScreenData() async {
    final appointmentController = Get.find<AppointmentController>();
    await Future.wait<void>([
      loadMyProfile(),
      appointmentController.loadPatientAppointments(),
      loadMyDoctors(),
    ]);
  }

  // جلب بيانات المريض الحالي (للمريض)
  Future<void> loadMyProfile({bool showError = false}) async {
    try {
      isLoading.value = true;
      final authController = Get.find<AuthController>();
      final activeId = authController.patientProfileId.value;
      final profile = await _patientService.getMyProfile(patientId: activeId);
      myProfile.value = profile;
      authController.patientProfileId.value = profile.id;
    } on ApiException catch (e) {
      print('❌ [PatientController] Error loading profile: ${e.message}');
      if (showError) {
        Future.microtask(() => NetworkUtils.showError(e));
      }
    } catch (e) {
      print('❌ [PatientController] Error loading profile: $e');
      if (showError) {
        Future.microtask(
          () => NetworkUtils.showError(
            e,
            fallbackMessage: 'حدث خطأ أثناء تحميل البيانات',
          ),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  // تحديد نوع العلاج (للطبيب) مع تحديث متفائل + تراجع + تحديث الكاش
  Future<void> setTreatmentType({
    required String patientId,
    required String treatmentType,
  }) async {
    PatientModel? oldPatient;

    try {
      isLoading.value = true;

      // حفظ نسخة قديمة للتراجع
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        oldPatient = patients[index];

        // نسخة محدثة بشكل متفائل
        final optimisticPatient = PatientModel(
          id: oldPatient.id,
          name: oldPatient.name,
          phoneNumber: oldPatient.phoneNumber,
          gender: oldPatient.gender,
          age: oldPatient.age,
          city: oldPatient.city,
          imageUrl: oldPatient.imageUrl,
          doctorIds: oldPatient.doctorIds,
          treatmentHistory: <String>[
            ...?oldPatient.treatmentHistory,
            treatmentType,
          ],
          qrCodeData: oldPatient.qrCodeData,
          qrImagePath: oldPatient.qrImagePath,
        );

        patients[index] = optimisticPatient;
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = optimisticPatient;
        }

        // كاش متفائل
        try {
          final box = Hive.box('patients');
          await box.put(
            'list',
            patients.map((p) => p.toJson()).toList(),
          );
          await box.put('lastUpdated', DateTime.now().toIso8601String());
        } catch (_) {}
      }

      // إرسال الطلب إلى السيرفر
      final updatedPatient = await _doctorService.setTreatmentType(
        patientId: patientId,
        treatmentType: treatmentType,
      );

      // تحديث القائمة بالبيانات المؤكدة
      final newIndex = patients.indexWhere((p) => p.id == patientId);
      if (newIndex != -1) {
        patients[newIndex] = updatedPatient;
      }
      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }

      // تحديث الكاش
      try {
        final box = Hive.box('patients');
        await box.put(
          'list',
          patients.map((p) => p.toJson()).toList(),
        );
        await box.put('lastUpdated', DateTime.now().toIso8601String());
      } catch (_) {}

      Get.snackbar('نجح', 'تم تحديث نوع العلاج');
    } on ApiException catch (e) {
      // تراجع (Rollback)
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          final box = Hive.box('patients');
          await box.put(
            'list',
            patients.map((p) => p.toJson()).toList(),
          );
          await box.put('lastUpdated', DateTime.now().toIso8601String());
        } catch (_) {}
      }

      await NetworkUtils.showError(e);
    } catch (e) {
      // تراجع (Rollback)
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          final box = Hive.box('patients');
          await box.put(
            'list',
            patients.map((p) => p.toJson()).toList(),
          );
          await box.put('lastUpdated', DateTime.now().toIso8601String());
        } catch (_) {}
      }

      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء تحديث نوع العلاج');
    } finally {
      isLoading.value = false;
    }
  }

  PatientModel? getPatientById(String patientId) {
    final selected = selectedPatient.value;
    if (selected != null && selected.id == patientId) {
      return selected;
    }

    for (final patient in searchResults) {
      if (patient.id == patientId) return patient;
    }

    for (final patient in patients) {
      if (patient.id == patientId) return patient;
    }

    return null;
  }

  void upsertPatient(PatientModel patient) {
    final patientIndex = patients.indexWhere((p) => p.id == patient.id);
    if (patientIndex >= 0) {
      patients[patientIndex] = patient;
    } else {
      patients.add(patient);
    }

    final searchIndex = searchResults.indexWhere((p) => p.id == patient.id);
    if (searchIndex >= 0) {
      searchResults[searchIndex] = patient;
    }
  }

  Future<PatientModel?> ensurePatientLoaded(String patientId) async {
    final cached = getPatientById(patientId);
    if (cached != null) {
      selectPatient(cached);
      return cached;
    }

    if (_isDoctorUser) {
      try {
        final patient = await _doctorService.fetchPatientById(patientId);
        upsertPatient(patient);
        selectPatient(patient);
        return patient;
      } catch (e) {
        print('❌ [PatientController] ensurePatientLoaded error: $e');
        return null;
      }
    }

    await reloadPatientsList();
    final reloaded = getPatientById(patientId);
    if (reloaded != null) {
      selectPatient(reloaded);
    }
    return reloaded;
  }

  Future<void> reloadPatientsList() async {
    if (_isDoctorUser) {
      await refreshDoctorPatients();
    } else {
      await loadPatients();
    }
  }

  List<PatientModel> searchPatients(String query) {
    if (_isDoctorUser) {
      return doctorDisplayedPatients;
    }
    if (query.isEmpty) return patients;

    return patients.where((patient) {
      return patient.name.toLowerCase().contains(query.toLowerCase()) ||
          patient.phoneNumber.contains(query);
    }).toList();
  }

  void selectPatient(PatientModel? patient) {
    selectedPatient.value = patient;
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
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        oldPatient = patients[index];
      }

      final authController = Get.find<AuthController>();
      final userType =
          authController.currentUser.value?.userType.toLowerCase();

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
        final box = Hive.box('patients');
        box.put(
          'list',
          patients.map((p) => p.toJson()).toList(),
        );
        box.put('lastUpdated', DateTime.now().toIso8601String());
      } catch (_) {}
    } on ApiException catch (e) {
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
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
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
      }
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث بيانات المريض');
      }
      rethrow;
    }
  }

  // تحديث الأطباء المرتبطين بمريض معين في الواجهة بدون إعادة تحميل كاملة
  void updatePatientDoctorIds(String patientId, List<String> doctorIds) {
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
      imageUrl: patient.imageUrl,
      doctorIds: doctorIds,
      treatmentHistory: patient.treatmentHistory,
      qrCodeData: patient.qrCodeData,
      qrImagePath: patient.qrImagePath,
    );

    patients[index] = updatedPatient;

    // تحديث المريض المحدد إذا كان هو نفسه
    if (selectedPatient.value?.id == patientId) {
      selectedPatient.value = updatedPatient;
    }

    // تحديث الكاش
    try {
      final box = Hive.box('patients');
      box.put(
        'list',
        patients.map((p) => p.toJson()).toList(),
      );
      box.put('lastUpdated', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  // إضافة مريض جديد إلى القائمة وتعيينه كمريض محدد بدون إعادة تحميل كاملة
  void addPatient(PatientModel patient) {
    // نضيف المريض في بداية القائمة ليظهر كأحدث مريض
    patients.insert(0, patient);
    selectedPatient.value = patient;

    // تحديث الكاش بعد الإضافة
    try {
      final box = Hive.box('patients');
      box.put(
        'list',
        patients.map((p) => p.toJson()).toList(),
      );
      box.put('lastUpdated', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  // التحقق من وجود طبيب مرتبط بالمريض
  Future<bool> checkDoctorAssignment() async {
    try {
      final authController = Get.find<AuthController>();
      final profile = await _patientService.getMyProfile(
        patientId: authController.patientProfileId.value,
      );
      myProfile.value = profile;
      // التحقق من وجود primary_doctor_id
      return profile.doctorIds.isNotEmpty;
    } catch (e) {
      print('❌ [PatientController] Error checking doctor assignment: $e');
      return false;
    }
  }

  // جلب معلومات الطبيب المرتبط بالمريض
  Future<void> updateMyProfile({
    String? name,
    String? gender,
    int? age,
    String? city,
  }) async {
    try {
      isLoading.value = true;
      final authController = Get.find<AuthController>();
      final updatedProfile = await _patientService.updateMyProfile(
        patientId: authController.patientProfileId.value,
        name: name,
        gender: gender,
        age: age,
        city: city,
      );
      myProfile.value = updatedProfile;
      
      await loadMyProfile();
    } catch (e) {
      print('❌ [PatientController] Error updating profile: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> uploadMyProfileImage(File imageFile) async {
    final authController = Get.find<AuthController>();
    final updated = await _patientService.uploadMyProfileImage(
      imageFile: imageFile,
      patientId: authController.patientProfileId.value,
    );
    myProfile.value = updated;
  }

  Future<void> loadMyDoctor() async {
    try {
      isLoading.value = true;
      final authController = Get.find<AuthController>();
      final doctorInfo = await _patientService.getMyDoctor(
        patientId: authController.patientProfileId.value,
      );
      myDoctor.value = doctorInfo;
    } on ApiException catch (e) {
      print('❌ [PatientController] Error loading doctor: ${e.message}');
      // لا نعرض snackbar لأنه قد لا يكون هناك طبيب مرتبط
      myDoctor.value = null;
    } catch (e) {
      print('❌ [PatientController] Error loading doctor: $e');
      myDoctor.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  // جلب قائمة الأطباء المرتبطين بالمريض
  Future<void> loadMyDoctors() async {
    try {
      isLoading.value = true;
      final authController = Get.find<AuthController>();
      final doctorsList = await _patientService.getMyDoctors(
        patientId: authController.patientProfileId.value,
      );
      myDoctors.value = doctorsList;
      // أيضاً تحديث myDoctor للأول (للتوافق مع الكود القديم)
      if (doctorsList.isNotEmpty) {
        myDoctor.value = doctorsList[0];
      } else {
        myDoctor.value = null;
      }
      if (Get.isRegistered<PresenceController>()) {
        Get.find<PresenceController>().seedFromDoctors(doctorsList);
      }
    } on ApiException catch (e) {
      print('❌ [PatientController] Error loading doctors: ${e.message}');
      myDoctors.value = [];
      myDoctor.value = null;
    } catch (e) {
      print('❌ [PatientController] Error loading doctors: $e');
      myDoctors.value = [];
      myDoctor.value = null;
    } finally {
      myDoctorsReady.value = true;
      isLoading.value = false;
    }
  }
}
