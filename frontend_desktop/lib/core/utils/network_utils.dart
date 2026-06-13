import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';

class NetworkUtils {
  /// يتحقق من وجود اتصال فعلي بالشبكة (عن طريق محاولة الوصول إلى مضيف الـ API).
  static Future<bool> hasInternetConnection() async {
    try {
      final uri = Uri.parse(ApiConstants.baseUrl);
      final host = uri.host.isNotEmpty ? uri.host : 'google.com';
      final port = uri.hasPort
          ? uri.port
          : (uri.scheme.toLowerCase() == 'http' ? 80 : 443);

      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));

      if (result.isEmpty || result.first.rawAddress.isEmpty) return false;

      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// يحدد إن كان الخطأ ناتج عن الشبكة / الاتصال بالسيرفر.
  static bool isNetworkError(Object error) {
    if (error is NetworkException) return true;
    final message = (error is ApiException ? error.message : error.toString())
        .toLowerCase();
    return message.contains('الاتصال') ||
        message.contains('الإنترنت') ||
        message.contains('السيرفر') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('socket') ||
        message.contains('failed host lookup');
  }

  /// يعرض دايلوج موحّد للتحذير من مشاكل الاتصال بالشبكة / السيرفر.
  static void showNetworkErrorDialog() {
    // التأكد من وجود context نشط قبل عرض Dialog
    if (Get.context == null) {
      print('⚠️ [NetworkUtils] Cannot show dialog - context is not available');
      return;
    }

    // إذا كان هناك دايلوج مفتوح لننهيه أولاً لتفادي التكدس
    if (Get.isDialogOpen == true) {
      Get.back();
    }

    // استخدام addPostFrameCallback للتأكد من أن الشجرة جاهزة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = Get.context;
      if (context != null && Get.isDialogOpen != true) {
        try {
          Get.dialog(
            AlertDialog(
              title: const Text('خطأ في الاتصال'),
              content:
                  const Text('تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('حسناً'),
                ),
              ],
            ),
            barrierDismissible: false,
          );
        } catch (e) {
          print('⚠️ [NetworkUtils] Error showing dialog: $e');
        }
      }
    });
  }
}

