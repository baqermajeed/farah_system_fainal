import 'package:hive/hive.dart';

part 'doctor_model.g.dart';

@HiveType(typeId: 3)
class DoctorModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String? name;

  @HiveField(3)
  final String phone;

  @HiveField(4)
  final String? imageUrl;

  @HiveField(5)
  final int todayTransfers;

  @HiveField(6)
  final DateTime? lastTransferAt;

  DoctorModel({
    required this.id,
    required this.userId,
    this.name,
    required this.phone,
    this.imageUrl,
    this.todayTransfers = 0,
    this.lastTransferAt,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    // قراءة today_transfers بطرق مختلفة للتأكد
    int transfers = 0;
    if (json['today_transfers'] != null) {
      transfers = json['today_transfers'] is int 
          ? json['today_transfers'] 
          : int.tryParse(json['today_transfers'].toString()) ?? 0;
    }

    // قراءة آخر تاريخ تحويل للطبيب إن وجد
    DateTime? lastTransferAt;
    if (json['last_transfer_at'] != null) {
      try {
        lastTransferAt = DateTime.parse(json['last_transfer_at'].toString());
      } catch (_) {
        lastTransferAt = null;
      }
    }

    print('🔍 [DoctorModel] Parsing doctor: ${json['name']}, today_transfers: ${json['today_transfers']}, parsed: $transfers');
    
    return DoctorModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name'],
      phone: json['phone'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      todayTransfers: transfers,
      lastTransferAt: lastTransferAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'imageUrl': imageUrl,
      if (lastTransferAt != null) 'last_transfer_at': lastTransferAt!.toIso8601String(),
    };
  }
}
