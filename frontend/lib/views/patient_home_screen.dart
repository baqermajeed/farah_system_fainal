import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/services/chat_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final ChatService _chatService = ChatService();
  final RxInt _unreadCount = 0.obs;
  final RxInt _unreadNotificationsCount = 0.obs;

  @override
  void initState() {
    super.initState();
    // تأجيل تحميل البيانات حتى بعد اكتمال بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnreadCount();
      _loadUnreadNotificationsCount();
      _loadData();
    });
  }

  void _loadData() {
    final patientController = Get.find<PatientController>();
    final appointmentController = Get.find<AppointmentController>();

    // تحميل البيانات فقط بدون أي تحقق أو إعادة توجيه
    print('🏠 [PatientHomeScreen] Loading data...');
    patientController.loadMyProfile().catchError((e) {
      print('❌ [PatientHomeScreen] Error loading profile: $e');
    });
    // تحميل المواعيد بشكل مستقل
    print('🏠 [PatientHomeScreen] Calling loadPatientAppointments...');
    appointmentController.loadPatientAppointments().catchError((e) {
      print('❌ [PatientHomeScreen] Error loading appointments: $e');
    });
    // تحميل معلومات الأطباء (يتم بشكل مستقل)
    patientController.loadMyDoctors().catchError((e) {
      print('❌ [PatientHomeScreen] Error loading doctors: $e');
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final chatList = await _chatService.getChatList();
      if (chatList.isNotEmpty) {
        // Patient has only one chat (with their doctor)
        final unreadCount = chatList[0]['unread_count'] as int? ?? 0;
        _unreadCount.value = unreadCount;
      } else {
        _unreadCount.value = 0;
      }
    } catch (e) {
      print('❌ Error loading unread count: $e');
      _unreadCount.value = 0;
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    try {
      final appointmentController = Get.find<AppointmentController>();
      int count = 0;

      // حساب المواعيد القادمة غير المقروءة
      final upcomingAppointments = appointmentController
          .getUpcomingAppointments();

      // استخدام Hive للتحقق من حالة القراءة
      try {
        final box = await Hive.openBox('read_notifications');
        for (final appointment in upcomingAppointments) {
          final notificationId = 'appointment_${appointment.id}';
          final isRead = box.get(notificationId, defaultValue: false) as bool;
          if (!isRead) {
            count++;
          }
        }
      } catch (e) {
        // إذا فشل فتح الـ box، نحسب جميع المواعيد كغير مقروءة
        count = upcomingAppointments.length;
      }

      // إضافة الرسائل غير المقروءة
      count += _unreadCount.value;

      _unreadNotificationsCount.value = count;
    } catch (e) {
      print('❌ Error loading unread notifications count: $e');
      _unreadNotificationsCount.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final patientController = Get.find<PatientController>();
    final appointmentController = Get.find<AppointmentController>();

    final baseTheme = Theme.of(context);
    final cairoTheme = baseTheme.copyWith(
      textTheme: GoogleFonts.cairoTextTheme(baseTheme.textTheme),
      primaryTextTheme: GoogleFonts.cairoTextTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: cairoTheme,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // Header with icons and title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bell icon with notification badge (left side)
                  GestureDetector(
                    onTap: () async {
                      await Get.toNamed(AppRoutes.notifications);
                      // إعادة تحميل عدد الإشعارات عند العودة
                      _loadUnreadNotificationsCount();
                    },
                    child: Obx(() {
                      final hasUnread = _unreadNotificationsCount.value > 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications,
                            color: AppColors.primary,
                            size: 30.sp,
                          ),
                          // Notification badge
                          if (hasUnread)
                            Positioned(
                              right: -4.w,
                              top: -4.h,
                              child: Container(
                                width: 8.w,
                                height: 8.w,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                  // Title in center
                  Text(
                    AppStrings.homePage,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Profile icon (right side)
                  GestureDetector(
                    onTap: () {
                      Get.toNamed(AppRoutes.patientProfile);
                    },
                    child: Image.asset(
                      'assets/images/Vector.png',
                      width: 26.sp,
                      height: 26.sp,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                        size: 30.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              // Welcome messages (centered)
              Column(
                children: [
                  Obx(() {
                    final user = authController.currentUser.value;
                    final profile = patientController.myProfile.value;
                    final patientName = user?.name ?? profile?.name ?? 'مريض';
                    return Text(
                      'مرحباً "$patientName"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const ui.Color.fromARGB(255, 71, 169, 230),
                      ),
                    );
                  }),
                  SizedBox(height: 4.h),
                  Text(
                    AppStrings.welcomeToClinic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const ui.Color.fromARGB(255, 71, 169, 230),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      patientController.myDoctors.length > 1
                          ? 'أطباؤك هم'
                          : 'طبيبك هو',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              // Doctors Cards
              Obx(() {
                final doctors = patientController.myDoctors;
                if (doctors.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      'لا يوجد أطباء مرتبطين',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return Column(
                  children: doctors.map<Widget>((doctor) {
                    final doctorName =
                        doctor['name'] != null &&
                            doctor['name'].toString().isNotEmpty
                        ? doctor['name']!
                        : 'طبيبك';
                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.only(
                        left: 20.w,
                        right: 0.w,
                        top: 2.h,
                        bottom: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Row(
                        children: [
                          // Doctor Image (على اليمين في RTL - أول عنصر)
                          Transform.translate(
                            offset: Offset(-4.w, 0),
                            child: Container(
                              width: 65.w,
                              height: 72.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.r),
                                child: Builder(
                                  builder: (context) {
                                    final doctorImageUrl = doctor['imageUrl'];
                                    final validImageUrl =
                                        ImageUtils.convertToValidUrl(
                                          doctorImageUrl,
                                        );

                                    if (validImageUrl != null &&
                                        ImageUtils.isValidImageUrl(
                                          validImageUrl,
                                        )) {
                                      return CachedNetworkImage(
                                        imageUrl: validImageUrl,
                                        width: 80.w,
                                        height: 85.h,
                                        fit: BoxFit.cover,
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                        memCacheWidth: 160,
                                        memCacheHeight: 170,
                                        placeholder: (context, url) =>
                                            Container(
                                              width: 80.w,
                                              height: 85.h,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16.r),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.secondary,
                                                  ],
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: AppColors.white,
                                                size: 30.sp,
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              width: 80.w,
                                              height: 85.h,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16.r),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.secondary,
                                                  ],
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: AppColors.white,
                                                size: 30.sp,
                                              ),
                                            ),
                                      );
                                    } else {
                                      return Container(
                                        width: 80.w,
                                        height: 85.h,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.secondary,
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: AppColors.white,
                                          size: 30.sp,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          // Doctor Details and Chat Icon
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.h),
                              child: Row(
                                children: [
                                  // Doctor Details (في المنتصف)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // الاسم مع تلوين مختلف
                                        RichText(
                                          textAlign: TextAlign.right,
                                          text: TextSpan(
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: 'الاسم : ',
                                                style: GoogleFonts.cairo(
                                                  fontWeight: FontWeight.w700,

                                                  color: const ui.Color.fromARGB(255, 95, 160, 225),
                                                  fontSize: 16.sp,
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'د. $doctorName',
                                                style: GoogleFonts.cairo(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                  fontSize: 16.sp,
                                                  
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          AppStrings.specialist,
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color: AppColors.textSecondary,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  // Chat Icon with notification dot (على اليسار في RTL - آخر عنصر)
                                  GestureDetector(
                                    onTap: () async {
                                      final profile =
                                          patientController.myProfile.value;
                                      final doctorId = doctor['id'];
                                      if (profile != null && doctorId != null) {
                                        await Get.toNamed(
                                          AppRoutes.chat,
                                          arguments: {
                                            'patientId': profile.id,
                                            'doctorId': doctorId.toString(),
                                            'doctorName': 'د. $doctorName',
                                          },
                                        );
                                        // Reload unread count when returning from chat
                                        await Future.delayed(
                                          const Duration(milliseconds: 300),
                                        );
                                        _loadUnreadCount();
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        Image.asset(
                                          'assets/images/message.png',
                                          width: 24.sp,
                                          height: 24.sp,
                                          fit: BoxFit.contain,
                                        ),
                                        Obx(() {
                                          if (_unreadCount.value > 0) {
                                            return Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                width: 10.w,
                                                height: 10.h,
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: AppColors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }),
              SizedBox(height: 24.h),
              // Dental Implant Timeline Card (if patient has implant treatment)
              Obx(() {
                final profile = patientController.myProfile.value;
                final hasImplant =
                    profile?.treatmentHistory?.contains(AppStrings.implant) ??
                    false;

                if (hasImplant) {
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Get.toNamed(AppRoutes.dentalImplantTimeline);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.only(
                            right: 4.w, // start from right edge
                            left: 20.w,
                            top: 20.w,
                            bottom: 20.w,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            textDirection: ui.TextDirection.rtl,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'مواعيد زراعة اسنانك',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'تابع مراحل زراعة الأسنان',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: AppColors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 70.w),
                              // Icon on the left
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  Icons.medical_services,
                                  color: AppColors.white,
                                  size: 28.sp,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              // Arrow at the far left
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppColors.white,
                                size: 20.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.appointments,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Get.toNamed(AppRoutes.patientAppointments);
                        },
                        child: Text(
                          AppStrings.viewAll,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.primary,
                        size: 20.sp,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Obx(() {
                final upcoming = appointmentController
                    .getUpcomingAppointments();
                final past = appointmentController.getPastAppointments();

                if (upcoming.isEmpty && past.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(24.w),
                    child: Center(
                      child: Text(
                        'لا توجد مواعيد',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }

                // Get all appointments and sort them
                final allAppointments = appointmentController.appointments
                    .toList();

                // Sort appointments by date (newest first)
                allAppointments.sort((a, b) {
                  final aDate = DateTime(a.date.year, a.date.month, a.date.day);
                  final bDate = DateTime(b.date.year, b.date.month, b.date.day);
                  final aTime = _parseTime(a.time);
                  final bTime = _parseTime(b.time);
                  final aDateTime = aDate.add(
                    Duration(hours: aTime.hour, minutes: aTime.minute),
                  );
                  final bDateTime = bDate.add(
                    Duration(hours: bTime.hour, minutes: bTime.minute),
                  );
                  return bDateTime.compareTo(aDateTime);
                });

                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                return Column(
                  children: [
                    if (allAppointments.isNotEmpty)
                      ...allAppointments.take(1).map((appointment) {
                        final appointmentDate = DateTime(
                          appointment.date.year,
                          appointment.date.month,
                          appointment.date.day,
                        );
                        final isPast = appointmentDate.isBefore(today);

                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _buildAppointmentCard(
                            appointment: appointment,
                            isPast: isPast,
                          ),
                        );
                      }),
                  ],
                );
              }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard({
    required AppointmentModel appointment,
    required bool isPast,
  }) {
    final patientController = Get.find<PatientController>();
    final doctorName = appointment.doctorName.isNotEmpty
        ? appointment.doctorName
        : (patientController.myDoctor.value?['name'] ?? 'طبيبك');

    // تنسيق التاريخ
    final dateFormat = DateFormat('dd-MM-yyyy', 'ar');
    final formattedDate = dateFormat.format(appointment.date);

    // أسماء الأيام بالعربية
    final weekDays = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final dayName = weekDays[appointment.date.weekday % 7];

    // تنسيق الوقت
    final timeParts = appointment.time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? timeParts[1] : '00';
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeText = '$displayHour:$minute';
    final periodText = isPM ? 'مساءاً' : 'صباحاً';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: isPast ? Colors.grey[200] : AppColors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Spacing where image was (to prevent text from sticking to edge)
              SizedBox(width: 4.w),
              // Line 1: Doctor name text
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.cairo(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: isPast
                            ? 'موعدك السابق مع الدكتور "'
                            : 'موعدك القادم مع الدكتور "',
                      ),
                      TextSpan(
                        text: doctorName,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary.withValues(alpha: 0.8),
                        ),
                      ),
                      const TextSpan(text: '" هو'),
                    ],
                  ),
                  textAlign: TextAlign.right,
                  textDirection: ui.TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(right: 10.w),
            // Appointment Details
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),
                // Line 2: Date row - "يوم الثلاثاء المصادف" + icon + date
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'يوم $dayName المصادف',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    SizedBox(width: 4.w),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.calendar_today,
                      size: 14.sp,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // Line 3: Time row - "في تمام الساعة" + blue button with time + period
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'في تمام الساعة',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      periodText,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: Text(
              'الرجاء الحضور قبل الموعد بنصف ساعة',
              textAlign: TextAlign.right,
              style: GoogleFonts.cairo(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const ui.Color.fromARGB(255, 71, 148, 184),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
