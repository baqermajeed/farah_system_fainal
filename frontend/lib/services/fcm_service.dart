import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'dart:io';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler — keep lightweight; navigation handled on open.
  debugPrint(
    '📨 [FCM] Background message: ${message.notification?.title} type=${message.data['type']}',
  );
}

class FcmService extends GetxService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  ApiService get _apiService => Get.find<ApiService>();

  String? _currentToken;
  bool _initialized = false;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ [FCM] User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ [FCM] User granted provisional notification permission');
      } else {
        debugPrint(
          '❌ [FCM] User declined or has not accepted notification permission',
        );
        _initialized = true;
        return;
      }

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('📱 [FCM] Token obtained: ${token.substring(0, 20)}...');
        await _registerToken(token);
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 [FCM] Token refreshed: ${newToken.substring(0, 20)}...');
        _currentToken = newToken;
        _registerToken(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '📨 [FCM] Foreground message: ${message.notification?.title}',
        );
        final title = message.notification?.title ?? 'إشعار جديد';
        final body = message.notification?.body ?? '';
        Get.snackbar(
          title,
          body,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
          onTap: (_) => handleNotificationNavigation(message.data),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📨 [FCM] Message opened app: ${message.notification?.title}');
        handleNotificationNavigation(message.data);
      });

      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '📨 [FCM] App opened from notification: ${initialMessage.notification?.title}',
        );
        // Delay so routes are ready
        Future.delayed(const Duration(milliseconds: 800), () {
          handleNotificationNavigation(initialMessage.data);
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint('❌ [FCM] Error initializing: $e');
    }
  }

  /// Navigate based on notification type / data payload.
  void handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    switch (type) {
      case 'appointment_created':
      case 'appointment_reminder':
      case 'appointment_updated':
        Get.toNamed(AppRoutes.patientAppointments);
        break;
      case 'message':
        final patientId = data['patientId']?.toString();
        if (patientId != null && patientId.isNotEmpty) {
          Get.toNamed(
            AppRoutes.chat,
            arguments: {'patientId': patientId},
          );
        }
        break;
      case 'implant_stage':
        Get.toNamed(AppRoutes.dentalImplantTimeline);
        break;
      case 'general':
      default:
        Get.toNamed(AppRoutes.notifications);
        break;
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();

      if (!isLoggedIn) {
        debugPrint('ℹ️ [FCM] User not logged in, skipping token registration');
        return;
      }

      final platform =
          Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');

      await _apiService.post(
        '/notifications/register',
        data: {
          'token': token,
          'platform': platform,
        },
      );

      debugPrint('✅ [FCM] Token registered successfully');
    } catch (e) {
      debugPrint('❌ [FCM] Error registering token: $e');
    }
  }

  String? get currentToken => _currentToken;

  Future<void> reRegisterToken() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      _currentToken = token;
      await _registerToken(token);
    }
  }
}
