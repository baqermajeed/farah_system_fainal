import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_exception.dart';
import '../models/user_me.dart';
import 'secure_storage_service.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;
  final _storage = SecureStorageService();

  Future<Map<String, String>> staffLogin({required String username, required String password}) async {
    try {
      final res = await _dio.post(
        '/auth/staff-login',
        data: {
          'username': username,
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = (res.data as Map).cast<String, dynamic>();
      final accessToken = data['access_token']?.toString();
      final refreshToken = data['refresh_token']?.toString();
      
      if (accessToken == null || accessToken.isEmpty) {
        throw ApiException('لم يتم استلام access_token من السيرفر.');
      }
      if (refreshToken == null || refreshToken.isEmpty) {
        throw ApiException('لم يتم استلام refresh_token من السيرفر.');
      }
      
      return {
        'access_token': accessToken,
        'refresh_token': refreshToken,
      };
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final detail = e.response?.data;
      throw ApiException('فشل تسجيل الدخول. (${status ?? 'no-status'}) ${detail ?? ''}', statusCode: status);
    }
  }

  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await _storage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final res = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = (res.data as Map).cast<String, dynamic>();
      final accessToken = data['access_token']?.toString();
      final newRefreshToken = data['refresh_token']?.toString();

      if (accessToken == null || accessToken.isEmpty || newRefreshToken == null || newRefreshToken.isEmpty) {
        return false;
      }

      await _storage.writeTokens(accessToken, newRefreshToken);
      ApiClient.instance.setToken(accessToken);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<UserMe> me() async {
    try {
      final res = await _dio.get('/auth/me', options: ApiClient.instance.authorizedOptions());
      return UserMe.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException('تعذر جلب معلومات المستخدم.', statusCode: e.response?.statusCode);
    }
  }
}


