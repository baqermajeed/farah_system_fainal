import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/notifications_screen_controller.dart';
import 'package:farah_sys_final/services/notification_service.dart';

class _NotifAssets {
  static const back = 'assets/icon/backblack.png';
  static const dateIcon = 'assets/icon/date23.png';
}

class NotificationsScreen extends GetView<NotificationsScreenController> {
  const NotificationsScreen({super.key});

  static const Color _bg = Color(0xFFF8FAFF);
  static const Color _navy = Color(0xFF1A3263);
  static const Color _grayText = Color(0xFF8A97A8);
  static const Color _border = Color(0xFFE8ECF0);
  static const double _headerBoxSize = 50;

  static List<BoxShadow> get _softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final theme = baseTheme.copyWith(
      textTheme: AppFonts.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppFonts.textTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: _navy,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  if (controller.notifications.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.notifications_none_outlined,
                      title: 'لا توجد إشعارات',
                      subtitle: 'لم يتم استلام أي إشعارات بعد',
                    );
                  }

                  final unreadCount =
                      controller.notifications.where((n) => !n.isRead).length;

                  return RefreshIndicator(
                    color: _navy,
                    onRefresh: controller.loadNotifications,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                      itemCount:
                          controller.notifications.length +
                          (unreadCount > 0 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (unreadCount > 0 && index == 0) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$unreadCount إشعار${unreadCount > 1 ? 'ات' : ''} غير مقروءة',
                                    style: AppFonts.lamaSans(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _grayText,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: controller.markAllAsRead,
                                  child: Text(
                                    'قراءة الكل',
                                    style: AppFonts.lamaSans(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _navy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final notifIndex =
                            unreadCount > 0 ? index - 1 : index;
                        return _buildNotificationItem(
                          controller.notifications[notifIndex],
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          const BackButtonWidget(assetPath: _NotifAssets.back),
          Expanded(
            child: Column(
              children: [
                Text(
                  'الإشعارات',
                  style: AppFonts.lamaSans(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'مواعيد، رسائل، وتحديثات العيادة',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: _headerBoxSize.w, height: _headerBoxSize.w),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final timeAgo = _getTimeAgo(notification.sentAt);
    final type = notification.type;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(20.r),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: notification.isRead
                    ? _border
                    : _navy.withValues(alpha: 0.25),
                width: notification.isRead ? 1 : 1.5,
              ),
              boxShadow: _softShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: Directionality(
                textDirection: ui.TextDirection.rtl,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!notification.isRead)
                        Container(
                          width: 4.w,
                          color: _navy,
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(14.w),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildNotificationIcon(type),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notification.title,
                                            style: AppFonts.lamaSans(
                                              fontSize: 14.sp,
                                              fontWeight: notification.isRead
                                                  ? FontWeight.w700
                                                  : FontWeight.w800,
                                              color: _navy,
                                            ),
                                          ),
                                        ),
                                        if (!notification.isRead) ...[
                                          SizedBox(width: 6.w),
                                          Container(
                                            width: 8.w,
                                            height: 8.w,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF3B82F6),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      notification.body,
                                      style: AppFonts.lamaSans(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        color: _grayText,
                                        height: 1.45,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 8.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _bg,
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        timeAgo,
                                        style: AppFonts.lamaSans(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                          color: _grayText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String type) {
    if (type == 'appointment_created' ||
        type == 'appointment_updated' ||
        type == 'appointment_reminder') {
      return Container(
        width: 46.w,
        height: 46.w,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Center(
          child: Image.asset(
            _NotifAssets.dateIcon,
            width: 24.w,
            height: 24.w,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    final iconData = _getNotificationIcon(type);
    final iconColor = _getNotificationColor(type);

    return Container(
      width: 46.w,
      height: 46.w,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Icon(iconData, color: iconColor, size: 22.sp),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'appointment_created':
      case 'appointment_updated':
        return Icons.calendar_today_outlined;
      case 'appointment_reminder':
        return Icons.alarm_outlined;
      case 'message':
        return Icons.chat_bubble_outline_rounded;
      case 'implant_stage':
        return Icons.medical_services_outlined;
      case 'general':
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'appointment_created':
      case 'appointment_updated':
        return _navy;
      case 'appointment_reminder':
        return const Color(0xFFF59E0B);
      case 'message':
        return const Color(0xFF3B82F6);
      case 'implant_stage':
        return const Color(0xFF2EAF68);
      case 'general':
      default:
        return _navy;
    }
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return DateFormat('yyyy/MM/dd', 'ar').format(time);
    }
  }
}
