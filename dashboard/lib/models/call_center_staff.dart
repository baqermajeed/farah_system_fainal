class CallCenterStaff {
  final String id;
  final String? name;
  final String? phone;
  final String? imageUrl;

  CallCenterStaff({
    required this.id,
    this.name,
    this.phone,
    this.imageUrl,
  });

  factory CallCenterStaff.fromJson(Map<String, dynamic> json) {
    return CallCenterStaff(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

