import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/controllers/patient_welcome_controller.dart';
import 'package:farah_sys_final/views/patient_browse_screen.dart';

/// شاشة انتظار تعيين الطبيب — تصميم تحريري قوي متناسق مع حساب المريض.
class PatientWelcomeScreen extends GetView<PatientWelcomeController> {
  const PatientWelcomeScreen({super.key});

  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _deepNavy = Color(0xFF0F2744);
  static const Color _accent = Color(0xFF5B9FCC);
  static const Color _grayText = Color(0xFF8A97A8);
  static const Color _surface = Color(0xFFF7F9FC);
  static const String _logoAsset = 'assets/images/Frame 2609217.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      textTheme: AppFonts.textTheme(Theme.of(context).textTheme),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _surface,
        body: Column(
          children: [
            _buildHeroPanel(context),
            Expanded(child: _buildLowerSheet()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPanel(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(32.r),
        bottomRight: Radius.circular(32.r),
      ),
      child: SizedBox(
        height: 340.h + topPad * 0.35,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/icon/ChatGPT Image Jul 11, 2026, 06_28_08 PM.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _deepNavy.withValues(alpha: 0.92),
                    _navy.withValues(alpha: 0.88),
                    _accent.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -40.h,
              left: -30.w,
              child: Container(
                width: 160.w,
                height: 160.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: 0.22),
                ),
              ),
            ),
            Positioned(
              bottom: 40.h,
              right: -50.w,
              child: Container(
                width: 140.w,
                height: 140.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 28.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(context),
                    const Spacer(),
                    Directionality(
                      textDirection: ui.TextDirection.rtl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              'عيادة فرح لطب الأسنان',
                              style: AppFonts.lamaSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.92),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Obx(() {
                            final profileName = controller
                                .patientController.myProfile.value?.name;
                            final userName = controller
                                .authController.currentUser.value?.name;
                            final displayName =
                                profileName ?? userName ?? 'المريض';

                            return Text(
                              'مرحباً،\n$displayName',
                              textAlign: TextAlign.right,
                              style: AppFonts.lamaSans(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            );
                          }),
                          SizedBox(height: 10.h),
                          Text(
                            'يرجى القدوم إلى العيادة لتعيين طبيب مختص لك وبدء رحلتك العلاجية.',
                            textAlign: TextAlign.right,
                            style: AppFonts.lamaSans(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.45,
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
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      textDirection: ui.TextDirection.ltr,
      children: [
        Image.asset(
          _logoAsset,
          width: 72.w,
          height: 72.w,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        Obx(() {
          final loading = controller.authController.isLoading.value;
          final isFamily = controller.isFamilyAccount.value;
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            elevation: 0,
            child: InkWell(
              onTap: loading
                  ? null
                  : () {
                      if (isFamily) {
                        _showSettingsSheet(context);
                      } else {
                        controller.confirmLogout();
                      }
                    },
              borderRadius: BorderRadius.circular(16.r),
              child: SizedBox(
                width: 46.w,
                height: 46.w,
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          isFamily
                              ? Icons.settings_outlined
                              : Icons.logout_rounded,
                          size: 20.sp,
                          color: _navy,
                        ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final authController = controller.authController;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DEE8),
                      borderRadius: BorderRadius.circular(99.r),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'الإعدادات',
                    style: AppFonts.lamaSans(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'تبديل الفرد أو تسجيل الخروج',
                    style: AppFonts.lamaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: _grayText,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  _buildSettingsOption(
                    icon: Icons.switch_account_rounded,
                    iconColor: _navy,
                    iconBg: _surface,
                    title: 'تبديل فرد العائلة',
                    subtitle: 'التبديل بين أفراد العائلة المسجلين',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      authController.switchFamilyMember();
                    },
                  ),
                  SizedBox(height: 10.h),
                  _buildSettingsOption(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFE25B5B),
                    iconBg: const Color(0xFFFFEEEE),
                    title: AppStrings.logout,
                    subtitle: 'الخروج من الحساب الحالي',
                    titleColor: const Color(0xFFE25B5B),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await controller.confirmLogout();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Ink(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE8ECF0)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            child: Row(
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, color: iconColor, size: 22.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.lamaSans(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: titleColor ?? _navy,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        subtitle,
                        style: AppFonts.lamaSans(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                          color: _grayText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14.sp,
                  color: _grayText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLowerSheet() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusBlock(),
          SizedBox(height: 22.h),
          _buildJourneySteps(),
          SizedBox(height: 26.h),
          _buildBrowseCard(),
        ],
      ),
    );
  }

  Widget _buildStatusBlock() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.warning,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بانتظار تعيين الطبيب',
                  style: AppFonts.lamaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'عند حضورك للعيادة، سيقوم موظف الاستقبال بتعيين طبيب مختص لك، وسننقلك تلقائياً إلى حسابك العلاجي.',
                  style: AppFonts.lamaSans(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneySteps() {
    final steps = [
      (Icons.check_rounded, 'تم إنشاء الحساب', true, true),
      (Icons.person_search_rounded, 'تعيين الطبيب', true, false),
      (Icons.medical_services_outlined, 'بدء الرحلة العلاجية', false, false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مسار رحلتك',
          style: AppFonts.lamaSans(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
        SizedBox(height: 14.h),
        ...List.generate(steps.length, (i) {
          final step = steps[i];
          final isLast = i == steps.length - 1;
          return _JourneyStep(
            icon: step.$1,
            title: step.$2,
            isActive: step.$3,
            isDone: step.$4,
            showLine: !isLast,
          );
        }),
      ],
    );
  }

  Widget _buildBrowseCard() {
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _navy,
            const Color(0xFF2A5080),
            _accent.withValues(alpha: 0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'استغل وقت الانتظار',
                      style: AppFonts.lamaSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'معلومات طبية مختصرة عن صحة الأسنان',
                      style: AppFonts.lamaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 50.h,
            child: ElevatedButton(
              onPressed: () => Get.to(() => const PatientBrowseScreen()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _navy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'تصفح الآن',
                    style: AppFonts.lamaSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Transform.rotate(
                    angle: math.pi,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 18.sp,
                      color: _navy,
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
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.isDone,
    required this.showLine,
  });

  final IconData icon;
  final String title;
  final bool isActive;
  final bool isDone;
  final bool showLine;

  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _accent = Color(0xFF5B9FCC);
  static const Color _grayText = Color(0xFF8A97A8);

  @override
  Widget build(BuildContext context) {
    final Color circleColor = isDone
        ? AppColors.success
        : isActive
            ? _accent
            : const Color(0xFFE8ECF0);
    final Color iconColor =
        (isDone || isActive) ? Colors.white : _grayText;
    final Color titleColor = isActive || isDone ? _navy : _grayText;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36.w,
            child: Column(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    boxShadow: isActive && !isDone
                        ? [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(icon, size: 18.sp, color: iconColor),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 4.h),
                      color: isDone
                          ? AppColors.success.withValues(alpha: 0.35)
                          : const Color(0xFFE8ECF0),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 7.h, bottom: showLine ? 18.h : 0),
              child: Text(
                title,
                style: AppFonts.lamaSans(
                  fontSize: 13.5.sp,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: titleColor,
                ),
              ),
            ),
          ),
          if (isActive && !isDone)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'الآن',
                  style: AppFonts.lamaSans(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
