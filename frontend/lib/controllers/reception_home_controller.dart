import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/models/patient_model.dart';

/// Controller لشاشة الرئيسية لموظف الاستقبال — منطق البحث والتنقل خارج الـ View (نمط GetX MVC).
class ReceptionHomeController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;

  PatientController get _patientController => Get.find<PatientController>();

  RxBool get isLoading => _patientController.isLoading;

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
    _patientController.loadPatients();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  List<PatientModel> get filteredPatients {
    return searchQuery.value.isEmpty
        ? _patientController.patients
        : _patientController.searchPatients(searchQuery.value);
  }

  void openPatient(PatientModel patient) {
    _patientController.selectPatient(patient);
    Get.toNamed(
      AppRoutes.patientDetails,
      arguments: {'patientId': patient.id},
    );
  }
}
