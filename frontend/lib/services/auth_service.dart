import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';

import '../core/network/api_constants.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

  // Helper to decode response body
  Map<String, dynamic> _decodeBody(List<int> bodyBytes) {
    try {
      return jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'raw': utf8.decode(bodyBytes)};
    }
  }

  // Helper to get full URL
  String _getFullUrl(String endpoint) {
    final url = '${ApiConstants.baseUrl}$endpoint';
    print(
      '🔗 [URL Builder] Base: ${ApiConstants.baseUrl}, Endpoint: $endpoint, Full: $url',
    );
    return url;
  }

  // Helper to get stored token
  Future<String?> _getToken() async {
    try {
      return await _storage.read(key: ApiConstants.tokenKey);
    } catch (e) {
      print('⚠️ Warning: Could not read token from storage: $e');
      return null;
    }
  }

  // Public method to get current token (for saving before patient registration)
  Future<String?> getToken() async {
    return await _getToken();
  }

  // Helper to save token
  Future<void> _saveToken(String token) async {
    try {
      await _storage.write(key: ApiConstants.tokenKey, value: token);
    } catch (e) {
      print('⚠️ Warning: Could not save token to storage: $e');
    }
  }

  // Helper to save refresh token
  Future<void> _saveRefreshToken(String refreshToken) async {
    try {
      await _storage.write(key: ApiConstants.refreshTokenKey, value: refreshToken);
    } catch (e) {
      print('⚠️ Warning: Could not save refresh token to storage: $e');
    }
  }

  // Helper to get refresh token
  Future<String?> _getRefreshToken() async {
    try {
      return await _storage.read(key: ApiConstants.refreshTokenKey);
    } catch (e) {
      print('⚠️ Warning: Could not read refresh token from storage: $e');
      return null;
    }
  }

  // Public method to save token (for restoring doctor/receptionist token)
  Future<void> saveToken(String token) async {
    await _saveToken(token);
  }

  // Helper to save both tokens
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _saveToken(accessToken);
    await _saveRefreshToken(refreshToken);
  }

  // Helper to clear token
  Future<void> _clearToken() async {
    try {
      await _storage.delete(key: ApiConstants.tokenKey);
      await _storage.delete(key: ApiConstants.refreshTokenKey);
      await _storage.delete(key: ApiConstants.userKey);
      await _storage.delete(key: ApiConstants.activePatientIdKey);
    } catch (e) {
      print('⚠️ Warning: Could not clear storage: $e');
    }
  }

  Future<void> saveActivePatientId(String patientId) async {
    try {
      await _storage.write(
        key: ApiConstants.activePatientIdKey,
        value: patientId,
      );
    } catch (e) {
      print('⚠️ Warning: Could not save active patient id: $e');
    }
  }

  Future<String?> getActivePatientId() async {
    try {
      return await _storage.read(key: ApiConstants.activePatientIdKey);
    } catch (e) {
      print('⚠️ Warning: Could not read active patient id: $e');
      return null;
    }
  }

  // Helper to get headers with token
  Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // طلب إرسال OTP
  Future<Map<String, dynamic>> requestOtp(String phone) async {
    try {
      print('🔐 ========== API REQUEST OTP ==========');
      final uri = Uri.parse(_getFullUrl(ApiConstants.authRequestOtp));
      print('🔐 URL: $uri');
      print('🔐 Phone: $phone');
      print('🔐 =====================================');

      final response = await http
          .post(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({'phone': phone}),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('❌ REQUEST OTP TIMEOUT');
              throw Exception('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى');
            },
          );

      print('🔐 ========== API REQUEST OTP RESPONSE ==========');
      print('🔐 Status Code: ${response.statusCode}');
      print('🔐 Response Body: ${response.body}');
      print('🔐 ==============================================');

      if (response.statusCode == 204 ||
          (response.statusCode >= 200 && response.statusCode < 300)) {
        print('✅ REQUEST OTP SUCCESS');
        return {'ok': true, 'data': {}};
      }

      final decoded = _decodeBody(response.bodyBytes);
      print('❌ REQUEST OTP FAILED: ${decoded['detail'] ?? 'Unknown error'}');
      return {
        'ok': false,
        'error': decoded['detail'] ?? 'فشل إرسال رمز التحقق',
        'data': decoded,
      };
    } catch (e) {
      print('❌ REQUEST OTP ERROR: $e');
      return {
        'ok': false,
        'error': e.toString().contains('timeout')
            ? 'انتهت مهلة الاتصال. يرجى التحقق من الاتصال بالإنترنت'
            : 'حدث خطأ في الاتصال. يرجى المحاولة مرة أخرى',
        'data': {'error': e.toString()},
      };
    }
  }

  // التحقق من OTP فقط (بدون إنشاء حساب)
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    try {
      print('🔐 ========== API VERIFY OTP ==========');
      final uri = Uri.parse(_getFullUrl(ApiConstants.authVerifyOtp));
      print('🔐 URL: $uri');
      print('🔐 Phone: $phone');
      print('🔐 Code: $code');
      print('🔐 ===================================');

      final payload = {
        'phone': phone,
        'code': code,
      };

      final response = await http
          .post(uri, headers: await _getHeaders(), body: jsonEncode(payload))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('❌ VERIFY OTP TIMEOUT');
              throw Exception('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى');
            },
          );

      print('🔐 ========== API VERIFY OTP RESPONSE ==========');
      print('🔐 Status Code: ${response.statusCode}');
      print('🔐 Response Body: ${response.body}');
      print('🔐 =============================================');

      final decoded = _decodeBody(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ VERIFY OTP SUCCESS');
        final accountExists = decoded['account_exists'] as bool? ?? false;
        final tokenObj = decoded['token'] as Map<String, dynamic>?;
        
        if (accountExists && tokenObj != null) {
          final accessToken = tokenObj['access_token'] as String?;
          final refreshToken = tokenObj['refresh_token'] as String?;
          if (accessToken != null && refreshToken != null) {
            await _saveTokens(accessToken, refreshToken);
            print('✅ Tokens saved successfully');
          }
        }
        
        return {
          'ok': true,
          'data': decoded,
          'accountExists': accountExists,
          'token': tokenObj,
        };
      }

      print('❌ VERIFY OTP FAILED: ${decoded['detail'] ?? 'Unknown error'}');
      return {
        'ok': false,
        'error': decoded['detail'] ?? 'فشل التحقق من رمز OTP',
        'data': decoded,
      };
    } catch (e) {
      print('❌ VERIFY OTP ERROR: $e');
      return {
        'ok': false,
        'error': e.toString().contains('timeout')
            ? 'انتهت مهلة الاتصال. يرجى التحقق من الاتصال بالإنترنت'
            : 'حدث خطأ في الاتصال. يرجى المحاولة مرة أخرى',
        'data': {'error': e.toString()},
      };
    }
  }

  // إنشاء حساب مريض جديد
  Future<Map<String, dynamic>> createPatientAccount({
    required String phone,
    required String name,
    String? gender,
    int? age,
    String? city,
  }) async {
    try {
      print('🔐 ========== API CREATE PATIENT ACCOUNT ==========');
      final uri = Uri.parse(_getFullUrl(ApiConstants.authCreatePatientAccount));
      print('🔐 URL: $uri');
      print('🔐 Phone: $phone');
      print('🔐 Name: $name');
      print('🔐 Gender: $gender');
      print('🔐 Age: $age');
      print('🔐 City: $city');
      print('🔐 ================================================');

      final payload = {
        'phone': phone,
        'name': name,
        if (gender != null) 'gender': gender,
        if (age != null) 'age': age,
        if (city != null) 'city': city,
      };

      final response = await http
          .post(uri, headers: await _getHeaders(), body: jsonEncode(payload))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('❌ CREATE PATIENT ACCOUNT TIMEOUT');
              throw Exception('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى');
            },
          );

      print('🔐 ========== API CREATE PATIENT ACCOUNT RESPONSE ==========');
      print('🔐 Status Code: ${response.statusCode}');
      print('🔐 Response Body: ${response.body}');
      print('🔐 =========================================================');

      final decoded = _decodeBody(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ CREATE PATIENT ACCOUNT SUCCESS');
        final accessToken = decoded['access_token'] as String?;
        final refreshToken = decoded['refresh_token'] as String?;
        if (accessToken != null && refreshToken != null) {
          await _saveTokens(accessToken, refreshToken);
          print('✅ Tokens saved successfully');
        }
        return {'ok': true, 'data': decoded};
      }

      print('❌ CREATE PATIENT ACCOUNT FAILED: ${decoded['detail'] ?? 'Unknown error'}');
      return {
        'ok': false,
        'error': decoded['detail'] ?? 'فشل إنشاء الحساب',
        'data': decoded,
      };
    } catch (e) {
      print('❌ CREATE PATIENT ACCOUNT ERROR: $e');
      return {
        'ok': false,
        'error': e.toString().contains('timeout')
            ? 'انتهت مهلة الاتصال. يرجى التحقق من الاتصال بالإنترنت'
            : 'حدث خطأ في الاتصال. يرجى المحاولة مرة أخرى',
        'data': {'error': e.toString()},
      };
    }
  }

  // تسجيل دخول الطاقم (طبيب/موظف/مصور/مدير)
  Future<Map<String, dynamic>> staffLogin({
    required String username,
    required String password,
  }) async {
    try {
      print('🔐 ========== API STAFF LOGIN ==========');
      final uri = Uri.parse(_getFullUrl(ApiConstants.authStaffLogin));
      print('🔐 URL: $uri');
      print('🔐 Username: $username');
      print('🔐 Password: ${'*' * password.length}');
      print('🔐 ====================================');

      // استخدام application/x-www-form-urlencoded للـ staff login
      // نفس التنسيق المستخدم في Swagger
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      };

      // URL encode البيانات لتجنب مشاكل الأحرف الخاصة
      // ترتيب الـ parameters: grant_type أولاً ثم username ثم password (مثل Swagger)
      final encodedUsername = Uri.encodeComponent(username);
      final encodedPassword = Uri.encodeComponent(password);
      final body =
          'grant_type=password&username=$encodedUsername&password=$encodedPassword';

      print('🔐 Body format: grant_type=password&username=***&password=***');
      print('🔐 Full URL: $uri');
      print('🔐 Headers: $headers');
      print(
        '🔐 Body preview: grant_type=password&username=$encodedUsername&password=***',
      );

      print('🔐 Sending POST request...');
      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(
            const Duration(seconds: 30), // زيادة الـ timeout إلى 30 ثانية
            onTimeout: () {
              print('❌ STAFF LOGIN TIMEOUT after 30 seconds');
              print('❌ Check if backend is running on 0.0.0.0:8000');
              throw Exception('انتهت مهلة الاتصال. تأكد من أن الباكند يعمل');
            },
          );
      print('🔐 Response received!');

      print('🔐 ========== API STAFF LOGIN RESPONSE ==========');
      print('🔐 Status Code: ${response.statusCode}');
      print('🔐 Response Body: ${response.body}');
      print('🔐 ==============================================');

      final decoded = _decodeBody(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ STAFF LOGIN SUCCESS');
        final accessToken = decoded['access_token'] as String?;
        final refreshToken = decoded['refresh_token'] as String?;
        if (accessToken != null && refreshToken != null) {
          await _saveTokens(accessToken, refreshToken);
          print('✅ Tokens saved successfully');
        }
        return {'ok': true, 'data': decoded};
      }

      print('❌ STAFF LOGIN FAILED: ${decoded['detail'] ?? 'Unknown error'}');
      return {
        'ok': false,
        'error': decoded['detail'] ?? 'فشل تسجيل الدخول',
        'data': decoded,
      };
    } catch (e) {
      print('❌ STAFF LOGIN ERROR: $e');
      return {
        'ok': false,
        'error': e.toString().contains('timeout')
            ? 'انتهت مهلة الاتصال. يرجى التحقق من الاتصال بالإنترنت'
            : 'حدث خطأ في الاتصال. يرجى المحاولة مرة أخرى',
        'data': {'error': e.toString()},
      };
    }
  }

  // جلب معلومات المستخدم الحالي
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      print('👤 ========== API GET CURRENT USER ==========');
      final uri = Uri.parse(_getFullUrl(ApiConstants.authMe));
      print('👤 URL: $uri');
      print('👤 ==========================================');

      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: true))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('❌ GET CURRENT USER TIMEOUT');
              throw Exception('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى');
            },
          );

      print('👤 ========== API GET CURRENT USER RESPONSE ==========');
      print('👤 Status Code: ${response.statusCode}');
      print('👤 Response Body: ${response.body}');
      print('👤 ===================================================');

      final decoded = _decodeBody(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ GET CURRENT USER SUCCESS');
        return {'ok': true, 'data': decoded};
      }

      print(
        '❌ GET CURRENT USER FAILED: ${decoded['detail'] ?? 'Unknown error'}',
      );
      return {
        'ok': false,
        'error': decoded['detail'] ?? 'فشل جلب معلومات المستخدم',
        'data': decoded,
      };
    } catch (e) {
      print('❌ GET CURRENT USER ERROR: $e');
      return {
        'ok': false,
        'error': e.toString().contains('timeout')
            ? 'انتهت مهلة الاتصال. يرجى التحقق من الاتصال بالإنترنت'
            : 'حدث خطأ في الاتصال. يرجى المحاولة مرة أخرى',
        'data': {'error': e.toString()},
      };
    }
  }

  // التحقق من تسجيل الدخول
  Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // تحديث معلومات المستخدم
  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    try {
      print('👤 ========== API UPDATE PROFILE ==========');
      final uri = Uri.parse(_getFullUrl(ApiConstants.authUpdateProfile));
      print('👤 URL: $uri');
      print('👤 Name: $name');
      print('👤 Phone: $phone');
      print('👤 =======================================');

      final payload = {
        'name': name,
        'phone': phone,
      };

      final response = await http
          .put(
            uri,
            headers: await _getHeaders(includeAuth: true),
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('❌ UPDATE PROFILE TIMEOUT');
              throw Exception('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى');
            },
          );

      print('👤 ========== API UPDATE PROFILE RESPONSE ==========');
      print('👤 Status Code: ${response.statusCode}');
      print('👤 Response Body: ${response.body}');
      print('👤 ================================================');

      final decoded = _decodeBody(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ UPDATE PROFILE SUCCESS');
        return;
      }

      print(
        '❌ UPDATE PROFILE FAILED: ${decoded['detail'] ?? 'Unknown error'}',
      );
      throw Exception(decoded['detail'] ?? 'فشل تحديث المعلومات');
    } catch (e) {
      print('❌ UPDATE PROFILE ERROR: $e');
      if (e.toString().contains('timeout')) {
        throw Exception('انتهت مهلة الاتصال. يرجى التحقق من الاتصال بالإنترنت');
      }
      rethrow;
    }
  }

  // رفع صورة الملف الشخصي
  Future<void> uploadProfileImage(File imageFile) async {
    try {
      print('📷 ========== API UPLOAD PROFILE IMAGE ==========');
      final uri = Uri.parse(_getFullUrl(ApiConstants.authUploadImage));
      print('📷 URL: $uri');
      print('📷 Image path: ${imageFile.path}');
      print('📷 ==============================================');

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _getHeaders(includeAuth: true));
      
      // إضافة الصورة
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: imageFile.path.split('/').last,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('❌ UPLOAD IMAGE TIMEOUT');
          throw Exception('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('📷 ========== API UPLOAD IMAGE RESPONSE ==========');
      print('📷 Status Code: ${response.statusCode}');
      print('📷 Response Body: ${response.body}');
      print('📷 ==============================================');

      final decoded = _decodeBody(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ UPLOAD IMAGE SUCCESS');
        return;
      }

      print('❌ UPLOAD IMAGE FAILED: ${decoded['detail'] ?? 'Unknown error'}');
      throw Exception(decoded['detail'] ?? 'فشل رفع الصورة');
    } catch (e) {
      print('❌ UPLOAD IMAGE ERROR: $e');
      if (e.toString().contains('timeout')) {
        throw Exception('انتهت مهلة الاتصال. يرجى التحقق من الاتصال بالإنترنت');
      }
      rethrow;
    }
  }

  // تجديد Access Token باستخدام Refresh Token
  Future<bool> refreshAccessToken() async {
    try {
      print('🔄 ========== API REFRESH TOKEN ==========');
      final refreshToken = await _getRefreshToken();
      
      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ No refresh token found');
        return false;
      }
      
      final uri = Uri.parse(_getFullUrl(ApiConstants.authRefresh));
      print('🔄 URL: $uri');
      print('🔄 Refresh token: ${refreshToken.substring(0, 30)}...');
      print('🔄 =====================================');
      
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('❌ REFRESH TOKEN TIMEOUT');
              throw Exception('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى');
            },
          );
      
      print('🔄 ========== API REFRESH TOKEN RESPONSE ==========');
      print('🔄 Status Code: ${response.statusCode}');
      print('🔄 Response Body: ${response.body}');
      print('🔄 ================================================');
      
      final decoded = _decodeBody(response.bodyBytes);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ REFRESH TOKEN SUCCESS');
        final accessToken = decoded['access_token'] as String?;
        final newRefreshToken = decoded['refresh_token'] as String?;
        if (accessToken != null && newRefreshToken != null) {
          await _saveTokens(accessToken, newRefreshToken);
          print('✅ New tokens saved successfully');
          return true;
        }
        return false;
      }
      
      print('❌ REFRESH TOKEN FAILED: ${decoded['detail'] ?? 'Unknown error'}');
      return false;
    } catch (e) {
      print('❌ REFRESH TOKEN ERROR: $e');
      return false;
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    await _clearToken();
    print('✅ Logged out successfully');
  }
}
