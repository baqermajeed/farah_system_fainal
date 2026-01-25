import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/app_colors.dart';
import '../enums/patient_activity_filter_mode.dart';
import '../models/doctor_profile.dart';
import '../models/patient_activity_stats.dart';
import '../services/stats_service.dart';
import '../services/admin_service.dart';

enum AppointmentFilterMode { total, daily, monthly, custom }
enum MessageFilterMode { total, daily, monthly, custom }

class DoctorProfileController extends GetxController {
  final String doctorId;
  DoctorProfileController({required this.doctorId});

  final _stats = StatsService();
  final _admin = AdminService();

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

  /// تعيين أو إلغاء خاصية "طبيب مدير"
  Future<void> setManagerStatus(bool isManager) async {
    try {
      // تحديث محلي فوري (optimistic update)
      final currentProfile = profile.value;
      if (currentProfile != null) {
        // إنشاء نسخة محدثة من الـ profile
        final updatedDoctor = DoctorProfileDoctor(
          doctorId: currentProfile.doctor.doctorId,
          userId: currentProfile.doctor.userId,
          name: currentProfile.doctor.name,
          phone: currentProfile.doctor.phone,
          imageUrl: currentProfile.doctor.imageUrl,
          isManager: isManager,
        );
        profile.value = DoctorProfile(
          doctor: updatedDoctor,
          counts: currentProfile.counts,
          messages: currentProfile.messages,
          appointments: currentProfile.appointments,
          transfers: currentProfile.transfers,
        );
      }

      // إرسال التحديث للـ backend
      await _admin.setDoctorManager(
        doctorId: doctorId,
        isManager: isManager,
      );

      // انتظار قصير للتأكد من تحديث الـ database
      await Future.delayed(const Duration(milliseconds: 300));

      // إعادة تحميل البيانات من الـ backend للتأكد
      await load();

      // التحقق من أن التحديث تم بنجاح
      final updatedProfile = profile.value;
      if (updatedProfile != null && updatedProfile.doctor.isManager != isManager) {
        // إذا لم يتطابق، نعيد التحديث المحلي
        final correctedDoctor = DoctorProfileDoctor(
          doctorId: updatedProfile.doctor.doctorId,
          userId: updatedProfile.doctor.userId,
          name: updatedProfile.doctor.name,
          phone: updatedProfile.doctor.phone,
          imageUrl: updatedProfile.doctor.imageUrl,
          isManager: isManager,
        );
        profile.value = DoctorProfile(
          doctor: correctedDoctor,
          counts: updatedProfile.counts,
          messages: updatedProfile.messages,
          appointments: updatedProfile.appointments,
          transfers: updatedProfile.transfers,
        );
      }

      // عرض رسالة النجاح
      Get.snackbar(
        'تم بنجاح',
        isManager
            ? 'تم تعيين الطبيب كطبيب مدير'
            : 'تم إلغاء خاصية طبيب مدير',
        backgroundColor: AppColors.success.withValues(alpha: 0.1),
        colorText: AppColors.success,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
        borderRadius: 16,
        icon: Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
        ),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      // في حالة الخطأ، نعيد الحالة القديمة
      await load();
      error.value = e.toString();
      Get.snackbar(
        'خطأ',
        'فشل تحديث حالة الطبيب: ${e.toString()}',
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        colorText: AppColors.error,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
        borderRadius: 16,
        icon: Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
        ),
        duration: const Duration(seconds: 3),
      );
      rethrow;
    }
  }
}


