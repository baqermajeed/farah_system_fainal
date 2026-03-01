import 'package:hive/hive.dart';

part 'gallery_image_model.g.dart';

@HiveType(typeId: 5)
class GalleryImageModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String patientId;

  @HiveField(2)
  final String? doctorId;

  @HiveField(3)
  final String imagePath;

  @HiveField(4)
  final String? note;

  @HiveField(5)
  final String createdAt;

  GalleryImageModel({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.imagePath,
    this.note,
    required this.createdAt,
  });

  factory GalleryImageModel.fromJson(Map<String, dynamic> json) {
    return GalleryImageModel(
      id: json['id'] ?? '',
      patientId: json['patient_id'] ?? '',
      doctorId: json['doctor_id']?.toString() ??
          json['doctorId']?.toString() ??
          json['user_id']?.toString() ??
          json['userId']?.toString(),
      imagePath: json['image_path'] ?? '',
      note: json['note'],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'image_path': imagePath,
      'note': note,
      'created_at': createdAt,
    };
  }
}
