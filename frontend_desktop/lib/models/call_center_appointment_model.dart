class CallCenterAppointmentModel {
  final String id;
  final String patientName;
  final String patientPhone;
  final DateTime scheduledAt;
  final String createdByUsername;
  final DateTime? createdAt;

  CallCenterAppointmentModel({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    required this.scheduledAt,
    required this.createdByUsername,
    this.createdAt,
  });

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
    );
  }
}

