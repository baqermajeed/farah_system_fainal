class DoctorModel {
  final String id;
  final String userId;
  final String? name;
  final String phone;
  final String? imageUrl;

  DoctorModel({
    required this.id,
    required this.userId,
    this.name,
    required this.phone,
    this.imageUrl,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name'],
      phone: json['phone'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'imageUrl': imageUrl,
    };
  }
}

