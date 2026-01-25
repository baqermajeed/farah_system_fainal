import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:frontend_desktop/services/api_service.dart';
import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';

class AuthService {
  final _api = ApiService();

  // طلب إرسال OTP
  Future<Map<String, dynamic>> requestOtp(String phone) async {
    try {
      print('🔐 [AuthService] Requesting OTP for $phone');
      final response = await _api.post(
        ApiConstants.authRequestOtp,
        data: {'phone': phone},
      );

      if (response.statusCode == 204 ||
          (response.statusCode != null &&
              response.statusCode! >= 200 &&
              response.statusCode! < 300)) {
        print('✅ [AuthService] OTP Request Success');
        return {'ok': true, 'data': {}};
      }

      throw ApiException('فشل إرسال رمز التحقق');
    } catch (e) {
      print('❌ [AuthService] OTP Request Error: $e');
      if (e is ApiException) return {'ok': false, 'error': e.message};
      return {'ok': false, 'error': 'فشل الاتصال: $e'};
    }
  }

  // التحقق من OTP
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.authVerifyOtp,
        data: {'phone': phone, 'code': code},
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = response.data;
        final accountExists = data['account_exists'] as bool? ?? false;
        final tokenObj = data['token'] as Map<String, dynamic>?;

        if (accountExists && tokenObj != null) {
          final accessToken = tokenObj['access_token'] as String?;
          final refreshToken = tokenObj['refresh_token'] as String?;
          if (accessToken != null && refreshToken != null) {
            await _api.saveTokens(accessToken, refreshToken);
          }
        }

        return {
          'ok': true,
          'data': data,
          'accountExists': accountExists,
          'token': tokenObj,
        };
      }
      throw ApiException('فشل التحقق من OTP');
    } catch (e) {
      print('❌ [AuthService] Verify OTP Error: $e');
      if (e is ApiException) return {'ok': false, 'error': e.message};
      return {'ok': false, 'error': 'فشل الاتصال: $e'};
    }
  }

  // Helper to get full URL
  String _getFullUrl(String endpoint) {
    return '${ApiConstants.baseUrl}$endpoint';
  }

  // Helper to decode response body
  Map<String, dynamic> _decodeBody(List<int> bodyBytes) {
    try {
      return jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'raw': utf8.decode(bodyBytes)};
    }
  }

  // تسجيل دخول الطاقم (طبيب/موظف)
  // استخدام http مباشرة مثل النسخة المحمولة لتجنب مشاكل Dio مع form-urlencoded
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
      // نفس التنسيق المستخدم في Swagger والنسخة المحمولة
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
      print('🔐 Encoded username: $encodedUsername');
      print('🔐 Body length: ${body.length} chars');
      print(
        '🔐 Actual body (without password): ${body.replaceAll(RegExp(r'password=\d+'), 'password=***')}',
      );

      print('🔐 Sending POST request...');
      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('❌ STAFF LOGIN TIMEOUT after 30 seconds');
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
          await _api.saveTokens(accessToken, refreshToken);
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
      final response = await _api.get(ApiConstants.authMe);
      if (response.statusCode == 200) {
        return {'ok': true, 'data': response.data};
      }
      throw ApiException('فشل جلب بيانات المستخدم');
    } catch (e) {
      if (e is ApiException) return {'ok': false, 'error': e.message};
      return {'ok': false, 'error': 'فشل الاتصال: $e'};
    }
  }

  // التحقق من تسجيل الدخول
  Future<bool> isLoggedIn() async {
    final token = await _api.getToken();
    return token != null && token.isNotEmpty;
  }

  // الحصول على access token
  Future<String?> getToken() async {
    return await _api.getToken();
  }

  // Helper to get headers with token
  Future<Map<String, String>> _getHeaders({bool includeAuth = false, bool includeContentType = false}) async {
    final headers = {'Accept': 'application/json'};

    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }

    if (includeAuth) {
      final token = await _api.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
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
        filename: imageFile.path.split(Platform.pathSeparator).last,
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

      final payload = {'name': name, 'phone': phone};
      final headersMap = await _getHeaders(includeAuth: true, includeContentType: true);
      final body = jsonEncode(payload);
      
      // Convert Map to proper headers format
      final headers = Map<String, String>.from(headersMap);
      
      print('👤 Headers: $headers');
      print('👤 Body: $body');
      print('👤 Body type: ${body.runtimeType}');
      print('👤 Body length: ${body.length}');

      final response = await http
          .put(
            uri,
            headers: headers,
            body: body,
            encoding: utf8,
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

      print('❌ UPDATE PROFILE FAILED: ${decoded['detail'] ?? 'Unknown error'}');
      throw Exception(decoded['detail'] ?? 'فشل تحديث المعلومات');
    } catch (e) {
      print('❌ UPDATE PROFILE ERROR: $e');
      if (e.toString().contains('timeout')) {
        throw Exception('انتهت مهلة الاتصال. يرجى التحقق من الاتصال بالإنترنت');
      }
      rethrow;
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    await _api.clearToken();
  }
}
