class GalleryImageModel {
  final String id;
  final String patientId;
  final String imagePath;
  final String? note;
  final String createdAt;

  GalleryImageModel({
    required this.id,
    required this.patientId,
    required this.imagePath,
    this.note,
    required this.createdAt,
  });

  factory GalleryImageModel.fromJson(Map<String, dynamic> json) {
    return GalleryImageModel(
      id: json['id'] ?? '',
      patientId: json['patient_id'] ?? '',
      imagePath: json['image_path'] ?? '',
      note: json['note'],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'image_path': imagePath,
      'note': note,
      'created_at': createdAt,
    };
  }
}

