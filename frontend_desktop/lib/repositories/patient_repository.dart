import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/patient_service.dart';

class PatientRepository {
  PatientRepository({
    PatientService? patientService,
    DoctorService? doctorService,
  }) : _patientService = patientService ?? PatientService(),
       _doctorService = doctorService ?? DoctorService();

  final PatientService _patientService;
  final DoctorService _doctorService;

  Future<List<PatientModel>> fetchPatients({
    required String? userType,
    required int skip,
    required int limit,
  }) {
    if (userType == 'receptionist') {
      return _patientService.getAllPatients(skip: skip, limit: limit);
    }
    return _doctorService.getMyPatients(skip: skip, limit: limit);
  }

  Future<List<PatientModel>> searchPatients({
    required String? userType,
    required String query,
    required int skip,
    required int limit,
  }) {
    if (userType == 'receptionist') {
      return _patientService.searchPatients(
        searchQuery: query,
        skip: skip,
        limit: limit,
      );
    }
    return _doctorService.searchMyPatients(
      searchQuery: query,
      skip: skip,
      limit: limit,
    );
  }
}
