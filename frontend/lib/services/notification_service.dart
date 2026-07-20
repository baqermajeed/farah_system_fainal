import 'package:farah_sys_final/services/api_service.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';

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
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      data: _parseData(json['data']),
      isRead: json['is_read'] == true,
      sentAt: _parseSentAt(json['sent_at']),
    );
  }

  static Map<String, dynamic> _parseData(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    return <String, dynamic>{};
  }

  /// السيرفر يخزّن UTC؛ إن جاء بدون Z/+00:00 نفترض UTC ثم نحوّل للمحلي.
  static DateTime _parseSentAt(dynamic raw) {
    try {
      var s = raw?.toString().trim() ?? '';
      if (s.isEmpty) return DateTime.now();

      if (s.endsWith('+00:00')) {
        s = '${s.substring(0, s.length - 6)}Z';
      }

      final hasTz = s.endsWith('Z') ||
          RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s);
      if (!hasTz && s.length >= 19) {
        s = '${s}Z';
      }

      final parsed = DateTime.parse(s);
      return parsed.toLocal();
    } catch (_) {
      return DateTime.now();
    }
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'is_read': isRead,
      'sent_at': sentAt.toUtc().toIso8601String(),
    };
  }
}

class NotificationService {
  final ApiService _api = ApiService();

  String? get _activePatientId {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().patientProfileId.value;
  }

  Future<List<NotificationModel>> getNotifications({
    int skip = 0,
    int limit = 30,
    bool unreadOnly = false,
    String? patientId,
  }) async {
    final query = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      'unread_only': unreadOnly,
    };
    final pid = patientId ?? _activePatientId;
    if (pid != null && pid.isNotEmpty) {
      query['patient_id'] = pid;
    }

    final response = await _api.get(
      '/notifications',
      queryParameters: query,
    );
    final list = response.data as List? ?? [];
    return list
        .whereType<Map>()
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> getUnreadCount({String? patientId}) async {
    final pid = patientId ?? _activePatientId;
    final query = <String, dynamic>{};
    if (pid != null && pid.isNotEmpty) {
      query['patient_id'] = pid;
    }
    final response = await _api.get(
      '/notifications/unread-count',
      queryParameters: query.isEmpty ? null : query,
    );
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

  Future<int> markAllAsRead({String? patientId}) async {
    final pid = patientId ?? _activePatientId;
    final response = await _api.post(
      '/notifications/mark-all-read',
      queryParameters: (pid != null && pid.isNotEmpty)
          ? {'patient_id': pid}
          : null,
    );
    final data = response.data;
    if (data is Map) {
      return (data['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
