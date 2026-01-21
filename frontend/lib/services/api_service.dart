import 'package:dio/dio.dart' hide Response, FormData, MultipartFile;
import 'package:dio/dio.dart'
    as dio
    show Response, FormData, MultipartFile, Options;
// RequestOptions and ErrorInterceptorHandler are used from dio package directly
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/services/auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();
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
            // إذا فشل قراءة الـ token (مثل MissingPluginException)، تجاهل
            // هذا يحدث عادة عند أول تشغيل قبل ربط الـ plugin بشكل صحيح
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
            final refreshed = await _authService.refreshAccessToken();
            
            if (refreshed) {
              // نجح التجديد - إعادة المحاولة للطلبات المعلقة
              _isRefreshing = false;
              await _retryPendingRequests();
              
              // إعادة المحاولة للطلب الأصلي
              final opts = requestOptions;
              opts.headers['Authorization'] = 'Bearer ${await _authService.getToken()}';
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
      // تجاهل الأخطاء في وضع العرض أو إذا كان flutter_secure_storage غير متاح
      print('Warning: Could not clear storage: $e');
    }
    // في وضع العرض، لا نعيد التوجيه تلقائياً
    // Get.offAllNamed(AppRoutes.userSelection);
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
    final token = await _authService.getToken();
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
    print('🌐 [ApiService] POST Request');
    print('   📍 Endpoint: $endpoint');
    print('   🔗 Full URL: $fullUrl');
    print('   📦 Data type: ${formData != null ? 'FormData' : 'JSON'}');
    if (formData != null) {
      print('   📋 FormData fields: ${formData.fields}');
    } else if (data != null) {
      print('   📋 JSON Data: $data');
    }
    if (options?.headers != null) {
      print('   📝 Headers: ${options!.headers}');
    }
    
    try {
      final response = await _dio.post(
        endpoint,
        data: formData ?? data,
        options: options,
      );
      print('✅ [ApiService] POST Success');
      print('   📊 Status Code: ${response.statusCode}');
      print('   📦 Response Data: ${response.data}');
      return response;
    } on DioException catch (e) {
      print('❌ [ApiService] POST DioException');
      print('   🔴 Error Type: ${e.type}');
      print('   🔴 Status Code: ${e.response?.statusCode}');
      print('   🔴 Response Data: ${e.response?.data}');
      print('   🔴 Error Message: ${e.message}');
      throw _handleDioError(e);
    } catch (e) {
      print('❌ [ApiService] POST General Error: $e');
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

  // Upload File from bytes
  Future<dio.Response> uploadFileBytes(
    String endpoint,
    List<int> fileBytes, {
    String fileName = 'image.jpg',
    String fileKey = 'image',
    String contentType = 'image/jpeg',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final formData = dio.FormData.fromMap({
        fileKey: dio.MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: DioMediaType.parse(contentType),
        ),
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
    print('🔧 [ApiService] _handleDioError called');
    print('   Error Type: ${error.type}');
    print('   Status Code: ${error.response?.statusCode}');
    print('   Response Data: ${error.response?.data}');
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        print('   ⏱️ Timeout error');
        return NetworkException('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        String message;
        
        // التحقق من نوع responseData أولاً
        if (responseData is String) {
          // إذا كان String (مثل traceback)، استخدمه مباشرة
          message = responseData;
        } else if (responseData is Map) {
          // إذا كان Map، حاول استخراج detail
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
            message = responseData['message']?.toString() ??
                error.response?.statusMessage ??
                'حدث خطأ في الخادم';
          }
        } else {
          // نوع غير متوقع
          message = error.response?.statusMessage ??
              'حدث خطأ في الخادم';
        }

        print('   🚨 Bad Response: $statusCode - $message');

        if (statusCode == 401) {
          return UnauthorizedException(message);
        } else if (statusCode == 404) {
          return NotFoundException(message);
        } else {
          return ServerException(message, statusCode: statusCode);
        }
      case DioExceptionType.cancel:
        print('   🚫 Request cancelled');
        return NetworkException('تم إلغاء الطلب');
      case DioExceptionType.connectionError:
        print('   🔌 Connection error - Server may be down or URL incorrect');
        return NetworkException('خطأ في الاتصال. تأكد من أن السيرفر يعمل وأن الـ URL صحيح.');
      case DioExceptionType.unknown:
      default:
        print('   ❓ Unknown error: ${error.message}');
        return NetworkException('خطأ في الاتصال. تأكد من اتصالك بالإنترنت.');
    }
  }

  // Get stored token
  Future<String?> getToken() async {
    return await _storage.read(key: ApiConstants.tokenKey);
  }

  // Save token
  Future<void> saveToken(String token) async {
    await _storage.write(key: ApiConstants.tokenKey, value: token);
  }

  // Clear token
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
