import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android notification channel — must match backend FCM channel id.
const String kFarahNotificationChannelId = 'farah_high_importance';
const String kFarahNotificationChannelName = 'إشعارات مركز فرح';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        kFarahNotificationChannelId,
        kFarahNotificationChannelName,
        description: 'إشعارات المواعيد والرسائل والتنبيهات',
        importance: Importance.high,
        playSound: true,
      );

      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(channel);
      await android?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      // Navigation is handled by FcmService when app resumes; payload kept for future use.
      debugPrint('[LocalNotification] tapped payload=$payload');
    } catch (e) {
      debugPrint('[LocalNotification] tap error: $e');
    }
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    if (!_initialized) {
      await initialize();
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null || title.isEmpty) return;

    final id = message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final payload = jsonEncode(message.data);

    const androidDetails = AndroidNotificationDetails(
      kFarahNotificationChannelId,
      kFarahNotificationChannelName,
      channelDescription: 'إشعارات المواعيد والرسائل والتنبيهات',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body ?? '',
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }
}
