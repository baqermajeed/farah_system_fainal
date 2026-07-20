import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/services/auth_service.dart';

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

  String? get patientId {
    final raw = data['patientId'] ?? data['patient_id'];
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  /// هل يظهر هذا الإشعار لفرد العائلة المحدد؟
  bool belongsToPatient(String? activePatientId) {
    if (activePatientId == null || activePatientId.isEmpty) return false;
    final scoped = patientId;
    if (scoped != null) {
      return scoped == activePatientId;
    }
    // إشعارات عامة للحساب فقط (broadcast)
    return type.toLowerCase() == 'general';
  }

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

  static DateTime _parseSentAt(dynamic raw) {
    try {
      var s = raw?.toString().trim() ?? '';
      if (s.isEmpty) return DateTime.now();

      if (s.endsWith('+00:00')) {
        s = '${s.substring(0, s.length - 6)}Z';
      }

      final hasTz =
          s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s);
      if (!hasTz && s.length >= 19) {
        s = '${s}Z';
      }

      return DateTime.parse(s).toLocal();
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
  final AuthService _authService = AuthService();

  Future<String> resolveActivePatientId({String? patientId}) async {
    if (patientId != null && patientId.isNotEmpty) return patientId;

    if (Get.isRegistered<AuthController>()) {
      final memory = Get.find<AuthController>().patientProfileId.value;
      if (memory != null && memory.isNotEmpty) return memory;
    }

    final stored = await _authService.getActivePatientId();
    if (stored != null && stored.isNotEmpty) {
      if (Get.isRegistered<AuthController>()) {
        Get.find<AuthController>().patientProfileId.value = stored;
      }
      return stored;
    }

    throw ApiException('لم يتم تحديد فرد العائلة النشط للإشعارات');
  }

  Future<List<NotificationModel>> getNotifications({
    int skip = 0,
    int limit = 30,
    bool unreadOnly = false,
    String? patientId,
  }) async {
    final pid = await resolveActivePatientId(patientId: patientId);
    final response = await _api.get(
      '/notifications',
      queryParameters: {
        'skip': skip,
        'limit': limit,
        'unread_only': unreadOnly,
        'patient_id': pid,
      },
    );
    final list = response.data as List? ?? [];
    return list
        .whereType<Map>()
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .where((n) => n.belongsToPatient(pid))
        .toList();
  }

  Future<int> getUnreadCount({String? patientId}) async {
    final pid = await resolveActivePatientId(patientId: patientId);
    final response = await _api.get(
      '/notifications/unread-count',
      queryParameters: {'patient_id': pid},
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
    final pid = await resolveActivePatientId(patientId: patientId);
    final response = await _api.post(
      '/notifications/mark-all-read',
      queryParameters: {'patient_id': pid},
    );
    final data = response.data;
    if (data is Map) {
      return (data['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
