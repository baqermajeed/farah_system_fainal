import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
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

  // جلب قائمة المرضى (للطبيب أو موظف الاستقبال) مع كاش Hive
  Future<void> loadPatients({
    int skip = 0,
    int limit = 50,
    bool fetchAll = true,
  }) async {
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
        // الطبيب (أو أي نوع آخر): يجلب مرضاه فقط من /doctor/patients
        print('📋 [PatientController] Loading doctor patients (API)...');
        if (fetchAll && skip == 0) {
          patientsList = await _fetchAllPages(
            fetchPage: (s, l) => _doctorService.getMyPatients(skip: s, limit: l),
            pageSize: 100,
          );
        } else {
          patientsList = await _doctorService.getMyPatients(
            skip: skip,
            limit: limit,
          );
        }

        if (patientsList.isEmpty) {
          print('⚠️ [PatientController] No patients found for this doctor!');
        }
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
      if (NetworkUtils.isNetworkError(e)) {
        await NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', e.message);
      }
    } catch (e) {
      print('❌ [PatientController] Error: $e');
      if (NetworkUtils.isNetworkError(e)) {
        await NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المرضى');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // جلب بيانات المريض الحالي (للمريض)
  Future<void> loadMyProfile({bool showError = false}) async {
    try {
      isLoading.value = true;
      final profile = await _patientService.getMyProfile();
      myProfile.value = profile;
      final authController = Get.find<AuthController>();
      authController.patientProfileId.value = profile.id;
    } on ApiException catch (e) {
      print('❌ [PatientController] Error loading profile: ${e.message}');
      if (showError) {
        // تأجيل عرض snackbar حتى بعد اكتمال البناء
        Future.microtask(() {
          Get.snackbar('خطأ', e.message);
        });
      }
    } catch (e) {
      print('❌ [PatientController] Error loading profile: $e');
      if (showError) {
        // تأجيل عرض snackbar حتى بعد اكتمال البناء
        Future.microtask(() {
          Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل البيانات');
        });
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

      if (NetworkUtils.isNetworkError(e)) {
        await NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', e.message);
      }
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

      if (NetworkUtils.isNetworkError(e)) {
        await NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث نوع العلاج');
      }
    } finally {
      isLoading.value = false;
    }
  }

  PatientModel? getPatientById(String patientId) {
    try {
      return patients.firstWhere((p) => p.id == patientId);
    } catch (e) {
      return null;
    }
  }

  List<PatientModel> searchPatients(String query) {
    if (query.isEmpty) return patients;

    return patients.where((patient) {
      return patient.name.toLowerCase().contains(query.toLowerCase()) ||
          patient.phoneNumber.contains(query);
    }).toList();
  }

  void selectPatient(PatientModel? patient) {
    selectedPatient.value = patient;
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
      final profile = await _patientService.getMyProfile();
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
      final updatedProfile = await _patientService.updateMyProfile(
        name: name,
        gender: gender,
        age: age,
        city: city,
      );
      myProfile.value = updatedProfile;
      
      // تحديث بيانات المستخدم أيضاً عبر إعادة جلب البيانات من السيرفر
      final authController = Get.find<AuthController>();
      await authController.checkLoggedInUser();
      
      // إعادة تحميل الملف الشخصي لضمان التحديث
      await loadMyProfile();
    } catch (e) {
      print('❌ [PatientController] Error updating profile: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMyDoctor() async {
    try {
      isLoading.value = true;
      final doctorInfo = await _patientService.getMyDoctor();
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
      final doctorsList = await _patientService.getMyDoctors();
      myDoctors.value = doctorsList;
      // أيضاً تحديث myDoctor للأول (للتوافق مع الكود القديم)
      if (doctorsList.isNotEmpty) {
        myDoctor.value = doctorsList[0];
      } else {
        myDoctor.value = null;
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
      isLoading.value = false;
    }
  }
}
