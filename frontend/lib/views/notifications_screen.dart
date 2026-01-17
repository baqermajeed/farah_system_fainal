import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/services/chat_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final AppointmentController _appointmentController = Get.find<AppointmentController>();
  final PatientController _patientController = Get.find<PatientController>();
  final ChatService _chatService = ChatService();
  
  final RxList<NotificationItem> _notifications = <NotificationItem>[].obs;
  final RxBool _isLoading = true.obs;
  Box? _readNotificationsBox;

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
      print('❌ Error initializing storage: $e');
      await _loadNotifications(); // جرب تحميل الإشعارات حتى لو فشل فتح الـ box
    }
  }

  bool _isNotificationRead(String notificationId) {
    try {
      if (_readNotificationsBox == null) return false;
      return _readNotificationsBox!.get(notificationId, defaultValue: false) as bool;
    } catch (e) {
      return false;
    }
  }

  void _markAsRead(String notificationId) {
    try {
      if (_readNotificationsBox == null) return;
      _readNotificationsBox!.put(notificationId, true);
      // تحديث حالة الإشعار في القائمة
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = NotificationItem(
          id: _notifications[index].id,
          title: _notifications[index].title,
          body: _notifications[index].body,
          time: _notifications[index].time,
          isRead: true,
          type: _notifications[index].type,
          data: _notifications[index].data,
        );
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  void _markAllAsRead() {
    try {
      if (_readNotificationsBox == null) return;
      for (final notification in _notifications) {
        _readNotificationsBox!.put(notification.id, true);
      }
      _loadNotifications(); // إعادة تحميل لتحديث الحالة
      Get.snackbar(
        'نجح',
        'تم تحديد جميع الإشعارات كمقروءة',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      _isLoading.value = true;
      final notifications = <NotificationItem>[];

      // جلب المواعيد القادمة
      final upcomingAppointments = _appointmentController.getUpcomingAppointments();
      final defaultDoctorName = _patientController.myDoctor.value?['name'] ?? 'طبيبك';
      
      for (final appointment in upcomingAppointments) {
        final appointmentDoctorName =
            appointment.doctorName.isNotEmpty ? appointment.doctorName : defaultDoctorName;
        final appointmentDate = appointment.date;
        final appointmentTime = appointment.time;
        
        // تنسيق التاريخ
        final dateFormat = DateFormat('dd-MM-yyyy', 'ar');
        final formattedDate = dateFormat.format(appointmentDate);
        
        // تنسيق الوقت
        final timeParts = appointmentTime.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = timeParts.length > 1 ? timeParts[1] : '00';
        final isPM = hour >= 12;
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final timeText = '$displayHour:$minute';
        final periodText = isPM ? 'مساءاً' : 'صباحاً';
        
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

      // جلب الرسائل غير المقروءة
      try {
        final chatList = await _chatService.getChatList();
        if (chatList.isNotEmpty) {
          final chat = chatList[0]; // المريض لديه محادثة واحدة مع طبيبه
          final unreadCount = chat['unread_count'] as int? ?? 0;
          
          if (unreadCount > 0) {
            final doctorName = _patientController.myDoctor.value?['name'] ?? 'طبيبك';
            final patientId = chat['patient_id'] as String?;
            
            final notificationId = 'message_${patientId ?? 'unknown'}';
            final isRead = _isNotificationRead(notificationId);
            
            notifications.add(NotificationItem(
              id: notificationId,
              title: 'رسالة جديدة',
              body: 'رسالة جديدة من الدكتور $doctorName',
              time: DateTime.now(), // يمكن استخدام وقت آخر رسالة إذا كان متوفراً
              isRead: isRead,
              type: NotificationType.message,
              data: {'patientId': patientId},
            ));
          }
        }
      } catch (e) {
        print('❌ Error loading chat notifications: $e');
      }

      // ترتيب الإشعارات حسب الوقت (الأحدث أولاً)
      notifications.sort((a, b) => b.time.compareTo(a.time));
      
      _notifications.value = notifications;
    } catch (e) {
      print('❌ Error loading notifications: $e');
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل الإشعارات');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Row(
                textDirection: ui.TextDirection.ltr,
                children: [
                  const BackButtonWidget(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'الإشعارات',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _markAllAsRead,
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.done_all,
                        color: AppColors.primary,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_isLoading.value) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                
                if (_notifications.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.notifications_none,
                    title: 'لا توجد إشعارات',
                    subtitle: 'لم يتم استلام أي إشعارات بعد',
                  );
                }
                
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return _buildNotificationItem(notification);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    final timeAgo = _getTimeAgo(notification.time);
    final icon = _getNotificationIcon(notification.type);
    final iconColor = _getNotificationColor(notification.type);

    return GestureDetector(
      onTap: () {
        _handleNotificationTap(notification);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: notification.isRead
              ? AppColors.white
              : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: notification.isRead
                ? AppColors.divider
                : AppColors.primary.withValues(alpha: 0.3),
            width: notification.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.divider,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: notification.isRead
                          ? FontWeight.w500
                          : FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.appointment:
        return Icons.calendar_today;
      case NotificationType.message:
        return Icons.chat_bubble_outline;
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.patient:
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.appointment:
        return AppColors.primary;
      case NotificationType.message:
        return AppColors.secondary;
      case NotificationType.reminder:
        return AppColors.warning;
      case NotificationType.patient:
        return AppColors.success;
      default:
        return AppColors.primary;
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
    // تحديد الإشعار كمقروء
    _markAsRead(notification.id);

    // الانتقال حسب نوع الإشعار
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
