import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/doctor_home_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';

class DoctorStatsController extends GetxController {
  PatientController get _patients => Get.find<PatientController>();
  AppointmentController get _appointments => Get.find<AppointmentController>();
  DoctorHomeController get _home => Get.find<DoctorHomeController>();

  final RxBool isLoading = false.obs;

  String get totalPatientsLabel {
    final count = _patients.patients.length;
    if (_patients.hasMorePatients.value) return '$count+';
    return '$count';
  }

  int get totalPatients => _patients.patients.length;

  int get todayAppointmentsCount => _home.todayAppointments.length;

  int get totalUnreadMessages => _home.totalUnreadCount;

  int get activeTreatments {
    return _patients.patients
        .where(
          (p) =>
              p.treatmentHistory != null && p.treatmentHistory!.isNotEmpty,
        )
        .length;
  }

  Map<String, int> get treatmentDistribution {
    final counts = <String, int>{};
    for (final patient in _patients.patients) {
      final treatment = patient.treatmentHistory != null &&
              patient.treatmentHistory!.isNotEmpty
          ? patient.treatmentHistory!.last
          : 'غير محدد';
      counts[treatment] = (counts[treatment] ?? 0) + 1;
    }
    return counts;
  }

  List<AppointmentModel> get weekAppointments {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday % 7));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _appointments.appointments.where((a) {
      final d = DateTime(a.date.year, a.date.month, a.date.day);
      return !d.isBefore(weekStart) && d.isBefore(weekEnd);
    }).toList();
  }

  List<int> get dailyAppointmentCounts {
    final counts = List<int>.filled(7, 0);
    final now = DateTime.now();
    for (final appointment in weekAppointments) {
      final diff = DateTime(appointment.date.year, appointment.date.month,
              appointment.date.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      if (diff >= -6 && diff <= 0) {
        counts[6 + diff]++;
      }
    }
    return counts;
  }

  Future<void> loadStats() async {
    try {
      isLoading.value = true;
      await Future.wait([
        _patients.refreshDoctorPatients(),
        _appointments.loadDoctorAppointments(),
        _home.loadUnreadCounts(),
        _home.loadTodayAppointments(),
      ]);
    } finally {
      isLoading.value = false;
    }
  }
}
