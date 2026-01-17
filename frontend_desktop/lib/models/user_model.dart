class UserModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String userType;
  final String? gender;
  final int? age;
  final String? city;
  final String? imageUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.userType,
    this.gender,
    this.age,
    this.city,
    this.imageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // دعم كلا التنسيقين: Backend API و Hive
    final role = json['role'] ?? json['userType'] ?? '';
    final mappedUserType = _mapRoleToUserType(role);

    final rawId = json['user_id'] ?? json['id'];
    return UserModel(
      id: rawId?.toString() ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phone'] ?? json['phoneNumber'] ?? '',
      userType: mappedUserType,
      gender: json['gender'],
      age: json['age'],
      city: json['city'],
      imageUrl: json['imageUrl'],
    );
  }

  static String _mapRoleToUserType(String role) {
    switch (role.toLowerCase()) {
      case 'patient':
        return 'patient';
      case 'doctor':
        return 'doctor';
      case 'receptionist':
        return 'receptionist';
      case 'photographer':
        return 'photographer';
      case 'admin':
        return 'admin';
      default:
        return role.isNotEmpty ? role : 'patient';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'userType': userType,
      'gender': gender,
      'age': age,
      'city': city,
      'imageUrl': imageUrl,
    };
  }

  // CopyWith method for updating user data
  UserModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? userType,
    String? gender,
    int? age,
    String? city,
    String? imageUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userType: userType ?? this.userType,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      city: city ?? this.city,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
