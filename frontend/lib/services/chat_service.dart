import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:http_parser/http_parser.dart';
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/models/message_model.dart';
import 'package:farah_sys_final/services/socket_service.dart';

class ChatService {
  final _api = ApiService();
  final SocketService _socketService = SocketService();

  MediaType? _guessImageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.heic')) return MediaType('image', 'heic');
    if (lower.endsWith('.heif')) return MediaType('image', 'heif');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return MediaType('image', 'jpeg');
  }

  // جلب قائمة المحادثات
  Future<List<Map<String, dynamic>>> getChatList() async {
    try {
      final response = await _api.get(ApiConstants.chatList);
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((json) => json as Map<String, dynamic>).toList();
      } else {
        throw ApiException('فشل جلب قائمة المحادثات');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب قائمة المحادثات: ${e.toString()}');
    }
  }

  // جلب الرسائل من API
  Future<List<MessageModel>> getMessages({
    required String patientId,
    int limit = 30,
    String? before,
    String? doctorId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit};
      if (before != null) queryParams['before'] = before;
      if (doctorId != null) queryParams['doctor_id'] = doctorId;

      final response = await _api.get(
        ApiConstants.chatMessages(patientId),
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.map((json) => MessageModel.fromJson(json)).toList();
      } else {
        throw ApiException('فشل جلب الرسائل');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب الرسائل: ${e.toString()}');
    }
  }

  // إرسال رسالة مع صورة (multipart عبر Dio)
  Future<MessageModel> sendMessageWithImage({
    required String patientId,
    String? content,
    File? image,
    String? doctorId,
  }) async {
    try {
      final map = <String, dynamic>{};
      if (content != null && content.isNotEmpty) {
        map['content'] = content;
      }
      if (doctorId != null && doctorId.isNotEmpty) {
        map['doctor_id'] = doctorId;
      }
      if (image != null) {
        final filename = image.path.split(Platform.pathSeparator).last;
        map['image'] = await dio.MultipartFile.fromFile(
          image.path,
          filename: filename,
          contentType: _guessImageContentType(image.path),
        );
      }

      final response = await _api.post(
        ApiConstants.chatSendMessage(patientId),
        formData: dio.FormData.fromMap(map),
      );

      final data = response.data;
      if (data is Map) {
        return MessageModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw ApiException('فشل إرسال الرسالة');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('فشل إرسال الرسالة: ${e.toString()}');
    }
  }

  // إرسال رسالة نصية عبر REST API (fallback when Socket.IO fails)
  Future<MessageModel> sendTextMessage({
    required String patientId,
    required String content,
    String? doctorId,
  }) async {
    try {
      final map = <String, dynamic>{
        if (content.isNotEmpty) 'content': content,
        if (doctorId != null && doctorId.isNotEmpty) 'doctor_id': doctorId,
      };

      final response = await _api.post(
        ApiConstants.chatSendMessage(patientId),
        formData: dio.FormData.fromMap(map),
      );

      final data = response.data;
      if (data is Map) {
        return MessageModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw ApiException('فشل إرسال الرسالة');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('فشل إرسال الرسالة: ${e.toString()}');
    }
  }

  // تعليم رسالة كمقروءة
  Future<void> markAsRead({
    required String roomId,
    required String messageId,
  }) async {
    try {
      await _api.put(
        ApiConstants.chatMarkRead(roomId, messageId),
      );
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل تعليم الرسالة كمقروءة: ${e.toString()}');
    }
  }

  // الحصول على SocketService
  SocketService get socketService => _socketService;

  // قطع الاتصال
  void disconnect() {
    _socketService.disconnect();
  }

  // التحقق من حالة الاتصال
  bool get isConnected => _socketService.isConnected;
}
