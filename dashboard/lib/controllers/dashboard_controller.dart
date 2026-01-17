import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../enums/patient_activity_filter_mode.dart';
import '../models/dashboard_stats.dart';
import '../models/patient_activity_stats.dart';
import '../services/stats_service.dart';

class DashboardController extends GetxController {
  final _service = StatsService();

  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final Rxn<DashboardStats> stats = Rxn<DashboardStats>();
  final Rx<PatientActivityFilterMode> patientActivityMode =
      PatientActivityFilterMode.daily.obs;
  final Rxn<PatientActivityStats> patientActivityStats =
      Rxn<PatientActivityStats>();

  DateTime? _patientActivityCustomFrom;
  DateTime? _patientActivityCustomTo;

  Future<void> refreshStats() async {
    loading.value = true;
    error.value = null;
    try {
      stats.value = await _service.getDashboard();
      await _loadPatientActivity();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> _loadPatientActivity({
    PatientActivityFilterMode? mode,
  }) async {
    final selectedMode = mode ?? patientActivityMode.value;
    patientActivityMode.value = selectedMode;
    final range = _rangeForMode(selectedMode);
    try {
      final data = await _service.getPatientActivity(
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


