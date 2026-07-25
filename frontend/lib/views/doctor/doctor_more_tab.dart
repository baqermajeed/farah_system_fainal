import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_glass_card.dart';

class DoctorMoreTab extends StatelessWidget {
  const DoctorMoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return ColoredBox(
      color: AppColors.doctorSurface,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 100.h),
        children: [
          Text(
            'المزيد',
            style: AppFonts.lamaSans(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 20.h),
          Obx(() {
            final user = authController.currentUser.value;
            final validUrl = ImageUtils.convertToValidUrl(user?.imageUrl);
            return DoctorGlassCard(
              onTap: () => Get.toNamed(AppRoutes.doctorProfile),
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.doctorNavInactive,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          user?.name ?? 'الطبيب',
                          style: AppFonts.lamaSans(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          user?.phoneNumber ?? '',
                          style: AppFonts.lamaSans(
                            fontSize: 13.sp,
                            color: AppColors.doctorLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: ClipOval(
                      child: validUrl != null &&
                              ImageUtils.isValidImageUrl(validUrl)
                          ? CachedNetworkImage(
                              imageUrl: validUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _fallbackAvatar(),
                            )
                          : _fallbackAvatar(),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 20.h),
          _MenuTile(
            icon: Icons.person_outline_rounded,
            title: 'الملف الشخصي',
            subtitle: 'تعديل بياناتك وصورتك',
            onTap: () => Get.toNamed(AppRoutes.doctorProfile),
          ),
          _MenuTile(
            icon: Icons.schedule_rounded,
            title: 'ساعات العمل',
            subtitle: 'إدارة أوقات استقبالك',
            onTap: () => Get.toNamed(AppRoutes.workingHours),
          ),
          _MenuTile(
            icon: Icons.people_alt_rounded,
            title: 'جميع المرضى',
            subtitle: 'قائمة المرضى الكاملة',
            onTap: () => Get.toNamed(AppRoutes.doctorPatientsList),
          ),
          _MenuTile(
            icon: Icons.qr_code_scanner_rounded,
            title: 'مسح QR',
            subtitle: 'فتح ملف مريض بالباركود',
            onTap: () => Get.toNamed(AppRoutes.qrScanner),
          ),
          _MenuTile(
            icon: Icons.notifications_none_rounded,
            title: 'الإشعارات',
            subtitle: 'عرض التنبيهات',
            onTap: () => Get.toNamed(AppRoutes.notifications),
          ),
          SizedBox(height: 12.h),
          _MenuTile(
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            subtitle: 'الخروج من الحساب',
            iconColor: AppColors.error,
            onTap: () => authController.logout(),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: AppColors.primary,
      child: Icon(Icons.person, color: AppColors.white, size: 28.sp),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return DoctorGlassCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      margin: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(Icons.chevron_left_rounded, color: AppColors.doctorNavInactive),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  title,
                  style: AppFonts.lamaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    color: AppColors.doctorLabel,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 22.sp),
          ),
        ],
      ),
    );
  }
}
