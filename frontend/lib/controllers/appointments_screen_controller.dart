import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/implant_stage_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';

/// Controller لشاشة مواعيد الطبيب (بها تبويبات) — المنطق والحالة خارج الـ View.
class AppointmentsScreenController extends GetxController
    with GetSingleTickerProviderStateMixin {
  AppointmentController get appointmentController =>
      Get.find<AppointmentController>();
  PatientController get patientController => Get.find<PatientController>();
  late ImplantStageController implantStageController;

  late final TabController tabController;

  /// Cache implant stages converted into appointments to avoid heavy
  /// recomputation inside Obx/build.
  final RxList<AppointmentModel> implantAppointmentsAll =
      <AppointmentModel>[].obs;
  Worker? _implantWorker;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 3, vsync: this);

    // Ensure controller exists once for this screen session.
    implantStageController = Get.find<ImplantStageController>();

    // Recompute implant appointments whenever patients or stages change
    // (debounced by GetX microtask scheduling).
    _implantWorker = everAll(
      [patientController.patients, implantStageController.stages],
      (_) => recomputeImplantAppointments(),
    );
  }

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appointmentController.loadDoctorAppointments();
      // Load patients to get their names and images
      if (patientController.patients.isEmpty) {
        patientController.loadPatients();
      }
      // Load implant stages for patients with زراعة treatment
      loadImplantStages();
    });
  }

  @override
  void onClose() {
    tabController.dispose();
    _implantWorker?.dispose();
    super.onClose();
  }

  Future<void> loadImplantStages() async {
    // جلب جميع المرضى الذين لديهم نوع علاج "زراعة"
    final implantPatients = patientController.patients.where((patient) {
      return patient.treatmentHistory != null &&
          patient.treatmentHistory!.isNotEmpty &&
          patient.treatmentHistory!.first == 'زراعة';
    }).toList();

    // Batch load implant stages to reduce repeated rebuilds / network churn
    try {
      await implantStageController.loadStagesForPatients(
        implantPatients.map((p) => p.id).toList(),
      );
    } catch (e) {
      print('❌ [AppointmentsScreenController] Error batch loading implant stages: $e');
    }
  }

  void recomputeImplantAppointments() {
    // Fast maps for lookups
    final patientById = {
      for (final p in patientController.patients) p.id: p,
    };

    final computed = <AppointmentModel>[];
    for (final stage in implantStageController.stages) {
      final patient = patientById[stage.patientId];
      if (patient == null) continue;

      final stageDate = stage.scheduledAt;
      computed.add(
        AppointmentModel(
          id: stage.id,
          patientId: stage.patientId,
          patientName: patient.name,
          doctorId: '',
          doctorName: '',
          date: stageDate,
          time:
              '${stageDate.hour.toString().padLeft(2, '0')}:${stageDate.minute.toString().padLeft(2, '0')}',
          status: stage.isCompleted ? 'completed' : 'scheduled',
          notes: 'مرحلة: ${stage.stageName}',
        ),
      );
    }

    implantAppointmentsAll.assignAll(computed);
  }

  List<AppointmentModel> filterImplantAppointments(String filter) {
    if (implantAppointmentsAll.isEmpty) return const [];

    final now = DateTime.now();
    switch (filter) {
      case 'اليوم':
        return implantAppointmentsAll.where((a) {
          return a.date.year == now.year &&
              a.date.month == now.month &&
              a.date.day == now.day;
        }).toList();
      case 'المتأخرون':
        return implantAppointmentsAll.where((a) {
          return a.date.isBefore(now) &&
              (a.status == 'pending' || a.status == 'scheduled');
        }).toList();
      case 'هذا الشهر':
        return implantAppointmentsAll.where((a) {
          return a.date.year == now.year && a.date.month == now.month;
        }).toList();
      default:
        return const [];
    }
  }
}
