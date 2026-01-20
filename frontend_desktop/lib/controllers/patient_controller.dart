import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';

class PatientController extends GetxController {
  final _patientService = PatientService();
  final _doctorService = DoctorService();

  final RxList<PatientModel> patients = <PatientModel>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<PatientModel?> selectedPatient = Rx<PatientModel?>(null);
  // for patient usage, currently we focus on doctor usage
  final Rx<PatientModel?> myProfile = Rx<PatientModel?>(null);

  // جلب قائمة المرضى (للطبيب)
  Future<void> loadPatients({int skip = 0, int limit = 50}) async {
    try {
      isLoading.value = true;
      print('📋 [PatientController] Loading doctor patients...');

      // 1) محاولة التحميل من الكاش أولاً (Hive)
      final box = Hive.box('patients');
      final cachedList = box.get('list');
      if (cachedList != null && cachedList is List) {
        try {
          final cachedPatients = cachedList
              .map(
                (json) => PatientModel.fromJson(
                  Map<String, dynamic>.from(json as Map),
                ),
              )
              .toList();
          patients.assignAll(cachedPatients);
          print(
            '✅ [PatientController] Loaded ${patients.length} patients from cache',
          );
        } catch (e) {
          print('❌ [PatientController] Error parsing cached patients: $e');
        }
      }

      // لا حاجة لفحص النوع الآن لأننا في تطبيق الديسك توب للأطباء حالياً، أو يمكننا فحصه إذا أردنا
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      if (userType == 'receptionist') {
        print(
          '📋 [PatientController] Receptionist mode - loading all patients (API)',
        );
        final patientsList = await _patientService.getAllPatients(
          skip: skip,
          limit: limit,
        );
        patients.value = patientsList;
      } else {
        final patientsList = await _doctorService.getMyPatients(
          skip: skip,
          limit: limit,
        );
        patients.value = patientsList;
      }

      print('✅ [PatientController] Loaded ${patients.length} patients from API');

      // 2) تحديث الكاش بعد نجاح الجلب من API
      try {
        await box.put(
          'list',
          patients.map((p) => p.toJson()).toList(),
        );
        await box.put(
          'lastUpdated',
          DateTime.now().toIso8601String(),
        );
        print('💾 [PatientController] Cache updated with ${patients.length} patients');
      } catch (e) {
        print('❌ [PatientController] Error updating cache: $e');
      }
    } on ApiException catch (e) {
      print('❌ [PatientController] ApiException: ${e.message}');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', e.message);
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
    }
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

        // تحديث الكاش بشكل متفائل
        try {
          final box = Hive.box('patients');
          box.put(
            'list',
            patients.map((p) => p.toJson()).toList(),
          );
          box.put('lastUpdated', DateTime.now().toIso8601String());
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

      // تحديث الكاش بالبيانات المؤكدة من السيرفر
      try {
        final box = Hive.box('patients');
        box.put(
          'list',
          patients.map((p) => p.toJson()).toList(),
        );
        box.put('lastUpdated', DateTime.now().toIso8601String());
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
          final box = Hive.box('patients');
          box.put(
            'list',
            patients.map((p) => p.toJson()).toList(),
          );
          box.put('lastUpdated', DateTime.now().toIso8601String());
        } catch (_) {}
      }

      // حوار تحذير للمستخدم أو سناك بار حسب نوع الخطأ
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', e.message);
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
          final box = Hive.box('patients');
          box.put(
            'list',
            patients.map((p) => p.toJson()).toList(),
          );
          box.put('lastUpdated', DateTime.now().toIso8601String());
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

  PatientModel? getPatientById(String patientId) {
    try {
      return patients.firstWhere((p) => p.id == patientId);
    } catch (e) {
      return null;
    }
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
}
