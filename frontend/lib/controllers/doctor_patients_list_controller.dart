import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/models/patient_model.dart';

/// Controller لشاشة قائمة مرضى الطبيب — حالة البحث/الفلترة في الواجهة
/// بينما بيانات المرضى تُدار عبر [PatientController] المشترك.
class DoctorPatientsListController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;

  PatientController get patientController => Get.find<PatientController>();

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
  }

  @override
  void onReady() {
    super.onReady();
    patientController.loadPatients();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  // Extract MongoDB ObjectId timestamp (first 8 hex chars = seconds since epoch).
  int _objectIdSeconds(String id) {
    if (id.length < 8) return 0;
    return int.tryParse(id.substring(0, 8), radix: 16) ?? 0;
  }

  List<PatientModel> _sortNewestFirst(Iterable<PatientModel> patients) {
    final sorted = List<PatientModel>.from(patients);
    sorted.sort(
      (a, b) => _objectIdSeconds(b.id).compareTo(_objectIdSeconds(a.id)),
    );
    return sorted;
  }

  List<PatientModel> get filteredPatients {
    final raw = searchQuery.value.isEmpty
        ? patientController.patients
        : patientController.searchPatients(searchQuery.value);
    return _sortNewestFirst(raw);
  }

  void openPatientDetails(PatientModel patient) {
    patientController.selectPatient(patient);
    Get.toNamed(
      AppRoutes.patientDetails,
      arguments: {'patientId': patient.id},
    );
  }

  void openChat(String patientId) {
    Get.toNamed(AppRoutes.chat, arguments: {'patientId': patientId});
  }

  Future<bool?> addPatientAndReload() async {
    final result = await Get.toNamed(AppRoutes.addPatient);
    // Reload patients when returning from add patient screen
    patientController.loadPatients();
    return result as bool?;
  }
}
