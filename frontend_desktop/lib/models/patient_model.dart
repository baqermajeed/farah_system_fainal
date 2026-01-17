class PatientModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String gender;
  final int age;
  final String city;
  final String? imageUrl;
  final List<String> doctorIds;
  final List<String>? treatmentHistory;
  final String? qrCodeData;
  final String? qrImagePath;

  PatientModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.gender,
    required this.age,
    required this.city,
    this.imageUrl,
    this.doctorIds = const [],
    this.treatmentHistory,
    this.qrCodeData,
    this.qrImagePath,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      gender: json['gender'] ?? '',
      age: json['age'] ?? 0,
      city: json['city'] ?? '',
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
      'imageUrl': imageUrl,
      'doctorIds': doctorIds,
      'treatmentHistory': treatmentHistory,
      'qrCodeData': qrCodeData,
      'qrImagePath': qrImagePath,
    };
  }
}
