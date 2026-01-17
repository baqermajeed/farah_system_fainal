import 'package:get/get.dart';
import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';

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

      // لا حاجة لفحص النوع الآن لأننا في تطبيق الديسك توب للأطباء حالياً، أو يمكننا فحصه إذا أردنا
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      if (userType == 'receptionist') {
        print(
          '📋 [PatientController] Receptionist mode - loading all patients',
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

      print('✅ [PatientController] Loaded ${patients.length} patients');
    } on ApiException catch (e) {
      print('❌ [PatientController] ApiException: ${e.message}');
      Get.snackbar('خطأ', e.message);
    } catch (e) {
      print('❌ [PatientController] Error: $e');
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المرضى');
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
    try {
      isLoading.value = true;
      final updatedPatient = await _doctorService.setTreatmentType(
        patientId: patientId,
        treatmentType: treatmentType,
      );

      // تحديث القائمة
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        patients[index] = updatedPatient;
      }

      // تحديث المريض المحدد إذا كان هو نفسه
      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }

      Get.snackbar('نجح', 'تم تحديث نوع العلاج');
    } on ApiException catch (e) {
      Get.snackbar('خطأ', e.message);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث نوع العلاج');
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
}
