import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'dart:io';

class FcmService extends GetxService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  ApiService get _apiService => Get.find<ApiService>();

  String? _currentToken;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ [FCM] User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ [FCM] User granted provisional notification permission');
      } else {
        print('❌ [FCM] User declined or has not accepted notification permission');
        return;
      }

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        print('📱 [FCM] Token obtained: ${token.substring(0, 20)}...');
        await _registerToken(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 [FCM] Token refreshed: ${newToken.substring(0, 20)}...');
        _currentToken = newToken;
        _registerToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 [FCM] Foreground message received: ${message.notification?.title}');
        // You can show a local notification here if needed
      });

      // Handle background messages (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📨 [FCM] Message opened app: ${message.notification?.title}');
        // Handle navigation here if needed
      });

      // Check if app was opened from a notification
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('📨 [FCM] App opened from notification: ${initialMessage.notification?.title}');
        // Handle navigation here if needed
      }
    } catch (e) {
      print('❌ [FCM] Error initializing: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerToken(String token) async {
    try {
      // Check if user is logged in
      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();
      
      if (!isLoggedIn) {
        print('ℹ️ [FCM] User not logged in, skipping token registration');
        return;
      }
      
      String platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');
      
      await _apiService.post(
        '/notifications/register',
        data: {
          'token': token,
          'platform': platform,
        },
      );
      
      print('✅ [FCM] Token registered successfully');
    } catch (e) {
      print('❌ [FCM] Error registering token: $e');
    }
  }

  /// Get current FCM token
  String? get currentToken => _currentToken;

  /// Re-register token (useful after login)
  Future<void> reRegisterToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }
  }
}

