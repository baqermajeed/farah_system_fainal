import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';

/// Controller لشاشة مواعيد حسب التاريخ أو الفترة — تصفية من السيرفر + pagination.
class AppointmentsByDateController extends GetxController {
  AppointmentController get appointmentController =>
      Get.find<AppointmentController>();
  PatientController get patientController => Get.find<PatientController>();

  DateTime? startDate;
  DateTime? endDate;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    final singleDate = args?['date'] as DateTime?;
    startDate = args?['startDate'] as DateTime? ?? singleDate;
    endDate = args?['endDate'] as DateTime? ?? singleDate;
  }

  @override
  void onReady() {
    super.onReady();
    if (startDate != null && endDate != null) {
      loadAppointments();
    }
  }

  Future<void> loadAppointments() async {
    if (startDate == null || endDate == null) return;

    final normalizedStart = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
    );
    final normalizedEnd = DateTime(
      endDate!.year,
      endDate!.month,
      endDate!.day,
    );

    await appointmentController.loadDoctorAppointments(
      isInitial: true,
      isRefresh: true,
      filter: 'تصفية مخصصة',
      customFilterStart: normalizedStart,
      customFilterEnd: normalizedEnd,
    );

    if (patientController.patients.isEmpty) {
      await patientController.reloadPatientsList();
    }
  }

  Future<void> loadMore() async {
    if (startDate == null || endDate == null) return;

    await appointmentController.loadMoreAppointments(
      filter: 'تصفية مخصصة',
      customFilterStart: DateTime(
        startDate!.year,
        startDate!.month,
        startDate!.day,
      ),
      customFilterEnd: DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
      ),
    );
  }

  Future<void> refreshAppointments() async {
    await loadAppointments();
  }
}
