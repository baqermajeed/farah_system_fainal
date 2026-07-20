import 'package:farah_sys_final/services/api_service.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime sentAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.isRead,
    required this.sentAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime sentAt;
    try {
      sentAt = DateTime.parse(json['sent_at']?.toString() ?? '').toLocal();
    } catch (_) {
      sentAt = DateTime.now();
    }

    final rawData = json['data'];
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      data: rawData is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{},
      isRead: json['is_read'] == true,
      sentAt: sentAt,
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      type: type,
      data: data,
      isRead: isRead ?? this.isRead,
      sentAt: sentAt,
    );
  }
}

class NotificationService {
  final ApiService _api = ApiService();

  Future<List<NotificationModel>> getNotifications({
    int skip = 0,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final response = await _api.get(
      '/notifications',
      queryParameters: {
        'skip': skip,
        'limit': limit,
        'unread_only': unreadOnly,
      },
    );
    final list = response.data as List? ?? [];
    return list
        .whereType<Map>()
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _api.get('/notifications/unread-count');
    final data = response.data;
    if (data is Map) {
      return (data['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<NotificationModel?> markAsRead(String notificationId) async {
    final response = await _api.patch('/notifications/$notificationId/read');
    final data = response.data;
    if (data is Map) {
      return NotificationModel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<int> markAllAsRead() async {
    final response = await _api.post('/notifications/mark-all-read');
    final data = response.data;
    if (data is Map) {
      return (data['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
