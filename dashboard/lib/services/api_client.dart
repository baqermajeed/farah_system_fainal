import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import 'auth_service.dart';
import 'secure_storage_service.dart';

class ApiClient {
  ApiClient._() {
    // Add interceptors for automatic token refresh
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add token to headers
          if (_token != null && _token!.isNotEmpty) {
            options.headers['authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 errors - try to refresh token
          if (error.response?.statusCode == 401) {
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
            final authService = AuthService();
            final refreshed = await authService.refreshAccessToken();
            
            if (refreshed) {
              // نجح التجديد - إعادة المحاولة للطلبات المعلقة
              _isRefreshing = false;
              await _retryPendingRequests();
              
              // إعادة المحاولة للطلب الأصلي
              final opts = requestOptions;
              opts.headers['authorization'] = 'Bearer $_token';
              final response = await dio.fetch(opts);
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

  static final ApiClient instance = ApiClient._();

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 18),
      headers: {'accept': 'application/json'},
    ),
  );

  String? _token;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  void setToken(String? token) {
    _token = token;
  }

  Future<void> _handleUnauthorized() async {
    final storage = SecureStorageService();
    await storage.clearToken();
    _token = null;
  }

  void _addPendingRequest(RequestOptions requestOptions, ErrorInterceptorHandler handler) {
    _pendingRequests.add(_PendingRequest(
      requestOptions: requestOptions,
      handler: handler,
    ));
  }

  Future<void> _retryPendingRequests() async {
    if (_token == null) return;

    for (final pending in _pendingRequests) {
      try {
        pending.requestOptions.headers['authorization'] = 'Bearer $_token';
        final response = await dio.fetch(pending.requestOptions);
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

  Options authorizedOptions([Options? options]) {
    final headers = <String, dynamic>{...?(options?.headers)};
    if (_token != null && _token!.isNotEmpty) {
      headers['authorization'] = 'Bearer $_token';
    }
    return (options ?? Options()).copyWith(headers: headers);
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


