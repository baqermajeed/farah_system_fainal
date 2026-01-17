import 'package:dio/dio.dart';

import '../core/config/app_config.dart';

class ApiClient {
  ApiClient._();

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

  void setToken(String? token) {
    _token = token;
  }

  Options authorizedOptions([Options? options]) {
    final headers = <String, dynamic>{...?(options?.headers)};
    if (_token != null && _token!.isNotEmpty) {
      headers['authorization'] = 'Bearer $_token';
    }
    return (options ?? Options()).copyWith(headers: headers);
  }
}


