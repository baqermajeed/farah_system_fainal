import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_exception.dart';
import '../models/user_me.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  Future<String> staffLogin({required String username, required String password}) async {
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
      final token = data['access_token']?.toString();
      if (token == null || token.isEmpty) {
        throw ApiException('لم يتم استلام access_token من السيرفر.');
      }
      return token;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final detail = e.response?.data;
      throw ApiException('فشل تسجيل الدخول. (${status ?? 'no-status'}) ${detail ?? ''}', statusCode: status);
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


