import 'package:dio/dio.dart' hide Response, FormData, MultipartFile;
import 'package:dio/dio.dart'
    as dio
    show Response, FormData, MultipartFile, Options;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/services/token_storage.dart';

class ApiService {
  static ApiService? _instance;
  factory ApiService() => _instance ??= ApiService._internal();

  late Dio _dio;
  final TokenStorage _tokenStorage;
  late final AuthService _authService;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  /// عميل Dio الموحّد (مثل ApiClient في قريب).
  Dio get client => _dio;

  ApiService._internal({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ??
            (Get.isRegistered<TokenStorage>()
                ? Get.find<TokenStorage>()
                : TokenStorage()) {
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
    _authService = AuthService(tokenStorage: _tokenStorage, dio: _dio);

    if (kDebugMode) {
      debugPrint('[ApiService] Base URL: ${ApiConstants.baseUrl}');
    }

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add token to headers
          try {
            final token = await _tokenStorage.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            // إذا فشل قراءة الـ token (مثل MissingPluginException)، تجاهل
            if (kDebugMode) {
              debugPrint('[ApiService] Could not read token: $e');
            }
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
              opts.headers['Authorization'] =
                  'Bearer ${await _tokenStorage.getAccessToken()}';
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
    await _tokenStorage.clearTokens();
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
    final token = await _tokenStorage.getAccessToken();
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
    Map<String, dynamic>? queryParameters,
    dio.Options? options,
  }) async {
    try {
      return await _dio.post(
        endpoint,
        data: formData ?? data,
        queryParameters: queryParameters,
        options: options,
      );
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
    Map<String, dynamic>? queryParameters,
    dio.FormData? formData,
    dio.Options? options,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: formData ?? data,
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
    return ApiException.fromDio(error);
  }

  // Get stored token
  Future<String?> getToken() => _tokenStorage.getAccessToken();

  // Save token
  Future<void> saveToken(String token) =>
      _tokenStorage.saveAccessToken(token);

  // Clear token
  Future<void> clearToken() => _tokenStorage.clearTokens();
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
