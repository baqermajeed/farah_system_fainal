import 'dart:convert';
import 'package:dio/dio.dart' hide Response, FormData, MultipartFile;
import 'package:dio/dio.dart'
    as dio
    show Response, FormData, MultipartFile, Options;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  ApiService._internal() {
    _dio = Dio(
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

    // Helpful startup log to confirm which backend URL the app is targeting.
    print('🌐 [ApiService] Base URL: ${ApiConstants.baseUrl}');

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add token to headers
          try {
            final token = await _storage.read(key: ApiConstants.tokenKey);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            print('Warning: Could not read token from storage: $e');
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle errors globally
          if (error.response?.statusCode == 401) {
            // Token expired - try to refresh
            final requestOptions = error.requestOptions;
            
            // إذا كان الطلب هو refresh token نفسه، لا نعيد المحاولة
            if (requestOptions.path.contains('/auth/refresh')) {
              await _handleUnauthorized();
              return handler.next(error);
            }
            
            // إذا كنا نعيد التجديد حالياً، نضيف الطلب للقائمة المعلقة
            if (_isRefreshing) {
              return _addPendingRequest(requestOptions, handler);
            }
            
            // محاولة تجديد الـ token
            _isRefreshing = true;
            final refreshed = await _refreshAccessToken();
            
            if (refreshed) {
              // نجح التجديد - إعادة المحاولة للطلبات المعلقة
              _isRefreshing = false;
              await _retryPendingRequests();
              
              // إعادة المحاولة للطلب الأصلي
              final opts = requestOptions;
              final newToken = await getToken();
              if (newToken != null && newToken.isNotEmpty) {
                opts.headers['Authorization'] = 'Bearer $newToken';
              }
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } else {
              // فشل التجديد - مسح tokens وlogout
              _isRefreshing = false;
              _pendingRequests.clear();
              await _handleUnauthorized();
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<void> _handleUnauthorized() async {
    try {
      await _storage.delete(key: ApiConstants.tokenKey);
      await _storage.delete(key: ApiConstants.refreshTokenKey);
      await _storage.delete(key: ApiConstants.userKey);
    } catch (e) {
      print('Warning: Could not clear storage: $e');
    }
  }

  // إضافة طلب للقائمة المعلقة
  void _addPendingRequest(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
  ) {
    _pendingRequests.add(_PendingRequest(
      requestOptions: requestOptions,
      handler: handler,
    ));
  }

  // إعادة المحاولة للطلبات المعلقة
  Future<void> _retryPendingRequests() async {
    final token = await getToken();
    if (token == null) return;

    for (final pending in _pendingRequests) {
      try {
        pending.requestOptions.headers['Authorization'] = 'Bearer $token';
        final response = await _dio.fetch(pending.requestOptions);
        pending.handler.resolve(response);
      } catch (e) {
        pending.handler.reject(
          DioException(
            requestOptions: pending.requestOptions,
            error: e,
          ),
        );
      }
    }
    _pendingRequests.clear();
  }

  // تجديد Access Token باستخدام Refresh Token
  Future<bool> _refreshAccessToken() async {
    try {
      print('🔄 ========== API REFRESH TOKEN ==========');
      final refreshToken = await getRefreshToken();
      
      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ No refresh token found');
        // مسح الـ tokens القديمة
        await _handleUnauthorized();
        return false;
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authRefresh}');
      print('🔄 URL: $uri');
      print('🔄 Refresh token: ${refreshToken.substring(0, 30)}...');
      print('🔄 =====================================');
      
      final response = await Dio().post(
        uri.toString(),
        options: dio.Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode({'refresh_token': refreshToken}),
      );
      
      print('🔄 ========== API REFRESH TOKEN RESPONSE ==========');
      print('🔄 Status Code: ${response.statusCode}');
      print('🔄 Response Body: ${response.data}');
      print('🔄 ================================================');
      
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        print('✅ REFRESH TOKEN SUCCESS');
        final data = response.data as Map<String, dynamic>;
        final accessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;
        if (accessToken != null && newRefreshToken != null) {
          await saveTokens(accessToken, newRefreshToken);
          print('✅ New tokens saved successfully');
          return true;
        }
        return false;
      }
      
      print('❌ REFRESH TOKEN FAILED: ${response.data}');
      // إذا كان الخطأ 401، مسح الـ tokens
      if (response.statusCode == 401) {
        print('⚠️ Refresh token expired (401), clearing tokens');
        await _handleUnauthorized();
      }
      return false;
    } on DioException catch (e) {
      print('❌ REFRESH TOKEN ERROR: $e');
      // إذا كان الخطأ 401، مسح الـ tokens
      if (e.response?.statusCode == 401) {
        print('⚠️ Refresh token expired (401), clearing tokens');
        await _handleUnauthorized();
      }
      return false;
    } catch (e) {
      print('❌ REFRESH TOKEN ERROR: $e');
      return false;
    }
  }

  // GET Request
  Future<dio.Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    dio.Options? options,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  // POST Request
  Future<dio.Response> post(
    String endpoint, {
    dynamic data,
    dio.FormData? formData,
    dio.Options? options,
  }) async {
    final fullUrl = '${ApiConstants.baseUrl}$endpoint';
    print('🌐 [ApiService] POST Request: $fullUrl');
    if (options?.headers != null) {
      print('🌐 [ApiService] Request Headers: ${options!.headers}');
    }
    if (data is String) {
      print('🌐 [ApiService] Data Type: String (${data.length} chars)');
      print('🌐 [ApiService] Data Preview: ${data.length > 100 ? data.substring(0, 100) + "..." : data}');
    } else if (data != null) {
      print('🌐 [ApiService] Data Type: ${data.runtimeType}');
      print('🌐 [ApiService] Data: $data');
    }

    // Handle form-urlencoded strings - convert to UTF-8 bytes so Dio sends as raw body
    dynamic requestData = formData ?? data;
    if (formData == null && 
        data is String && 
        options?.contentType == 'application/x-www-form-urlencoded') {
      // Convert string to UTF-8 bytes to ensure Dio sends it as raw body
      requestData = utf8.encode(data);
      print('🌐 [ApiService] Converting form-urlencoded string to UTF-8 bytes');
    }

    try {
      final response = await _dio.post(
        endpoint,
        data: requestData,
        options: options,
      );
      print('✅ [ApiService] POST Success: ${response.statusCode}');
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  // PUT Request
  Future<dio.Response> put(
    String endpoint, {
    Map<String, dynamic>? data,
    dio.FormData? formData,
    dio.Options? options,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: formData ?? data,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  // PATCH Request
  Future<dio.Response> patch(
    String endpoint, {
    Map<String, dynamic>? data,
    dio.Options? options,
  }) async {
    try {
      final response = await _dio.patch(endpoint, data: data, options: options);
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  // DELETE Request
  Future<dio.Response> delete(
    String endpoint, {
    Map<String, dynamic>? data,
    dio.Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        data: data,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  // Upload File from Bytes
  Future<dio.Response> uploadFileBytes(
    String endpoint,
    List<int> bytes, {
    String fileKey = 'image',
    String fileName = 'image.jpg',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final formData = dio.FormData.fromMap({
        fileKey: dio.MultipartFile.fromBytes(bytes, filename: fileName),
        ...?additionalData,
      });

      final response = await _dio.post(endpoint, data: formData);
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  // Upload File
  Future<dio.Response> uploadFile(
    String endpoint,
    String filePath, {
    String fileKey = 'image',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final formData = dio.FormData.fromMap({
        fileKey: await dio.MultipartFile.fromFile(filePath),
        ...?additionalData,
      });

      final response = await _dio.post(endpoint, data: formData);
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  ApiException _handleDioError(DioException error) {
    print(
      '🔧 [ApiService] Error: ${error.type}, Status: ${error.response?.statusCode}',
    );

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        String message;

        if (responseData is String) {
          message = responseData;
        } else if (responseData is Map) {
          final detail = responseData['detail'];
          if (detail is List && detail.isNotEmpty) {
            final firstError = detail[0];
            if (firstError is Map && firstError['msg'] != null) {
              message = firstError['msg'].toString();
            } else {
              message = detail.toString();
            }
          } else if (detail is String) {
            message = detail;
          } else {
            message =
                responseData['message']?.toString() ??
                error.response?.statusMessage ??
                'حدث خطأ في الخادم';
          }
        } else {
          message = error.response?.statusMessage ?? 'حدث خطأ في الخادم';
        }

        if (statusCode == 401) {
          return UnauthorizedException(message);
        } else if (statusCode == 404) {
          return NotFoundException(message);
        } else {
          return ServerException(message, statusCode: statusCode);
        }
      case DioExceptionType.cancel:
        return NetworkException('تم إلغاء الطلب');
      case DioExceptionType.connectionError:
        return NetworkException('خطأ في الاتصال. تأكد من أن السيرفر يعمل.');
      default:
        return NetworkException('خطأ غير معروف: ${error.message}');
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: ApiConstants.tokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: ApiConstants.refreshTokenKey);
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: ApiConstants.tokenKey, value: token);
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: ApiConstants.tokenKey, value: accessToken);
    await _storage.write(key: ApiConstants.refreshTokenKey, value: refreshToken);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: ApiConstants.tokenKey);
    await _storage.delete(key: ApiConstants.refreshTokenKey);
    await _storage.delete(key: ApiConstants.userKey);
  }
}

// Helper class للطلبات المعلقة أثناء refresh
class _PendingRequest {
  final RequestOptions requestOptions;
  final ErrorInterceptorHandler handler;

  _PendingRequest({
    required this.requestOptions,
    required this.handler,
  });
}
