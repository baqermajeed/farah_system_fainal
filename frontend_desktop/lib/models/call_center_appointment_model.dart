import 'package:frontend_desktop/core/network/api_constants.dart';

class CallCenterAppointmentModel {
  final String id;
  final String patientName;
  final String patientPhone;
  final DateTime scheduledAt;
  final String createdByUsername;
  final DateTime? createdAt;
  /// تاريخ قبول الموعد من الاستقبال (للإحصائيات حسب شهر القبول).
  final DateTime? acceptedAt;
  final String governorate;
  final String platform;
  /// ملاحظة اختيارية من موظف الاتصالات عند الإضافة.
  final String note;
  /// "pending" = لم يُقبل بعد، "accepted" = قبله الاستقبال (يُعرض الصف بلون أخضر).
  final String status;
  /// فرع الموعد: farah_najaf أو kendy_baghdad (للعرض ومعرفة الـ API عند التعديل/الحذف).
  final String branch;

  CallCenterAppointmentModel({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    required this.scheduledAt,
    required this.createdByUsername,
    this.createdAt,
    this.acceptedAt,
    this.governorate = '',
    this.platform = '',
    this.note = '',
    this.status = 'pending',
    this.branch = '',
  });

  bool get isAccepted => status == 'accepted';

  /// اسم الفرع للعرض في الجدول.
  String get branchDisplay {
    if (branch == ApiConstants.callCenterBranchKendyBaghdad) {
      return 'عيادة الكندي بغداد';
    }
    if (branch == ApiConstants.callCenterBranchFarahNajaf) {
      return 'عيادة فرح النجف';
    }
    return branch.isNotEmpty ? branch : '-';
  }

  factory CallCenterAppointmentModel.fromJson(
    Map<String, dynamic> json, {
    String? branch,
  }) {
    final scheduledRaw = (json['scheduled_at'] ?? '').toString();
    final createdRaw = (json['created_at'] ?? '').toString();
    final acceptedRaw = (json['accepted_at'] ?? '').toString();
    return CallCenterAppointmentModel(
      id: (json['id'] ?? '').toString(),
      patientName: (json['patient_name'] ?? '').toString(),
      patientPhone: (json['patient_phone'] ?? '').toString(),
      scheduledAt: DateTime.tryParse(scheduledRaw) ??
          DateTime.tryParse(scheduledRaw.replaceAll('Z', '+00:00')) ??
          DateTime.now(),
      createdByUsername: (json['created_by_username'] ?? '').toString(),
      createdAt: createdRaw.isEmpty
          ? null
          : DateTime.tryParse(createdRaw) ??
              DateTime.tryParse(createdRaw.replaceAll('Z', '+00:00')),
      acceptedAt: acceptedRaw.isEmpty
          ? null
          : DateTime.tryParse(acceptedRaw) ??
              DateTime.tryParse(acceptedRaw.replaceAll('Z', '+00:00')),
      governorate: (json['governorate'] ?? '').toString(),
      platform: (json['platform'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      branch: branch ?? (json['branch'] ?? '').toString(),
    );
  }
}

