import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/services/local_notification_service.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/doctor_home_controller.dart';
import 'package:farah_sys_final/controllers/notifications_screen_controller.dart';
import 'package:farah_sys_final/controllers/patient_home_controller.dart';
import 'package:farah_sys_final/controllers/doctor_chats_screen_controller.dart';
import 'dart:io';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await LocalNotificationService.initialize();
  await LocalNotificationService.showFromRemoteMessage(message);
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
      await LocalNotificationService.initialize();

      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final permissionGranted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (permissionGranted) {
        debugPrint('✅ [FCM] Notification permission granted');
      } else if (!Platform.isAndroid) {
        debugPrint(
          '❌ [FCM] User declined notification permission (iOS)',
        );
        _initialized = true;
        return;
      } else {
        debugPrint(
          '⚠️ [FCM] Android notification permission not granted — push may be limited',
        );
      }

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('📱 [FCM] Token: $token');
        await _registerToken(token);
      } else {
        debugPrint('❌ [FCM] Failed to obtain device token');
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 [FCM] Token refreshed');
        _currentToken = newToken;
        _registerToken(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '📨 [FCM] Foreground message: ${message.notification?.title}',
        );
        _handleForegroundMessage(message);
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
        Future.delayed(const Duration(milliseconds: 800), () {
          handleNotificationNavigation(initialMessage.data);
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint('❌ [FCM] Error initializing: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? '';

    if (type == 'message') {
      _refreshChatUnreadCounts();
    } else {
      refreshHomeUnreadCounts();
      if (Get.isRegistered<NotificationsScreenController>()) {
        Get.find<NotificationsScreenController>()
            .loadNotifications(forceRefresh: true);
      }
    }

    LocalNotificationService.showFromRemoteMessage(message);
  }

  void _refreshChatUnreadCounts() {
    try {
      if (_isDoctor()) {
        if (Get.isRegistered<DoctorHomeController>()) {
          Get.find<DoctorHomeController>().loadUnreadCounts();
        }
        if (Get.isRegistered<DoctorChatsScreenController>()) {
          Get.find<DoctorChatsScreenController>().loadChatList();
        }
      } else if (Get.isRegistered<PatientHomeController>()) {
        Get.find<PatientHomeController>().loadUnreadCount();
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error refreshing chat unread: $e');
    }
  }

  bool _isDoctor() {
    if (!Get.isRegistered<AuthController>()) return false;
    final type =
        Get.find<AuthController>().currentUser.value?.userType.toLowerCase();
    return type == 'doctor';
  }

  String? _activePatientId() {
    if (!Get.isRegistered<AuthController>()) return null;
    final id = Get.find<AuthController>().patientProfileId.value;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// تحديث عداد الإشعارات غير المقروءة في الشاشة الرئيسية.
  void refreshHomeUnreadCounts() {
    try {
      if (_isDoctor()) {
        if (Get.isRegistered<DoctorHomeController>()) {
          Get.find<DoctorHomeController>().loadUnreadNotificationsCount();
        }
      } else if (Get.isRegistered<PatientHomeController>()) {
        Get.find<PatientHomeController>().loadUnreadNotificationsCount();
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error refreshing unread counts: $e');
    }
  }

  /// Navigate based on notification type / data payload.
  void handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final isDoctor = _isDoctor();

    switch (type) {
      case 'appointment_created':
      case 'appointment_reminder':
      case 'appointment_updated':
        Get.toNamed(
          isDoctor ? AppRoutes.appointments : AppRoutes.patientAppointments,
        );
        break;
      case 'message':
        _navigateToMessageChat(data, isDoctor: isDoctor);
        break;
      case 'implant_stage':
        if (!isDoctor) {
          Get.toNamed(AppRoutes.dentalImplantTimeline);
        } else {
          Get.toNamed(AppRoutes.notifications);
        }
        break;
      case 'general':
      default:
        Get.toNamed(AppRoutes.notifications);
        break;
    }
  }

  void _navigateToMessageChat(
    Map<String, dynamic> data, {
    required bool isDoctor,
  }) {
    if (isDoctor) {
      final patientId = data['patientId']?.toString();
      if (patientId != null && patientId.isNotEmpty) {
        Get.toNamed(
          AppRoutes.chat,
          arguments: {'patientId': patientId},
        );
      } else {
        Get.toNamed(AppRoutes.doctorChats);
      }
      return;
    }

    final patientId =
        data['patientId']?.toString() ?? _activePatientId();
    if (patientId == null || patientId.isEmpty) {
      Get.toNamed(AppRoutes.notifications);
      return;
    }

    final doctorUserId = data['doctorUserId']?.toString();
    Get.toNamed(
      AppRoutes.chat,
      arguments: {
        'patientId': patientId,
        if (doctorUserId != null && doctorUserId.isNotEmpty)
          'doctorUserId': doctorUserId,
      },
    );
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
      debugPrint('📱 [FCM] Re-register token: $token');
      await _registerToken(token);
    }
  }
}
