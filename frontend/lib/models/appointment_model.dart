import 'package:hive/hive.dart';

part 'appointment_model.g.dart';

@HiveType(typeId: 2)
class AppointmentModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String patientId;

  @HiveField(2)
  final String patientName;

  @HiveField(3)
  final String doctorId;

  @HiveField(4)
  final String doctorName;

  @HiveField(5)
  final DateTime date;

  @HiveField(6)
  final String time;

  @HiveField(7)
  final String status;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final String? imagePath; // للتوافق مع البيانات القديمة

  @HiveField(10)
  final List<String> imagePaths; // قائمة الصور الجديدة
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
    this.imagePaths = const [], // Default to empty list
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    // دعم كلا التنسيقين: Backend API و Hive
    final scheduledAt = json['scheduled_at'] ?? json['date'];
    final dateTime = scheduledAt is String
        ? DateTime.parse(scheduledAt)
        : (scheduledAt is DateTime ? scheduledAt : DateTime.now());

    // للتوافق مع البيانات القديمة: إذا كانت image_paths موجودة، استخدمها، وإلا استخدم image_path
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
