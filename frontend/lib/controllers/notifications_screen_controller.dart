import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/services/fcm_service.dart';
import 'package:farah_sys_final/services/notification_service.dart';

/// Controller لشاشة الإشعارات — المنطق والحالة خارج الـ View.
class NotificationsScreenController extends GetxController {
  final NotificationService _notificationService = NotificationService();

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      isLoading.value = true;
      final items = await _notificationService.getNotifications();
      notifications.assignAll(items);
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل الإشعارات');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    try {
      await _notificationService.markAsRead(notification.id);
      final index = notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        notifications[index] = notification.copyWith(isRead: true);
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      notifications.assignAll(
        notifications.map((n) => n.copyWith(isRead: true)).toList(),
      );
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  Future<void> handleNotificationTap(NotificationModel notification) async {
    await markAsRead(notification);

    // Prefer shared FCM navigation helper for type routing
    try {
      final fcm = Get.find<FcmService>();
      final data = <String, dynamic>{
        'type': notification.type,
        ...notification.data,
      };
      fcm.handleNotificationNavigation(data);
    } catch (_) {
      switch (notification.type) {
        case 'appointment_created':
        case 'appointment_reminder':
        case 'appointment_updated':
          Get.toNamed(AppRoutes.patientAppointments);
          break;
        case 'message':
          final patientId = notification.data['patientId']?.toString();
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
        default:
          break;
      }
    }
  }
}
