class ImplantStageModel {
  final String id;
  final String patientId;
  final String stageName;
  final DateTime scheduledAt;
  final bool isCompleted;
  final String? appointmentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ImplantStageModel({
    required this.id,
    required this.patientId,
    required this.stageName,
    required this.scheduledAt,
    required this.isCompleted,
    this.appointmentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ImplantStageModel.fromJson(Map<String, dynamic> json) {
    // تحويل أي تاريخ/وقت قادم من الباكند إلى التوقيت المحلي مباشرة
    DateTime parseDateTime(dynamic dateTimeValue) {
      if (dateTimeValue == null) {
        return DateTime.now().toLocal();
      }

      if (dateTimeValue is String) {
        try {
          final parsed = DateTime.parse(dateTimeValue);
          // إذا كان UTC نحوله إلى local، وإذا كان بدون timezone نعتبره أصلاً local
          return parsed.toLocal();
        } catch (e) {
          print(
            '⚠️ [ImplantStageModel] Error parsing timestamp: $dateTimeValue, error: $e',
          );
          return DateTime.now().toLocal();
        }
      } else if (dateTimeValue is DateTime) {
        return dateTimeValue.toLocal();
      } else {
        return DateTime.now().toLocal();
      }
    }
    
    final rawAppointmentId = json['appointment_id'];
    final appointmentIdStr = rawAppointmentId?.toString().trim();
    final normalizedAppointmentId =
        (appointmentIdStr == null ||
                appointmentIdStr.isEmpty ||
                appointmentIdStr.toLowerCase() == 'null')
            ? null
            : appointmentIdStr;

    return ImplantStageModel(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      stageName: json['stage_name'] ?? '',
      scheduledAt: parseDateTime(json['scheduled_at']),
      isCompleted: json['is_completed'] ?? false,
      appointmentId: normalizedAppointmentId,
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'stage_name': stageName,
      'scheduled_at': scheduledAt.toIso8601String(),
      'is_completed': isCompleted,
      'appointment_id': appointmentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
