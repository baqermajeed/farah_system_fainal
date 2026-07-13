import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/services/chat_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

class _NotifAssets {
  static const back = 'assets/icon/backblack.png';
  static const dateIcon = 'assets/icon/date23.png';
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _bg = Color(0xFFF8FAFF);
  static const Color _navy = Color(0xFF1A3263);
  static const Color _grayText = Color(0xFF8A97A8);
  static const Color _border = Color(0xFFE8ECF0);
  static const double _headerBoxSize = 50;
  static const double _headerBoxRadius = 16;

  final AppointmentController _appointmentController =
      Get.find<AppointmentController>();
  final PatientController _patientController = Get.find<PatientController>();
  final ChatService _chatService = ChatService();

  final RxList<NotificationItem> _notifications = <NotificationItem>[].obs;
  final RxBool _isLoading = true.obs;
  Box? _readNotificationsBox;

  static List<BoxShadow> get _softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get _headerShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: Offset.zero,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _initStorageAndLoad();
  }

  Future<void> _initStorageAndLoad() async {
    try {
      _readNotificationsBox = await Hive.openBox('read_notifications');
      await _loadNotifications();
    } catch (e) {
      debugPrint('❌ Error initializing storage: $e');
      await _loadNotifications();
    }
  }

  bool _isNotificationRead(String notificationId) {
    try {
      if (_readNotificationsBox == null) return false;
      return _readNotificationsBox!.get(notificationId, defaultValue: false)
          as bool;
    } catch (e) {
      return false;
    }
  }

  void _markAsRead(String notificationId) {
    try {
      if (_readNotificationsBox == null) return;
      _readNotificationsBox!.put(notificationId, true);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final n = _notifications[index];
        _notifications[index] = NotificationItem(
          id: n.id,
          title: n.title,
          body: n.body,
          time: n.time,
          isRead: true,
          type: n.type,
          data: n.data,
        );
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  void _markAllAsRead() {
    try {
      if (_readNotificationsBox == null) return;
      for (final notification in _notifications) {
        _readNotificationsBox!.put(notification.id, true);
      }
      _loadNotifications();
      Get.snackbar('نجح', 'تم تحديد جميع الإشعارات كمقروءة');
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      _isLoading.value = true;
      final notifications = <NotificationItem>[];

      final upcomingAppointments =
          _appointmentController.getUpcomingAppointments();
      final defaultDoctorName =
          _patientController.myDoctor.value?['name'] ?? 'طبيبك';

      for (final appointment in upcomingAppointments) {
        final appointmentDoctorName = appointment.doctorName.isNotEmpty
            ? appointment.doctorName
            : defaultDoctorName;
        final appointmentDate = appointment.date;
        final appointmentTime = appointment.time;

        final dateFormat = DateFormat('dd-MM-yyyy', 'ar');
        final formattedDate = dateFormat.format(appointmentDate);

        final timeParts = appointmentTime.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = timeParts.length > 1 ? timeParts[1] : '00';
        final isPM = hour >= 12;
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final timeText = '$displayHour:$minute';
        final periodText = isPM ? 'مساءً' : 'صباحاً';

        final notificationId = 'appointment_${appointment.id}';
        final isRead = _isNotificationRead(notificationId);

        notifications.add(NotificationItem(
          id: notificationId,
          title: 'موعد جديد',
          body:
              'لديك موعد مع الطبيب $appointmentDoctorName في $formattedDate الساعة $timeText $periodText',
          time: appointmentDate,
          isRead: isRead,
          type: NotificationType.appointment,
          data: {'appointmentId': appointment.id},
        ));
      }

      try {
        final chatList = await _chatService.getChatList();
        if (chatList.isNotEmpty) {
          final chat = chatList[0];
          final unreadCount = chat['unread_count'] as int? ?? 0;

          if (unreadCount > 0) {
            final doctorName =
                _patientController.myDoctor.value?['name'] ?? 'طبيبك';
            final patientId = chat['patient_id'] as String?;
            final notificationId = 'message_${patientId ?? 'unknown'}';
            final isRead = _isNotificationRead(notificationId);

            notifications.add(NotificationItem(
              id: notificationId,
              title: 'رسالة جديدة',
              body: 'رسالة جديدة من الدكتور $doctorName',
              time: DateTime.now(),
              isRead: isRead,
              type: NotificationType.message,
              data: {'patientId': patientId},
            ));
          }
        }
      } catch (e) {
        debugPrint('❌ Error loading chat notifications: $e');
      }

      notifications.sort((a, b) => b.time.compareTo(a.time));
      _notifications.value = notifications;
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل الإشعارات');
    } finally {
      _isLoading.value = false;
    }
  }

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
                  if (_isLoading.value) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: _navy,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  if (_notifications.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.notifications_none_outlined,
                      title: 'لا توجد إشعارات',
                      subtitle: 'لم يتم استلام أي إشعارات بعد',
                    );
                  }

                  final unreadCount =
                      _notifications.where((n) => !n.isRead).length;

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                    itemCount: _notifications.length + (unreadCount > 0 ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (unreadCount > 0 && index == 0) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Text(
                            '$unreadCount إشعار${unreadCount > 1 ? 'ات' : ''} غير مقروءة',
                            style: AppFonts.lamaSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: _grayText,
                            ),
                          ),
                        );
                      }

                      final notifIndex = unreadCount > 0 ? index - 1 : index;
                      return _buildNotificationItem(
                        _notifications[notifIndex],
                      );
                    },
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
                  'تابع مواعيدك ورسائلك',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _markAllAsRead,
            child: Container(
              width: _headerBoxSize.w,
              height: _headerBoxSize.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_headerBoxRadius.r),
                boxShadow: _headerShadow,
              ),
              child: Icon(
                Icons.done_all_rounded,
                color: _navy,
                size: 24.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    final timeAgo = _getTimeAgo(notification.time);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
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
                              _buildNotificationIcon(notification.type),
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

  Widget _buildNotificationIcon(NotificationType type) {
    if (type == NotificationType.appointment) {
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

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.appointment:
        return Icons.calendar_today_outlined;
      case NotificationType.message:
        return Icons.chat_bubble_outline_rounded;
      case NotificationType.reminder:
        return Icons.alarm_outlined;
      case NotificationType.patient:
        return Icons.person_add_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.appointment:
        return _navy;
      case NotificationType.message:
        return const Color(0xFF3B82F6);
      case NotificationType.reminder:
        return const Color(0xFFF59E0B);
      case NotificationType.patient:
        return const Color(0xFF2EAF68);
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

  void _handleNotificationTap(NotificationItem notification) {
    _markAsRead(notification.id);

    switch (notification.type) {
      case NotificationType.appointment:
        Get.toNamed(AppRoutes.patientAppointments);
        break;
      case NotificationType.message:
        final patientId = notification.data?['patientId'];
        if (patientId != null) {
          Get.toNamed(
            AppRoutes.chat,
            arguments: {'patientId': patientId},
          );
        }
        break;
      case NotificationType.reminder:
        Get.toNamed(AppRoutes.patientAppointments);
        break;
      default:
        break;
    }
  }
}

enum NotificationType {
  appointment,
  message,
  reminder,
  patient,
  other,
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final bool isRead;
  final NotificationType type;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.isRead,
    required this.type,
    this.data,
  });
}
