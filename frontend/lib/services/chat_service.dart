import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/models/message_model.dart';
import 'package:farah_sys_final/services/socket_service.dart';

class ChatService {
  final _api = ApiService();
  final SocketService _socketService = SocketService();

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
    int limit = 50,
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
        return data
            .map((json) => MessageModel.fromJson(json))
            .toList();
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

  // إرسال رسالة مع صورة (multipart)
  Future<MessageModel> sendMessageWithImage({
    required String patientId,
    String? content,
    File? image,
    String? doctorId,
  }) async {
    try {
      final token = await _api.getToken();
      if (token == null) {
        throw ApiException('غير مصرح به');
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.chatSendMessage(patientId)}');
      
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      if (doctorId != null) {
        request.fields['doctor_id'] = doctorId;
      }

      if (image != null) {
        final fileStream = image.openRead();
        final fileLength = await image.length();
        final multipartFile = http.MultipartFile(
          'image',
          fileStream,
          fileLength,
          filename: image.path.split('/').last,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        return MessageModel.fromJson(data);
      } else {
        throw ApiException('فشل إرسال الرسالة: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
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
      final token = await _api.getToken();
      if (token == null) {
        throw ApiException('غير مصرح به');
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.chatSendMessage(patientId)}');
      
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      if (content.isNotEmpty) {
        request.fields['content'] = content;
      }
      if (doctorId != null) {
        request.fields['doctor_id'] = doctorId;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        return MessageModel.fromJson(data);
      } else {
        throw ApiException('فشل إرسال الرسالة: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
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

