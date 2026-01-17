import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../enums/patient_activity_filter_mode.dart';
import '../models/doctor_profile.dart';
import '../models/patient_activity_stats.dart';
import '../services/stats_service.dart';

enum AppointmentFilterMode { total, daily, monthly, custom }
enum MessageFilterMode { total, daily, monthly, custom }

class DoctorProfileController extends GetxController {
  final String doctorId;
  DoctorProfileController({required this.doctorId});

  final _stats = StatsService();

  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final Rxn<DoctorProfile> profile = Rxn<DoctorProfile>();

  final Rx<AppointmentFilterMode> appointmentMode =
      AppointmentFilterMode.total.obs;
  final Rx<MessageFilterMode> messageMode = MessageFilterMode.daily.obs;
  final Rx<PatientActivityFilterMode> patientActivityMode =
      PatientActivityFilterMode.daily.obs;
  final Rxn<PatientActivityStats> patientActivityStats =
      Rxn<PatientActivityStats>();

  DateTime? _from;
  DateTime? _to;
  DateTime? _patientActivityCustomFrom;
  DateTime? _patientActivityCustomTo;

  bool get hasRange => _from != null && _to != null;

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      profile.value = await _stats.getDoctorProfile(
        doctorId: doctorId,
        dateFromIso: _from?.toUtc().toIso8601String(),
        dateToIso: _to?.toUtc().toIso8601String(),
      );
      await _loadPatientActivity();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> setRange({required DateTime from, required DateTime to}) async {
    _from = from;
    _to = to;
    await load();
  }

  Future<void> _loadPatientActivity({
    PatientActivityFilterMode? mode,
  }) async {
    final selectedMode = mode ?? patientActivityMode.value;
    patientActivityMode.value = selectedMode;
    final range = _rangeForMode(selectedMode);
    try {
      final data = await _stats.getPatientActivity(
        doctorId: doctorId,
        dateFromIso: range.start.toUtc().toIso8601String(),
        dateToIso: range.end.toUtc().toIso8601String(),
      );
      patientActivityStats.value = data;
    } catch (_) {
      patientActivityStats.value = null;
    }
  }

  DateTimeRange _rangeForMode(PatientActivityFilterMode mode) {
    final now = DateTime.now();
    switch (mode) {
      case PatientActivityFilterMode.daily:
        final start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
      case PatientActivityFilterMode.monthly:
        final start = DateTime(now.year, now.month, 1);
        final nextMonth = DateTime(
          start.month == 12 ? start.year + 1 : start.year,
          start.month == 12 ? 1 : start.month + 1,
          1,
        );
        return DateTimeRange(start: start, end: nextMonth);
      case PatientActivityFilterMode.custom:
        return _customPatientActivityRange();
    }
  }

  DateTimeRange _customPatientActivityRange() {
    final now = DateTime.now();
    if (_patientActivityCustomFrom == null || _patientActivityCustomTo == null) {
      final start = DateTime(now.year, now.month, now.day);
      return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
    }
    final exclusiveTo =
        _patientActivityCustomTo!.add(const Duration(days: 1));
    return DateTimeRange(start: _patientActivityCustomFrom!, end: exclusiveTo);
  }

  Future<void> setPatientActivityMode(
    PatientActivityFilterMode mode,
  ) async {
    if (mode == PatientActivityFilterMode.custom &&
        (_patientActivityCustomFrom == null || _patientActivityCustomTo == null)) {
      await _loadPatientActivity(mode: PatientActivityFilterMode.daily);
      return;
    }
    await _loadPatientActivity(mode: mode);
  }

  Future<void> setPatientActivityCustomRange({
    required DateTime from,
    required DateTime to,
  }) async {
    _patientActivityCustomFrom = from;
    _patientActivityCustomTo = to;
    patientActivityMode.value = PatientActivityFilterMode.custom;
    await _loadPatientActivity(mode: PatientActivityFilterMode.custom);
  }
}


