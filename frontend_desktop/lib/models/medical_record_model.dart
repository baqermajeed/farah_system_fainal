class MedicalRecordModel {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime date;
  final String treatmentType;
  final String diagnosis;
  final List<String>? images;
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
    final createdAt = json['created_at'] ?? json['date'];
    final dateTime = createdAt is String
        ? DateTime.parse(createdAt)
        : (createdAt is DateTime ? createdAt : DateTime.now());

    final imagePaths = json['image_paths'];
    final imagePath = json['image_path'];
    final images =
        imagePaths != null && imagePaths is List && imagePaths.isNotEmpty
        ? List<String>.from(imagePaths.map((e) => e.toString()))
        : (imagePath != null
              ? [imagePath.toString()]
              : (json['images'] != null
                    ? (json['images'] is List
                          ? List<String>.from(
                              json['images'].map((e) => e.toString()),
                            )
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
