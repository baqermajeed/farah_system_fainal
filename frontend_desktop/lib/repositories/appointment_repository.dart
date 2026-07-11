import 'package:frontend_desktop/models/appointment_model.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/patient_service.dart';

class AppointmentRepository {
  AppointmentRepository({
    DoctorService? doctorService,
    PatientService? patientService,
  }) : _doctorService = doctorService ?? DoctorService(),
       _patientService = patientService ?? PatientService();

  final DoctorService _doctorService;
  final PatientService _patientService;

  Future<Map<String, List<AppointmentModel>>> fetchCurrentUserAppointments() {
    return _patientService.getMyAppointments();
  }

  Future<List<AppointmentModel>> fetchStaffAppointments({
    required String? userType,
    String? day,
    String? dateFrom,
    String? dateTo,
    String? status,
    required int skip,
    required int limit,
  }) {
    if (userType == 'receptionist') {
      return _doctorService.getAllAppointmentsForReception(
        day: day,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        skip: skip,
        limit: limit,
      );
    }

    if (userType == 'call_center') {
      return _doctorService.getAllAppointmentsForCallCenter(
        day: day,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        skip: skip,
        limit: limit,
      );
    }

    return _doctorService.getMyAppointments(
      day: day,
      dateFrom: dateFrom,
      dateTo: dateTo,
      status: status,
      skip: skip,
      limit: limit,
    );
  }

  Future<List<AppointmentModel>> fetchPatientAppointments({
    required String patientId,
    int skip = 0,
    int limit = 50,
  }) {
    return _doctorService.getPatientAppointments(
      patientId,
      skip: skip,
      limit: limit,
    );
  }
}
