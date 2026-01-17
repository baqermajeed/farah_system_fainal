class AppointmentModel {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final DateTime date;
  final String time;
  final String status;
  final String? notes;
  final String? imagePath;
  final List<String> imagePaths;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.date,
    required this.time,
    required this.status,
    this.notes,
    this.imagePath,
    this.imagePaths = const [],
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    // Backend/Hive support logic adapted
    final scheduledAt = json['scheduled_at'] ?? json['date'];
    final dateTime = scheduledAt is String
        ? DateTime.parse(scheduledAt)
        : (scheduledAt is DateTime ? scheduledAt : DateTime.now());

    List<String> finalImagePaths = [];
    if (json['image_paths'] != null && json['image_paths'] is List) {
      finalImagePaths = List<String>.from(json['image_paths']);
    } else if (json['image_path'] != null) {
      finalImagePaths = [json['image_path']];
    }

    return AppointmentModel(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? json['patientId'] ?? '',
      patientName: json['patient_name'] ?? json['patientName'] ?? '',
      doctorId: json['doctor_id']?.toString() ?? json['doctorId'] ?? '',
      doctorName: json['doctor_name'] ?? json['doctorName'] ?? '',
      date: dateTime,
      time: json['time'] ?? _formatTime(dateTime),
      status: json['status'] ?? 'scheduled',
      notes: json['note'] ?? json['notes'],
      imagePath: json['image_path'],
      imagePaths: finalImagePaths,
    );
  }

  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'date': date.toIso8601String(),
      'time': time,
      'status': status,
      'notes': notes,
      'image_path': imagePath,
      'image_paths': imagePaths,
    };
  }
}
