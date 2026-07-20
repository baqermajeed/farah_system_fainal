import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';

/// Controller لشاشة مواعيد تاريخ محدد — المنطق والحالة خارج الـ View.
class AppointmentsByDateController extends GetxController {
  AppointmentController get appointmentController =>
      Get.find<AppointmentController>();
  PatientController get patientController => Get.find<PatientController>();

  DateTime? selectedDate;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    selectedDate = args?['date'] as DateTime?;
  }

  @override
  void onReady() {
    super.onReady();
    if (selectedDate != null) {
      loadAppointmentsForDate(selectedDate!);
    }
  }

  Future<void> loadAppointmentsForDate(DateTime date) async {
    // Normalize date to local date (remove time component)
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateFromStr = DateFormat('yyyy-MM-dd').format(normalizedDate);

    // date_to should be the next day (backend uses scheduled_at < end)
    final nextDay = normalizedDate.add(const Duration(days: 1));
    final dateToStr = DateFormat('yyyy-MM-dd').format(nextDay);

    // Load appointments for the selected date
    await appointmentController.loadDoctorAppointments(
      dateFrom: dateFromStr,
      dateTo: dateToStr,
    );

    // Load patients to get their names and images
    if (patientController.patients.isEmpty) {
      patientController.loadPatients();
    }
  }
}
