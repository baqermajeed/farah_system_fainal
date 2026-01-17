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
    // تحويل scheduled_at من UTC إلى local time
    DateTime parseDateTime(dynamic dateTimeValue) {
      if (dateTimeValue == null) {
        return DateTime.now().toLocal();
      }
      
      if (dateTimeValue is String) {
        try {
          String timeString = dateTimeValue.trim();
          // التأكد من معاملة UTC بشكل صحيح
          if (timeString.endsWith('+00:00')) {
            timeString = timeString.replaceFirst('+00:00', 'Z');
          } else if (!timeString.endsWith('Z') && !timeString.contains('+') && !timeString.contains('-', 10)) {
            // إذا لم يكن هناك timezone indicator، نضيف 'Z' للافتراض أنه UTC
            if (timeString.length >= 19) {
              timeString = '${timeString}Z';
            }
          }
          final parsed = DateTime.parse(timeString);
          // تحويل من UTC إلى local time
          // DateTime.parse يجب أن يتعامل بشكل صحيح مع UTC timestamps
          return parsed.isUtc ? parsed.toLocal() : parsed;
        } catch (e) {
          print('⚠️ [ImplantStageModel] Error parsing timestamp: $dateTimeValue, error: $e');
          return DateTime.now().toLocal();
        }
      } else if (dateTimeValue is DateTime) {
        return dateTimeValue.isUtc ? dateTimeValue.toLocal() : dateTimeValue;
      } else {
        return DateTime.now().toLocal();
      }
    }
    
    return ImplantStageModel(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      stageName: json['stage_name'] ?? '',
      scheduledAt: parseDateTime(json['scheduled_at']),
      isCompleted: json['is_completed'] ?? false,
      appointmentId: json['appointment_id']?.toString(),
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

