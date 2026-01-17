class UserMe {
  final String id;
  final String? name;
  final String phone;
  final String role; // admin/doctor/...
  final String? imageUrl;

  UserMe({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
    this.imageUrl,
  });

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  bool get isAdmin => role == 'admin';
}
