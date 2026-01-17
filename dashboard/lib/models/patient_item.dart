class PatientItem {
  final String id;
  final String userId;
  final String? name;
  final String phone;
  final String? treatmentType;
  final String? imageUrl;

  PatientItem({
    required this.id,
    required this.userId,
    required this.phone,
    this.name,
    this.treatmentType,
    this.imageUrl,
  });

  factory PatientItem.fromJson(Map<String, dynamic> json) => PatientItem(
        id: (json['id'] ?? '').toString(),
        userId: (json['user_id'] ?? '').toString(),
        name: json['name']?.toString(),
        phone: (json['phone'] ?? '').toString(),
        treatmentType: json['treatment_type']?.toString(),
        imageUrl: json['imageUrl']?.toString(),
      );
}


