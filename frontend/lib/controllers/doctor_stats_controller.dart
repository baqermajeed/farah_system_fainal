import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/models/doctor_stats_model.dart';
import 'package:farah_sys_final/services/stats_service.dart';

class DoctorStatsController extends GetxController {
  final StatsService _statsService = StatsService();

  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  bool _fetchInProgress = false;

  final RxInt _totalPatients = 0.obs;
  final RxInt _newPatientsToday = 0.obs;
  final RxInt _newPatientsMonth = 0.obs;
  final RxList<DoctorStatsBreakdownItem> _patientStatusItems =
      <DoctorStatsBreakdownItem>[].obs;
  final RxList<DoctorStatsBreakdownItem> _genderItems =
      <DoctorStatsBreakdownItem>[].obs;
  final RxList<DoctorStatsAgeBucket> _ageBuckets = <DoctorStatsAgeBucket>[].obs;
  final RxList<DoctorStatsWeekDay> _weeklyAppointments =
      <DoctorStatsWeekDay>[].obs;
  final RxInt _weeklyAppointmentsTotal = 0.obs;
  final RxList<DoctorStatsBreakdownItem> _appointmentStatusItems =
      <DoctorStatsBreakdownItem>[].obs;
  final RxList<DoctorStatsTreatmentItem> _treatmentItems =
      <DoctorStatsTreatmentItem>[].obs;

  int get totalPatients => _totalPatients.value;
  String get totalPatientsLabel => '${_totalPatients.value}';
  int get newPatientsToday => _newPatientsToday.value;
  int get newPatientsMonth => _newPatientsMonth.value;
  List<DoctorStatsBreakdownItem> get patientStatusItems => _patientStatusItems;
  List<DoctorStatsBreakdownItem> get genderItems => _genderItems;
  List<DoctorStatsAgeBucket> get ageBuckets => _ageBuckets;
  List<DoctorStatsWeekDay> get weeklyAppointments => _weeklyAppointments;
  int get weeklyAppointmentsTotal => _weeklyAppointmentsTotal.value;
  List<DoctorStatsBreakdownItem> get appointmentStatusItems =>
      _appointmentStatusItems;
  List<DoctorStatsTreatmentItem> get treatmentItems => _treatmentItems;

  bool get showDemographics =>
      _genderItems.any((item) => item.count > 0) || _ageBuckets.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    loadStats();
  }

  Future<void> loadStats() async {
    if (_fetchInProgress) return;

    _fetchInProgress = true;
    isLoading.value = true;
    hasError.value = false;

    try {
      final doctorId = await _statsService.resolveDoctorId();
      final data = await _statsService
          .getDoctorMobileDashboard(doctorId)
          .timeout(const Duration(seconds: 30));

      if (data.containsKey('detail')) {
        hasError.value = true;
        return;
      }

      _applyDashboard(data);
    } catch (e, stack) {
      hasError.value = true;
      if (kDebugMode) {
        debugPrint('[DoctorStatsController] loadStats error: $e');
        debugPrint('$stack');
      }
    } finally {
      isLoading.value = false;
      _fetchInProgress = false;
    }
  }

  void _applyDashboard(Map<String, dynamic> data) {
    final patients = (data['patients'] as Map?)?.cast<String, dynamic>() ?? {};
    _totalPatients.value = _asInt(patients['total']);
    _newPatientsToday.value = _asInt(patients['new_today']);
    _newPatientsMonth.value = _asInt(patients['new_month']);

    _patientStatusItems.assignAll(
      _parseBreakdownItems(data['patient_status']),
    );

    final demographics =
        (data['demographics'] as Map?)?.cast<String, dynamic>() ?? {};
    _genderItems.assignAll(
      _parseBreakdownItems(demographics['gender']),
    );
    _ageBuckets.assignAll(
      (demographics['age_buckets'] as List? ?? [])
          .whereType<Map>()
          .map((item) => DoctorStatsAgeBucket.fromJson(item.cast<String, dynamic>()))
          .where((item) => item.label.isNotEmpty)
          .toList(),
    );

    final weekly =
        (data['weekly_appointments'] as Map?)?.cast<String, dynamic>() ?? {};
    _weeklyAppointmentsTotal.value = _asInt(weekly['total']);
    _weeklyAppointments.assignAll(
      (weekly['items'] as List? ?? [])
          .whereType<Map>()
          .map((item) => DoctorStatsWeekDay.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );

    _appointmentStatusItems.assignAll(
      _parseBreakdownItems(data['appointment_status_month']),
    );

    final treatment =
        (data['treatment_distribution'] as Map?)?.cast<String, dynamic>() ?? {};
    _treatmentItems.assignAll(
      (treatment['items'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                DoctorStatsTreatmentItem.fromJson(item.cast<String, dynamic>()),
          )
          .where((item) => item.type.isNotEmpty)
          .toList(),
    );
  }

  List<DoctorStatsBreakdownItem> _parseBreakdownItems(dynamic section) {
    if (section is! Map) return const [];
    final items = section['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => DoctorStatsBreakdownItem.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.label.isNotEmpty)
        .toList();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
