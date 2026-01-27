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
    // قراءة today_transfers بطرق مختلفة للتأكد
    int transfers = 0;
    if (json['today_transfers'] != null) {
      transfers = json['today_transfers'] is int 
          ? json['today_transfers'] 
          : int.tryParse(json['today_transfers'].toString()) ?? 0;
    }
    
    print('🔍 [DoctorModel] Parsing doctor: ${json['name']}, today_transfers: ${json['today_transfers']}, parsed: $transfers');
    
    return DoctorModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name'],
      phone: json['phone'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      todayTransfers: transfers,
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
