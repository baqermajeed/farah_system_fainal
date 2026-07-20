import 'package:dio/dio.dart';

/// استثناء موحّد لفشل طلبات الـ API (نمط قريب).
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.data,
  });

  /// من جسم رد الـ API (FastAPI / detail / message / error).
  factory ApiException.fromResponse(dynamic body, int statusCode) {
    final map = _asMap(body);
    final detail = map['detail'];

    String message;
    String? code;

    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) {
        message = first['msg'].toString();
      } else {
        message = detail.toString();
      }
    } else if (detail is String && detail.isNotEmpty) {
      message = detail;
    } else if (map['error'] is Map) {
      final err = Map<String, dynamic>.from(map['error'] as Map);
      message = err['message']?.toString() ?? 'حدث خطأ، حاول مرة أخرى';
      code = err['code']?.toString();
    } else if (map['message'] != null) {
      message = map['message'].toString();
    } else if (body is String && body.isNotEmpty) {
      message = body;
    } else {
      message = 'حدث خطأ، حاول مرة أخرى';
    }

    return ApiException(
      message,
      code: code,
      statusCode: statusCode,
      data: body,
    );
  }

  /// من DioException إلى ApiException المناسب.
  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkException(
          'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
        );
      case DioExceptionType.cancel:
        return const NetworkException('تم إلغاء الطلب');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final parsed = ApiException.fromResponse(
          error.response?.data,
          statusCode,
        );
        return _typedFromStatus(parsed.message, statusCode, parsed.data);
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return NetworkException(
          'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
        );
    }
  }

  static ApiException _typedFromStatus(
    String message,
    int statusCode,
    dynamic data,
  ) {
    if (statusCode == 401) {
      return UnauthorizedException(message, data: data);
    }
    if (statusCode == 404) {
      return NotFoundException(message, data: data);
    }
    if (statusCode >= 500) {
      return NetworkException(
        'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
      );
    }
    if (_looksLikeConnectionWording(message)) {
      return NetworkException(
        'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
      );
    }
    return ServerException(message, statusCode: statusCode, data: data);
  }

  static bool _looksLikeConnectionWording(String message) {
    final lower = message.toLowerCase();
    return message.contains('الخادم') ||
        message.contains('السيرفر') ||
        message.contains('تعذر الاتصال') ||
        message.contains('الباكند') ||
        lower.contains('backend');
  }

  static Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return <String, dynamic>{};
  }

  final String message;
  final String? code;
  final int? statusCode;
  final dynamic data;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

class NetworkException extends ApiException {
  const NetworkException(String message, {dynamic data})
      : super(message, data: data);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(String message, {dynamic data})
      : super(message, statusCode: 401, data: data);
}

class NotFoundException extends ApiException {
  const NotFoundException(String message, {dynamic data})
      : super(message, statusCode: 404, data: data);
}

class ServerException extends ApiException {
  const ServerException(
    String message, {
    int? statusCode,
    dynamic data,
  }) : super(message, statusCode: statusCode, data: data);
}
