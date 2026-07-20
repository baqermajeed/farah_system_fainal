import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/services/fcm_service.dart';
import 'package:farah_sys_final/services/notification_service.dart';

/// Controller لشاشة الإشعارات — كاش Hive + pagination (30) + تحديث خلفي.
class NotificationsScreenController extends GetxController {
  final NotificationService _notificationService = NotificationService();

  static const int pageSize = 30;

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool hasMore = true.obs;

  final ScrollController scrollController = ScrollController();

  bool _loadingMoreLock = false;

  String get _cacheKey {
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final userId = auth?.currentUser.value?.id ?? 'guest';
    final patientId = auth?.patientProfileId.value;
    if (patientId != null && patientId.isNotEmpty) {
      return 'user_${userId}_patient_$patientId';
    }
    return 'user_$userId';
  }

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    loadNotifications();
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final pos = scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      unawaited(loadMore());
    }
  }

  List<NotificationModel> _readCache() {
    try {
      final box = Hive.box('notifications');
      final raw = box.get(_cacheKey);
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notifications] cache read error: $e');
      }
      return const [];
    }
  }

  Future<void> _writeCache(List<NotificationModel> items) async {
    try {
      final box = Hive.box('notifications');
      // نخزّن أول صفحة + ما تم تحميله محلياً (حد معقول)
      final toStore = items.take(pageSize * 5).toList();
      await box.put(
        _cacheKey,
        toStore.map((n) => n.toJson()).toList(),
      );
      await box.put(
        '${_cacheKey}_lastUpdated',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notifications] cache write error: $e');
      }
    }
  }

  /// تحميل أولي: كاش فوري (مصفّى) ثم تحديث من السيرفر لفرد العائلة النشط فقط.
  Future<void> loadNotifications({bool forceRefresh = false}) async {
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final activePatientId = auth?.patientProfileId.value;

    final cached = _readCache()
        .where((n) => n.belongsToPatient(activePatientId))
        .toList();
    final hasCache = cached.isNotEmpty;

    if (hasCache && (notifications.isEmpty || forceRefresh)) {
      notifications.assignAll(cached);
    } else if (!hasCache) {
      // لا نعرض كاش فرد آخر
      notifications.clear();
    }

    if (!hasCache && notifications.isEmpty) {
      isLoading.value = true;
    } else {
      isRefreshing.value = true;
    }

    try {
      final items = await _notificationService.getNotifications(
        skip: 0,
        limit: pageSize,
        patientId: activePatientId,
      );

      hasMore.value = items.length >= pageSize;
      // استبدل دائماً بنتيجة الفرد النشط (لا تخلط مع كاش قديم)
      notifications.assignAll(items);
      await _writeCache(items);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading notifications: $e');
      }
      if (notifications.isEmpty) {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل الإشعارات');
      }
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  /// صفحة تالية (30 أخرى) عند السكرول للأسفل.
  Future<void> loadMore() async {
    if (_loadingMoreLock ||
        isLoadingMore.value ||
        isLoading.value ||
        !hasMore.value) {
      return;
    }

    final activePatientId = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().patientProfileId.value
        : null;

    _loadingMoreLock = true;
    isLoadingMore.value = true;
    try {
      final skip = notifications.length;
      final items = await _notificationService.getNotifications(
        skip: skip,
        limit: pageSize,
        patientId: activePatientId,
      );

      if (items.length < pageSize) {
        hasMore.value = false;
      }
      if (items.isEmpty) return;

      final existingIds = notifications.map((n) => n.id).toSet();
      final toAdd = items
          .where((n) => !existingIds.contains(n.id))
          .where((n) => n.belongsToPatient(activePatientId))
          .toList();
      if (toAdd.isNotEmpty) {
        notifications.addAll(toAdd);
        await _writeCache(notifications.toList());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading more notifications: $e');
      }
    } finally {
      isLoadingMore.value = false;
      _loadingMoreLock = false;
    }
  }

  Future<void> markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    try {
      await _notificationService.markAsRead(notification.id);
      final index = notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        notifications[index] = notification.copyWith(isRead: true);
        await _writeCache(notifications.toList());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error marking notification as read: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      notifications.assignAll(
        notifications.map((n) => n.copyWith(isRead: true)).toList(),
      );
      await _writeCache(notifications.toList());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error marking all as read: $e');
      }
    }
  }

  Future<void> handleNotificationTap(NotificationModel notification) async {
    await markAsRead(notification);

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
