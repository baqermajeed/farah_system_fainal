import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';

class NetworkUtils {
  /// Simple connectivity check by attempting to open a socket to the API host.
  static Future<bool> hasInternetConnection() async {
    try {
      final uri = Uri.parse(ApiConstants.baseUrl);
      final host = uri.host.isNotEmpty ? uri.host : ApiConstants.baseUrl;
      final port = uri.port == 0 ? 443 : uri.port;

      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Detect if an error is network-related.
  static bool isNetworkError(Object error) {
    if (error is NetworkException) return true;

    final message = error.toString();
    return message.contains('الاتصال') ||
        message.contains('الإنترنت') ||
        message.contains('السيرفر') ||
        message.contains('connection') ||
        message.contains('Network');
  }

  /// Centralized "check your internet connection" dialog.
  static Future<void> showNetworkErrorDialog() async {
    // If there is no active context, we can't show a dialog safely.
    if (Get.context == null) return;

    // Use post-frame to avoid "deactivated widget" issues.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Get.context == null) return;

      // Close any existing dialog first to avoid stacking.
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      try {
        await Get.dialog(
          AlertDialog(
            title: const Text('خطأ في الاتصال'),
            content: const Text(
              'تعذر الاتصال بالخادم.\n'
              'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
          barrierDismissible: true,
        );
      } catch (_) {
        // Ignore dialog errors to avoid crashing the app.
      }
    });
  }
}


