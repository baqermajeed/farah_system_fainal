import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;

import '../core/network/api_constants.dart';
import '../core/network/api_exception.dart';
import 'token_storage.dart';

/// خدمة المصادقة — Dio موحّد + ApiException واضح (نمط قريب).
class AuthService {
  AuthService({TokenStorage? tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage ??
            (Get.isRegistered<TokenStorage>()
                ? Get.find<TokenStorage>()
                : TokenStorage()) {
    _dio = dio ?? _createFallbackDio();
  }

  final TokenStorage _tokenStorage;
  late final Dio _dio;

  Dio _createFallbackDio() {
    final client = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(
          milliseconds: ApiConstants.connectionTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: ApiConstants.receiveTimeout,
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    return client;
  }

  Future<String?> getToken() => _tokenStorage.getAccessToken();

  Future<void> saveToken(String token) =>
      _tokenStorage.saveAccessToken(token);

  Future<void> saveActivePatientId(String patientId) =>
      _tokenStorage.saveActivePatientId(patientId);

  Future<String?> getActivePatientId() => _tokenStorage.getActivePatientId();

  Map<String, dynamic> _fail(Object e, {String fallback = 'حدث خطأ، حاول مرة أخرى'}) {
    final ex = e is DioException
        ? ApiException.fromDio(e)
        : (e is ApiException
            ? e
            : ApiException(fallback, data: {'error': e.toString()}));
    if (kDebugMode) {
      debugPrint('[AuthService] ${ex.toString()}');
    }
    return {
      'ok': false,
      'error': ex.message,
      'code': ex.code,
      'statusCode': ex.statusCode,
      'data': ex.data ?? {'error': e.toString()},
    };
  }

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    try {
      final response = await _dio.post(
        ApiConstants.authRequestOtp,
        data: {'phone': phone},
      );
      final code = response.statusCode ?? 0;
      if (code == 204 || (code >= 200 && code < 300)) {
        return {'ok': true, 'data': {}};
      }
      final ex = ApiException.fromResponse(response.data, code);
      return {
        'ok': false,
        'error': ex.message,
        'code': ex.code,
        'statusCode': ex.statusCode,
        'data': response.data,
      };
    } catch (e) {
      return _fail(e, fallback: 'فشل إرسال رمز التحقق');
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.authVerifyOtp,
        data: {'phone': phone, 'code': code},
      );
      final status = response.statusCode ?? 0;
      final data = response.data;

      if (status >= 200 && status < 300 && data is Map) {
        final decoded = Map<String, dynamic>.from(data);
        final accountExists = decoded['account_exists'] as bool? ?? false;
        final tokenObj = decoded['token'] as Map<String, dynamic>?;
        if (accountExists && tokenObj != null) {
          final accessToken = tokenObj['access_token'] as String?;
          final refreshToken = tokenObj['refresh_token'] as String?;
          if (accessToken != null && refreshToken != null) {
            await _tokenStorage.saveTokens(accessToken, refreshToken);
          }
        }
        return {
          'ok': true,
          'data': decoded,
          'accountExists': accountExists,
          'token': tokenObj,
        };
      }

      final ex = ApiException.fromResponse(data, status);
      return {
        'ok': false,
        'error': ex.message,
        'code': ex.code,
        'statusCode': ex.statusCode,
        'data': data,
      };
    } catch (e) {
      return _fail(e, fallback: 'فشل التحقق من رمز OTP');
    }
  }

  Future<Map<String, dynamic>> createPatientAccount({
    required String phone,
    required String name,
    String? gender,
    int? age,
    String? city,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.authCreatePatientAccount,
        data: {
          'phone': phone,
          'name': name,
          if (gender != null) 'gender': gender,
          if (age != null) 'age': age,
          if (city != null) 'city': city,
        },
      );
      final status = response.statusCode ?? 0;
      final data = response.data;

      if (status >= 200 && status < 300 && data is Map) {
        final decoded = Map<String, dynamic>.from(data);
        final accessToken = decoded['access_token'] as String?;
        final refreshToken = decoded['refresh_token'] as String?;
        if (accessToken != null && refreshToken != null) {
          await _tokenStorage.saveTokens(accessToken, refreshToken);
        }
        return {'ok': true, 'data': decoded};
      }

      final ex = ApiException.fromResponse(data, status);
      return {
        'ok': false,
        'error': ex.message,
        'code': ex.code,
        'statusCode': ex.statusCode,
        'data': data,
      };
    } catch (e) {
      return _fail(e, fallback: 'فشل إنشاء الحساب');
    }
  }

  Future<Map<String, dynamic>> staffLogin({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.authStaffLogin,
        data: {
          'grant_type': 'password',
          'username': username,
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final status = response.statusCode ?? 0;
      final data = response.data;

      if (status >= 200 && status < 300 && data is Map) {
        final decoded = Map<String, dynamic>.from(data);
        final accessToken = decoded['access_token'] as String?;
        final refreshToken = decoded['refresh_token'] as String?;
        if (accessToken != null && refreshToken != null) {
          await _tokenStorage.saveTokens(accessToken, refreshToken);
        }
        return {'ok': true, 'data': decoded};
      }

      final ex = ApiException.fromResponse(data, status);
      return {
        'ok': false,
        'error': ex.message,
        'code': ex.code,
        'statusCode': ex.statusCode,
        'data': data,
      };
    } catch (e) {
      return _fail(e, fallback: 'اسم المستخدم أو كلمة المرور غير صحيحة');
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiConstants.authMe);
      final status = response.statusCode ?? 0;
      final data = response.data;

      if (status >= 200 && status < 300) {
        return {'ok': true, 'data': data};
      }

      final ex = ApiException.fromResponse(data, status);
      return {
        'ok': false,
        'error': ex.message,
        'code': ex.code,
        'statusCode': ex.statusCode,
        'data': data,
      };
    } catch (e) {
      return _fail(e, fallback: 'فشل جلب معلومات المستخدم');
    }
  }

  Future<bool> isLoggedIn() => _tokenStorage.hasTokens();

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    try {
      final response = await _dio.put(
        ApiConstants.authUpdateProfile,
        data: {'name': name, 'phone': phone},
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return;
      throw ApiException.fromResponse(response.data, status);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> uploadProfileImage(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split(Platform.pathSeparator).last,
        ),
      });
      final response = await _dio.post(
        ApiConstants.authUploadImage,
        data: formData,
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return;
      throw ApiException.fromResponse(response.data, status);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await _dio.post(
        ApiConstants.authRefresh,
        data: {'refresh_token': refreshToken},
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300 || response.data is! Map) {
        return false;
      }

      final decoded = Map<String, dynamic>.from(response.data as Map);
      final accessToken = decoded['access_token'] as String?;
      final newRefreshToken = decoded['refresh_token'] as String?;
      if (accessToken == null || newRefreshToken == null) return false;

      await _tokenStorage.saveTokens(accessToken, newRefreshToken);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] refresh failed: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clearSession();
  }
}
