class DoctorModel {
  final String id;
  final String userId;
  final String? name;
  final String phone;
  final String? imageUrl;
  final int todayTransfers;

  DoctorModel({
    required this.id,
    required this.userId,
    this.name,
    required this.phone,
    this.imageUrl,
    this.todayTransfers = 0,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name'],
      phone: json['phone'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      todayTransfers: json['today_transfers'] ?? 0,
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
