import 'network_utils.dart';

/// رسائل أخطاء مناسبة للمستخدم دون ذكر السيرفر أو الباكند.
class UserErrorMessages {
  UserErrorMessages._();

  static const otpSendFailed = 'تعذر إرسال رمز التحقق، حاول مرة أخرى';
  static const invalidPhone = 'رقم الهاتف غير صحيح';

  static bool isTechnicalOrServerText(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return true;
    if (NetworkUtils.hasForbiddenConnectionText(trimmed)) return true;
    if (NetworkUtils.isNetworkError(trimmed)) return true;

    final lower = trimmed.toLowerCase();
    const technicalFragments = [
      'exception',
      'dioexception',
      'apiexception',
      'socketexception',
      'failed to send',
      'internal server',
      'bad gateway',
      'service unavailable',
      'gateway timeout',
      'otpiq',
      'status code',
      'http/',
      'traceback',
      'stack trace',
      'الخادم',
      'السيرفر',
      'الباكند',
    ];
    for (final fragment in technicalFragments) {
      if (lower.contains(fragment)) return true;
    }

    if (RegExp(r'\b5\d{2}\b').hasMatch(trimmed)) return true;

    return false;
  }

  static String otpRequestMessage({String? raw, int? statusCode}) {
    if (statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504 ||
        (statusCode != null && statusCode >= 500)) {
      return otpSendFailed;
    }

    final message = raw?.trim() ?? '';
    final lower = message.toLowerCase();

    if (lower.contains('invalid phone') || message.contains('رقم غير صالح')) {
      return invalidPhone;
    }
    if (lower.contains('failed to send otp')) {
      return otpSendFailed;
    }
    if (message.isEmpty || isTechnicalOrServerText(message)) {
      return otpSendFailed;
    }

    return message;
  }
}
