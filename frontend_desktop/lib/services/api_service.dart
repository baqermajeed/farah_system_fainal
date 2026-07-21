import 'dart:convert';
import 'package:dio/dio.dart' hide Response, FormData, MultipartFile;
import 'package:dio/dio.dart'
    as dio
    show Response, FormData, MultipartFile, Options;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend_desktop/core/logging/app_logger.dart';
import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];
  static const int _maxGetRetries = 2;
  static const Duration _baseGetRetryDelay = Duration(milliseconds: 400);

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
          // FormData: clear forced application/json so Dio can set multipart + boundary
          if (options.data is dio.FormData) {
            options.headers.remove(Headers.contentTypeHeader);
            options.contentType = Headers.multipartFormDataContentType;
          }

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
            final requestOptions = error.requestOptions;

            // تجنب حلقة لا نهائية إذا فشلت إعادة المحاولة بعد تجديد التوكن
            if (requestOptions.extra['auth_retry'] == true) {
              return handler.next(error);
            }

            // طلب مرسل لـ API آخر (مثل الكندي) — لا نجدد التوكن ولا نعيد المحاولة (نتجنب حلقة لا نهائية)
            if (!_isRequestToMainBackend(requestOptions)) {
              return handler.next(error);
            }

            // إذا كان الطلب هو refresh token نفسه، لا نعيد المحاولة
            if (requestOptions.path.contains('/auth/refresh')) {
              await _handleUnauthorized();
              return handler.next(error);
            }

            // FormData لا يمكن إعادة إرساله بعد الاستهلاك
            if (requestOptions.data is dio.FormData) {
              return handler.next(error);
            }

            // إذا كنا نعيد التجديد حالياً، نضيف الطلب للقائمة المعلقة
            if (_isRefreshing) {
              return _addPendingRequest(requestOptions, handler);
            }
            
            // محاولة تجديد الـ token
            _isRefreshing = true;
            final refreshResult = await _refreshAccessToken();
            
            if (refreshResult == _RefreshResult.success) {
              // نجح التجديد - إعادة المحاولة للطلبات المعلقة
              _isRefreshing = false;
              await _retryPendingRequests();
              
              // إعادة المحاولة للطلب الأصلي
              try {
                final response = await _retryRequestAfterRefresh(requestOptions);
                return handler.resolve(response);
              } on DioException catch (e) {
                return handler.reject(e);
              }
            } else if (refreshResult == _RefreshResult.invalidToken) {
              // فشل حقيقي في التجديد (refresh token منتهي/غير صالح)
              _isRefreshing = false;
              _rejectPendingRequests(
                UnauthorizedException('انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.'),
              );
              _pendingRequests.clear();
              await _handleUnauthorized();
              return handler.next(error);
            } else {
              // فشل بسبب الشبكة/الخادم المؤقت: لا نمسح الجلسة
              _isRefreshing = false;
              _rejectPendingRequests(
                NetworkException(
                  'تعذر تجديد الجلسة بسبب ضعف الاتصال. حاول مرة أخرى عند تحسن الإنترنت.',
                ),
              );
              _pendingRequests.clear();
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

  /// الطلب مرسل إلى الـ API الرئيسي (نفس baseUrl) وليس إلى سيرفر آخر (مثل الكندي).
  bool _isRequestToMainBackend(RequestOptions options) {
    final path = options.path;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        final uri = Uri.parse(path);
        final mainUri = Uri.parse(ApiConstants.baseUrl);
        return uri.host == mainUri.host;
      } catch (_) {
        return true;
      }
    }
    return true;
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
        final response = await _retryRequestAfterRefresh(pending.requestOptions);
        pending.handler.resolve(response);
      } on DioException catch (e) {
        pending.handler.reject(e);
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

  /// إعادة إرسال الطلب بعد تجديد التوكن — نبني طلباً جديداً بدلاً من إعادة استخدام
  /// RequestOptions الأصلي لتجنب أخطاء 400 من جسم/معاملات مُستهلكة (Dio 5).
  Future<dio.Response> _retryRequestAfterRefresh(
    RequestOptions requestOptions,
  ) async {
    final token = await getToken();
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final extra = Map<String, dynamic>.from(requestOptions.extra);
    extra['auth_retry'] = true;

    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      onSendProgress: requestOptions.onSendProgress,
      onReceiveProgress: requestOptions.onReceiveProgress,
      options: dio.Options(
        method: requestOptions.method,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        extra: extra,
        headers: headers,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        validateStatus: requestOptions.validateStatus,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        followRedirects: requestOptions.followRedirects,
        maxRedirects: requestOptions.maxRedirects,
        persistentConnection: requestOptions.persistentConnection,
        requestEncoder: requestOptions.requestEncoder,
        responseDecoder: requestOptions.responseDecoder,
        listFormat: requestOptions.listFormat,
      ),
    );
  }

  void _rejectPendingRequests(Object error) {
    for (final pending in _pendingRequests) {
      pending.handler.reject(
        DioException(
          requestOptions: pending.requestOptions,
          error: error,
        ),
      );
    }
  }

  // تجديد Access Token باستخدام Refresh Token
  Future<_RefreshResult> _refreshAccessToken() async {
    try {
      print('🔄 ========== API REFRESH TOKEN ==========');
      final refreshToken = await getRefreshToken();
      
      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ No refresh token found');
        return _RefreshResult.invalidToken;
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
          return _RefreshResult.success;
        }
        return _RefreshResult.networkError;
      }
      
      print('❌ REFRESH TOKEN FAILED: ${response.data}');
      return _RefreshResult.networkError;
    } on DioException catch (e) {
      print('❌ REFRESH TOKEN DIO ERROR: ${e.type} - ${e.response?.statusCode}');
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return _RefreshResult.invalidToken;
      }
      return _RefreshResult.networkError;
    } catch (e) {
      print('❌ REFRESH TOKEN ERROR: $e');
      return _RefreshResult.networkError;
    }
  }

  bool _isRetriableGetError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return true;
    }
    final status = error.response?.statusCode ?? 0;
    return status == 408 || status == 429 || status >= 500;
  }

  Future<dio.Response> _performGetWithRetry(
    Future<dio.Response> Function() action, {
    required String endpoint,
  }) async {
    for (var attempt = 0; attempt <= _maxGetRetries; attempt++) {
      try {
        return await action();
      } on DioException catch (e) {
        final isLastAttempt = attempt >= _maxGetRetries;
        if (!_isRetriableGetError(e) || isLastAttempt) {
          rethrow;
        }
        final delayMs = _baseGetRetryDelay.inMilliseconds * (attempt + 1);
        AppLogger.warning(
          'Retrying GET request',
          scope: 'ApiService',
          error: 'endpoint=$endpoint attempt=${attempt + 1} delayMs=$delayMs',
        );
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw NetworkException('فشل جلب البيانات بعد عدة محاولات');
  }

  // GET Request
  /// When [baseUrlOverride] is set, the request is sent to that base URL (e.g. for call center Kendy branch).
  Future<dio.Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    dio.Options? options,
    String? baseUrlOverride,
  }) async {
    if (baseUrlOverride != null && baseUrlOverride.isNotEmpty) {
      final base = baseUrlOverride.endsWith('/')
          ? baseUrlOverride.substring(0, baseUrlOverride.length - 1)
          : baseUrlOverride;
      final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final uri = queryParameters != null && queryParameters.isNotEmpty
            ? Uri.parse('$base$path').replace(
                queryParameters: Map<String, String>.fromEntries(
                  queryParameters.entries.map(
                    (e) => MapEntry(e.key, e.value?.toString() ?? ''),
                  ),
                ),
              )
            : Uri.parse('$base$path');
      try {
        final token = await _storage.read(key: ApiConstants.tokenKey);
        final headers = <String, dynamic>{
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };
        final response = await _performGetWithRetry(
          () => _dio.fetch(
            RequestOptions(
              method: 'GET',
              path: uri.toString(),
              headers: headers,
              sendTimeout: options?.sendTimeout ??
                  const Duration(milliseconds: ApiConstants.connectionTimeout),
              receiveTimeout: options?.receiveTimeout ??
                  const Duration(milliseconds: ApiConstants.receiveTimeout),
            ),
          ),
          endpoint: uri.toString(),
        );
        return response;
      } on DioException catch (e) {
        throw _handleDioError(e);
      } catch (e) {
        throw NetworkException(e.toString());
      }
    }
    try {
      final response = await _performGetWithRetry(
        () => _dio.get(
          endpoint,
          queryParameters: queryParameters,
          options: options,
        ),
        endpoint: endpoint,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  // POST Request
  /// When [baseUrlOverride] is set, the request is sent to that base URL (e.g. for call center Kendy branch).
  Future<dio.Response> post(
    String endpoint, {
    dynamic data,
    dio.FormData? formData,
    dio.Options? options,
    String? baseUrlOverride,
  }) async {
    dynamic requestData = formData ?? data;
    if (formData == null &&
        data is String &&
        options?.contentType == 'application/x-www-form-urlencoded') {
      requestData = utf8.encode(data);
    }

    if (baseUrlOverride != null && baseUrlOverride.isNotEmpty) {
      final base = baseUrlOverride.endsWith('/')
          ? baseUrlOverride.substring(0, baseUrlOverride.length - 1)
          : baseUrlOverride;
      final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final uri = Uri.parse('$base$path');
      print('🌐 [ApiService] POST Request (override): $uri');
      try {
        final token = await _storage.read(key: ApiConstants.tokenKey);
        final headers = <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };
        final optsHeaders = options?.headers;
        if (optsHeaders != null) {
          for (final e in optsHeaders.entries) {
            headers[e.key] = e.value;
          }
        }
        final response = await _dio.fetch(
          RequestOptions(
            method: 'POST',
            path: uri.toString(),
            data: requestData,
            headers: headers,
            sendTimeout: options?.sendTimeout ??
                const Duration(milliseconds: ApiConstants.connectionTimeout),
            receiveTimeout: options?.receiveTimeout ??
                const Duration(milliseconds: ApiConstants.receiveTimeout),
          ),
        );
        print('✅ [ApiService] POST Success (override): ${response.statusCode}');
        return response;
      } on DioException catch (e) {
        throw _handleDioError(e);
      } catch (e) {
        throw NetworkException(e.toString());
      }
    }

    final fullUrl = '${ApiConstants.baseUrl}$endpoint';
    print('🌐 [ApiService] POST Request: $fullUrl');
    if (options?.headers != null) {
      print('🌐 [ApiService] Request Headers: ${options!.headers}');
    }
    if (formData != null) {
      print('🌐 [ApiService] Data Type: FormData');
    } else if (data is String) {
      print('🌐 [ApiService] Data Type: String (${data.length} chars)');
      print('🌐 [ApiService] Data Preview: ${data.length > 100 ? data.substring(0, 100) + "..." : data}');
    } else if (data != null) {
      print('🌐 [ApiService] Data Type: ${data.runtimeType}');
      print('🌐 [ApiService] Data: $data');
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
  /// When [baseUrlOverride] is set, the request is sent to that base URL (e.g. for call center Kendy branch).
  Future<dio.Response> put(
    String endpoint, {
    Map<String, dynamic>? data,
    dio.FormData? formData,
    dio.Options? options,
    String? baseUrlOverride,
  }) async {
    if (baseUrlOverride != null && baseUrlOverride.isNotEmpty) {
      final base = baseUrlOverride.endsWith('/')
          ? baseUrlOverride.substring(0, baseUrlOverride.length - 1)
          : baseUrlOverride;
      final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final uri = Uri.parse('$base$path');
      try {
        final token = await _storage.read(key: ApiConstants.tokenKey);
        final headers = <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };
        final response = await _dio.fetch(
          RequestOptions(
            method: 'PUT',
            path: uri.toString(),
            data: formData ?? data,
            headers: headers,
            sendTimeout: options?.sendTimeout ??
                const Duration(milliseconds: ApiConstants.connectionTimeout),
            receiveTimeout: options?.receiveTimeout ??
                const Duration(milliseconds: ApiConstants.receiveTimeout),
          ),
        );
        return response;
      } on DioException catch (e) {
        throw _handleDioError(e);
      } catch (e) {
        throw NetworkException(e.toString());
      }
    }
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
  /// When [baseUrlOverride] is set, the request is sent to that base URL (e.g. for call center Kendy branch).
  Future<dio.Response> delete(
    String endpoint, {
    Map<String, dynamic>? data,
    dio.Options? options,
    String? baseUrlOverride,
  }) async {
    if (baseUrlOverride != null && baseUrlOverride.isNotEmpty) {
      final base = baseUrlOverride.endsWith('/')
          ? baseUrlOverride.substring(0, baseUrlOverride.length - 1)
          : baseUrlOverride;
      final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final uri = Uri.parse('$base$path');
      try {
        final token = await _storage.read(key: ApiConstants.tokenKey);
        final headers = <String, dynamic>{
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };
        final response = await _dio.fetch(
          RequestOptions(
            method: 'DELETE',
            path: uri.toString(),
            data: data,
            headers: headers,
            sendTimeout: options?.sendTimeout ??
                const Duration(milliseconds: ApiConstants.connectionTimeout),
            receiveTimeout: options?.receiveTimeout ??
                const Duration(milliseconds: ApiConstants.receiveTimeout),
          ),
        );
        return response;
      } on DioException catch (e) {
        throw _handleDioError(e);
      } catch (e) {
        throw NetworkException(e.toString());
      }
    }
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

enum _RefreshResult {
  success,
  invalidToken,
  networkError,
}
