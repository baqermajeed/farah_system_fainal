import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';

class NetworkUtils {
  static bool _isShowingNetworkDialog = false;

  /// Simple connectivity check by attempting to open a socket to the API host.
  static Future<bool> hasInternetConnection() async {
    try {
      final uri = Uri.parse(ApiConstants.baseUrl);
      final host = uri.host.isNotEmpty ? uri.host : ApiConstants.baseUrl;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

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

  /// Messages that must never appear in snackbars/dialogs (server / connection).
  static bool hasForbiddenConnectionText(String message) {
    final lower = message.toLowerCase();
    return message.contains('الخادم') ||
        message.contains('السيرفر') ||
        message.contains('تعذر الاتصال') ||
        message.contains('الباكند') ||
        message.contains('تأكد من أن السيرفر') ||
        message.contains('تأكد من أن الباكند') ||
        message.contains('مشكلة في السيرفر') ||
        message.contains('مشكلة بالسيرفر') ||
        message.contains('مشكلة في الخادم') ||
        message.contains('مشكلة بالخادم') ||
        lower.contains('internal server') ||
        lower.contains('bad gateway') ||
        lower.contains('service unavailable') ||
        lower.contains('backend');
  }

  static String _messageOf(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  /// Detect if an error is network-related or forbidden server/connection wording.
  static bool isNetworkError(Object error) {
    if (error is NetworkException) return true;

    final message = _messageOf(error);
    if (hasForbiddenConnectionText(message)) return true;

    return message.contains('الاتصال') ||
        message.contains('الإنترنت') ||
        message.contains('السيرفر') ||
        message.contains('connection') ||
        message.contains('Network') ||
        message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('Network is unreachable') ||
        message.contains('مهلة الاتصال');
  }

  /// Show internet dialog for network/server-connection errors; otherwise a snackbar.
  /// Never shows snackbars/dialogs that mention السيرفر / الخادم / تعذر الاتصال بالخادم.
  static Future<void> showError(
    Object error, {
    String? fallbackMessage,
  }) async {
    final message = _messageOf(error);
    if (isNetworkError(error) || hasForbiddenConnectionText(message)) {
      await showNetworkErrorDialog();
      return;
    }

    final display = fallbackMessage ?? message;
    if (hasForbiddenConnectionText(display) || isNetworkError(display)) {
      await showNetworkErrorDialog();
      return;
    }

    Get.snackbar('خطأ', display);
  }

  /// Dialog: تأكد من الاتصال بالإنترنت — إغلاق / إعادة المحاولة.
  static Future<void> showNetworkErrorDialog() async {
    if (Get.context == null) return;
    if (_isShowingNetworkDialog) return;

    _isShowingNetworkDialog = true;
    final completer = Completer<void>();

    Future<void> present() async {
      try {
        while (Get.context != null) {
          final retry = await Get.dialog<bool>(
            AlertDialog(
              title: Text(
                'تأكد من الاتصال بالإنترنت',
                style: AppFonts.lamaSans(fontWeight: FontWeight.w700),
              ),
              content: Text(
                'تحقق من اتصالك بشبكة الإنترنت ثم حاول مرة أخرى.',
                style: AppFonts.lamaSans(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text('إغلاق', style: AppFonts.lamaSans()),
                ),
                TextButton(
                  onPressed: () => Get.back(result: true),
                  child: Text(
                    'إعادة المحاولة',
                    style: AppFonts.lamaSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            barrierDismissible: false,
          );

          if (retry != true) {
            break;
          }

          final hasConnection = await hasInternetConnection();
          if (hasConnection) {
            break;
          }
        }
      } catch (_) {
        // Ignore dialog errors to avoid crashing the app.
      } finally {
        _isShowingNetworkDialog = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      present();
    });

    return completer.future;
  }
}
