import 'package:hive/hive.dart';

part 'patient_model.g.dart';

@HiveType(typeId: 1)
class PatientModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phoneNumber;

  @HiveField(3)
  final String gender;

  @HiveField(4)
  final int age;

  @HiveField(5)
  final String city;

  @HiveField(6)
  final String? visitType; // "مريض جديد" | "مراجع قديم"

  @HiveField(7)
  final String? imageUrl;

  @HiveField(8)
  final List<String> doctorIds;

  @HiveField(9)
  final List<String>? treatmentHistory;

  @HiveField(10)
  final String? qrCodeData;

  @HiveField(11)
  final String? qrImagePath;

  @HiveField(12)
  final List<String>? paymentMethods;

  PatientModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.gender,
    required this.age,
    required this.city,
    this.visitType,
    this.imageUrl,
    this.doctorIds = const [],
    this.treatmentHistory,
    this.qrCodeData,
    this.qrImagePath,
    this.paymentMethods,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      gender: json['gender'] ?? '',
      age: json['age'] ?? 0,
      city: json['city'] ?? '',
      visitType: json['visit_type'] ?? json['visitType'],
      imageUrl: json['imageUrl'],
      doctorIds: json['doctor_ids'] != null
          ? List<String>.from(json['doctor_ids'])
          : (json['doctorIds'] != null
                ? List<String>.from(json['doctorIds'])
                : const []),
      treatmentHistory: json['treatmentHistory'] != null
          ? List<String>.from(json['treatmentHistory'])
          : null,
      qrCodeData: json['qr_code_data'] ?? json['qrCodeData'],
      qrImagePath: json['qr_image_path'] ?? json['qrImagePath'],
      paymentMethods: json['payment_methods'] != null
          ? List<String>.from(json['payment_methods'])
          : (json['paymentMethods'] != null
              ? List<String>.from(json['paymentMethods'])
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'gender': gender,
      'age': age,
      'city': city,
      'visitType': visitType,
      'imageUrl': imageUrl,
      'doctorIds': doctorIds,
      'treatmentHistory': treatmentHistory,
      'qrCodeData': qrCodeData,
      'qrImagePath': qrImagePath,
      'paymentMethods': paymentMethods,
    };
  }
}
