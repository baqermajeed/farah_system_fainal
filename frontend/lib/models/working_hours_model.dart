class WorkingHoursModel {
  final String id;
  final String doctorId;
  final int dayOfWeek; // 0=Sunday, 6=Saturday
  final String startTime; // HH:MM format
  final String endTime; // HH:MM format
  final bool isWorking;
  final int slotDuration; // in minutes

  WorkingHoursModel({
    required this.id,
    required this.doctorId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isWorking,
    required this.slotDuration,
  });

  factory WorkingHoursModel.fromJson(Map<String, dynamic> json) {
    return WorkingHoursModel(
      id: json['id'] ?? '',
      doctorId: json['doctor_id'] ?? '',
      dayOfWeek: json['day_of_week'] ?? 0,
      startTime: json['start_time'] ?? '09:00',
      endTime: json['end_time'] ?? '17:00',
      isWorking: json['is_working'] ?? true,
      slotDuration: json['slot_duration'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isWorking': isWorking,
      'slotDuration': slotDuration,
    };
  }
}

