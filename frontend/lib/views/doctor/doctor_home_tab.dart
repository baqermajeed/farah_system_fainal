import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/doctor_home_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/widgets/app_avatar.dart';

class DoctorHomeTab extends GetView<DoctorHomeController> {
  const DoctorHomeTab({super.key});

  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _grayText = Color(0xFF8A97A8);
  static const Color _bgColor = Color(0xFFF8FAFC); // خلفية عصرية جداً فاتحة
  static const String _notificationIconAsset =
      'assets/icon/Frame 2609203.png';
  static const String _barcodeIconAsset = 'assets/icon/Frame 2609218.png';
  static const Color _headerIconColor = Color(0xFF5A7C99);

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _bgColor,
      ),
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            color: _navy,
            displacement: 40,
            onRefresh: controller.refreshDashboard,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(authController),
                      SizedBox(height: 8.h), // تقليل المسافة
                      _buildStatsCard(),
                      SizedBox(height: 20.h), // تقليل المسافة
                      _buildQuickActions(),
                      SizedBox(height: 24.h), // تقليل المسافة
                      Obx(() {
                        if (controller.recentPatients.isEmpty) return const SizedBox.shrink();
                        return Column(
                          children: [
                            _buildSectionTitle('أحدث المرضى'),
                            SizedBox(height: 6.h), // تم تقليل المسافة بين العنوان والكونتينرات
                            _buildRecentPatients(),
                            SizedBox(height: 24.h), // تقليل المسافة
                          ],
                        );
                      }),
                      _buildSectionTitle(
                        'مواعيد اليوم',
                        onSeeAll: () => Get.toNamed(AppRoutes.appointments),
                      ),
                      SizedBox(height: 12.h), // تقليل المسافة
                      _buildTodaySchedule(),
                      SizedBox(height: 80.h), // تقليل مساحة الـ bottom padding
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AuthController authController) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Row(
          children: [
            Obx(() {
              final user = authController.currentUser.value;
              final imageUrl = ImageUtils.convertToValidUrl(user?.imageUrl);
              return GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.doctorProfile),
                child: Container(
                  width: 54.w,
                  height: 54.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  padding: EdgeInsets.all(2.w),
                  child: AppAvatar(
                    imageUrl: imageUrl,
                    size: 50.w,
                    cornerRadius: 25.w,
                  ),
                ),
              );
            }),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.greeting,
                    style: AppFonts.lamaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: _grayText,
                    ),
                  ),
                  Obx(() {
                    final user = authController.currentUser.value;
                    final name = user?.name ?? 'دكتور';
                    final displayName = name.startsWith('د.') ? name : 'د. $name';
                    return Text(
                      displayName,
                      style: AppFonts.lamaSans(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    );
                  }),
                ],
              ),
            ),
            _headerIconButton(
              assetPath: _barcodeIconAsset,
              assetWidth: 26.w,
              assetHeight: 26.w,
              onTap: () => Get.toNamed(AppRoutes.qrScanner),
            ),
            SizedBox(width: 10.w),
            Obx(() {
              final unread = controller.unreadCounts.values.fold<int>(0, (s, c) => s + c);
              return _headerIconButton(
                assetPath: _notificationIconAsset,
                assetWidth: 26.w,
                assetHeight: 31.w,
                onTap: () => Get.toNamed(AppRoutes.notifications),
                hasBadge: unread > 0,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _headerIconButton({
    String? assetPath,
    double? assetWidth,
    double? assetHeight,
    IconData? icon,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    assert(assetPath != null || icon != null);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: Offset.zero,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: assetPath != null
                ? Image.asset(
                    assetPath,
                    width: assetWidth ?? 22.w,
                    height: assetHeight ?? 26.w,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    icon,
                    color: _headerIconColor,
                    size: 24.sp,
                  ),
          ),
          if (hasBadge)
            Positioned(
              top: 2.h,
              right: 2.w,
              child: Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF162D4A), Color(0xFF4A88B8)], // تدرج راقي ومريح
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A88B8).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // تأثيرات زجاجية خلفية عصرية
          Positioned(
            right: -20.w,
            top: -20.h,
            child: Container(
              width: 140.w,
              height: 140.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            left: -40.w,
            bottom: -40.h,
            child: Container(
              width: 180.w,
              height: 180.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // المحتوى
          Padding(
            padding: EdgeInsets.all(28.w),
            child: Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملخص اليوم',
                          style: AppFonts.lamaSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Obx(
                          () => Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${controller.todayAppointmentsCount.value}',
                                style: AppFonts.lamaSans(
                                  fontSize: 48.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'مواعيد مجدولة',
                                style: AppFonts.lamaSans(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),
                        GestureDetector(
                          onTap: () => Get.toNamed(AppRoutes.appointments),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(24.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'الذهاب للجدول',
                                  style: AppFonts.lamaSans(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                RotatedBox(
                                  quarterTurns: 2,
                                  child: Icon(
                                    Icons.arrow_back_rounded, // 180deg flipped
                                    color: Colors.white,
                                    size: 16.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.medical_information_rounded,
                      color: Colors.white,
                      size: 34.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'label': 'المرضى',
        'icon': Icons.people_alt_rounded,
        'route': AppRoutes.doctorPatientsList,
        'color': const Color(0xFF5B9FCC) // أزرق
      },
      {
        'label': 'المحادثات',
        'icon': Icons.chat_bubble_outline_rounded,
        'action': controller.openChatsAndRefresh,
        'color': const Color(0xFF8B5CF6) // بنفسجي
      },
      {
        'label': 'الإشعارات',
        'icon': Icons.notifications_none_rounded,
        'route': AppRoutes.notifications,
        'color': const Color(0xFFFF9500) // برتقالي
      },
      {
        'label': 'الإحصائيات',
        'icon': Icons.bar_chart_rounded,
        'route': AppRoutes.doctorStats,
        'color': const Color(0xFFE74C3C) // أحمر
      },
      {
        'label': 'المواعيد',
        'icon': Icons.calendar_month_rounded,
        'route': AppRoutes.appointments,
        'color': const Color(0xFF27AE60) // أخضر
      },
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.05), // ظل كحلي فخم وناعم
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(actions.length, (index) {
              final action = actions[index];
              final color = action['color'] as Color;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (action['route'] != null) {
                      Get.toNamed(action['route'] as String);
                    } else if (action['action'] != null) {
                      ((action['action'] as VoidCallback))();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08), // خلفية شفافة من نفس لون الأيقونة
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          color: color,
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        action['label'] as String,
                        style: AppFonts.lamaSans(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppFonts.lamaSans(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  'الكل',
                  style: AppFonts.lamaSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPatients() {
    // تصميم إبداعي راقي (Premium Overlapping Avatar Cards)
    return SizedBox(
      height: 170.h,
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          itemCount: controller.recentPatients.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w), // تم تقليل الـ w (المسافة الأفقية) بين الكونتينرات هنا
          itemBuilder: (_, index) {
            final patient = controller.recentPatients[index];
            return GestureDetector(
              onTap: () => controller.openPatient(patient),
              child: SizedBox(
                width: 125.w,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // الكرت الأساسي الأبيض
                    Positioned(
                      top: 32.h,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A5F).withValues(alpha: 0.06), // ظل كحلي راقي وفخم
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                              child: Text(
                                patient.name.split(' ').take(2).join(' '),
                                style: AppFonts.lamaSans(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'مريض',
                              style: AppFonts.lamaSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: _grayText,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            // الزر المدمج أسفل الكرت
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC), // لون رمادي مزرق فاتح جداً
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(24.r),
                                  bottomRight: Radius.circular(24.r),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'الملف الطبي',
                                    style: AppFonts.lamaSans(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Transform.rotate(
                                    angle: 3.14159, // قلب السهم 180 درجة
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      size: 14.sp,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // الصورة البارزة (Overlapping Avatar)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(4.w), // إطار أبيض حول الصورة
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryLight.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: AppAvatar(
                          imageUrl: patient.imageUrl,
                          size: 56.w,
                          cornerRadius: 28.w,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTodaySchedule() {
    return Obx(() {
      if (controller.isLoadingAppointments.value && controller.todayAppointments.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.h),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      if (controller.todayAppointments.isEmpty) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.symmetric(vertical: 40.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  color: _grayText.withValues(alpha: 0.2),
                  size: 56.sp,
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا توجد مواعيد اليوم',
                  style: AppFonts.lamaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: _grayText,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          children: controller.todayAppointments
              .take(5)
              .map((appt) => _buildScheduleItem(appt))
              .toList(),
        ),
      );
    });
  }

  Widget _buildScheduleItem(AppointmentModel appointment) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24.r),
        child: InkWell(
          onTap: () => controller.openAppointmentPatient(appointment),
          borderRadius: BorderRadius.circular(24.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Row(
                children: [
                  // شارة الوقت (Time Badge) المودرن
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      appointment.time,
                      style: AppFonts.lamaSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // معلومات المريض
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName,
                          style: AppFonts.lamaSans(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          appointment.stageName ?? appointment.notes ?? 'متابعة حالة المريض',
                          style: AppFonts.lamaSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _grayText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // أيقونة الدخول
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF1F5F9), // Gray 100
                    ),
                    child: Transform.rotate(
                      angle: 3.14159, // قلب السهم 180 درجة (Pi radians)
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: _navy,
                        size: 20.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
