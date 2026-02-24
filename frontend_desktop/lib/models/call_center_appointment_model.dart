class CallCenterAppointmentModel {
  final String id;
  final String patientName;
  final String patientPhone;
  final DateTime scheduledAt;
  final String createdByUsername;
  final DateTime? createdAt;
  final String governorate;
  final String platform;
  /// ملاحظة اختيارية من موظف الاتصالات عند الإضافة.
  final String note;
  /// "pending" = لم يُقبل بعد، "accepted" = قبله الاستقبال (يُعرض الصف بلون أخضر).
  final String status;

  CallCenterAppointmentModel({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    required this.scheduledAt,
    required this.createdByUsername,
    this.createdAt,
    this.governorate = '',
    this.platform = '',
    this.note = '',
    this.status = 'pending',
  });

  bool get isAccepted => status == 'accepted';

  factory CallCenterAppointmentModel.fromJson(Map<String, dynamic> json) {
    final scheduledRaw = (json['scheduled_at'] ?? '').toString();
    final createdRaw = (json['created_at'] ?? '').toString();
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
      governorate: (json['governorate'] ?? '').toString(),
      platform: (json['platform'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
    );
  }
}

