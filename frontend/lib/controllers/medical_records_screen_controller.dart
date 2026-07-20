import 'package:get/get.dart';

import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';
import 'package:farah_sys_final/models/medical_record_model.dart';
import 'package:farah_sys_final/services/doctor_service.dart';

/// Controller لشاشة السجلات الطبية — المنطق والحالة خارج الـ View.
class MedicalRecordsScreenController extends GetxController {
  final DoctorService _doctorService = DoctorService();

  PatientController get patientController => Get.find<PatientController>();

  final RxList<MedicalRecordModel> records = <MedicalRecordModel>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<String?> selectedPatientId = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    loadRecords();
  }

  Future<void> loadRecords({String? patientId}) async {
    isLoading.value = true;
    try {
      if (patientId != null) {
        final loadedRecords = await _doctorService.getPatientNotes(
          patientId: patientId,
        );
        records.value = loadedRecords;
      } else {
        // Load all records for all patients
        // TODO: Implement getAllRecords when API is ready
        records.value = [];
      }
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
    } catch (e) {
      await NetworkUtils.showError(
        e,
        fallbackMessage: 'حدث خطأ أثناء تحميل السجلات',
      );
    } finally {
      isLoading.value = false;
    }
  }

  void selectPatient(String? patientId) {
    selectedPatientId.value = patientId;
    loadRecords(patientId: patientId);
  }
}
