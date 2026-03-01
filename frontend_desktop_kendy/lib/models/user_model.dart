import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phoneNumber;

  @HiveField(3)
  final String userType;

  @HiveField(4)
  final bool isDoctorManager;

  @HiveField(5)
  final String? gender;

  @HiveField(6)
  final int? age;

  @HiveField(7)
  final String? city;

  @HiveField(8)
  final String? imageUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.userType,
    this.isDoctorManager = false,
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
      isDoctorManager: (json['doctor_manager'] == true) || (json['doctorManager'] == true),
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
      case 'call_center':
        return 'call_center';
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
      'doctorManager': isDoctorManager,
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
    bool? isDoctorManager,
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
      isDoctorManager: isDoctorManager ?? this.isDoctorManager,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      city: city ?? this.city,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
