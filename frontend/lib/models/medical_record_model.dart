import 'package:hive/hive.dart';

part 'medical_record_model.g.dart';

@HiveType(typeId: 3)
class MedicalRecordModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String patientId;

  @HiveField(2)
  final String doctorId;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String treatmentType;

  @HiveField(5)
  final String diagnosis;

  @HiveField(6)
  final List<String>? images;

  @HiveField(7)
  final String? notes;

  MedicalRecordModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.date,
    required this.treatmentType,
    required this.diagnosis,
    this.images,
    this.notes,
  });

  factory MedicalRecordModel.fromJson(Map<String, dynamic> json) {
    // دعم كلا التنسيقين: Backend API و Hive
    final createdAt = json['created_at'] ?? json['date'];
    final dateTime = createdAt is String 
        ? DateTime.parse(createdAt)
        : (createdAt is DateTime ? createdAt : DateTime.now());
    
    // دعم image_paths (الجديد) و image_path (القديم) و images
    final imagePaths = json['image_paths'];
    final imagePath = json['image_path'];
    final images = imagePaths != null && imagePaths is List && imagePaths.isNotEmpty
        ? List<String>.from(imagePaths.map((e) => e.toString()))
        : (imagePath != null 
            ? [imagePath.toString()]
            : (json['images'] != null 
                ? (json['images'] is List 
                    ? List<String>.from(json['images'].map((e) => e.toString()))
                    : null)
                : null));
    
    return MedicalRecordModel(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? json['patientId'] ?? '',
      doctorId: json['doctor_id']?.toString() ?? json['doctorId'] ?? '',
      date: dateTime,
      treatmentType: json['treatmentType'] ?? '',
      diagnosis: json['note'] ?? json['diagnosis'] ?? '',
      images: images,
      notes: json['note'] ?? json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'date': date.toIso8601String(),
      'treatmentType': treatmentType,
      'diagnosis': diagnosis,
      'images': images,
      'notes': notes,
    };
  }
}
