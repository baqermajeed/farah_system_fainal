import 'dart:math' show pi;
import 'dart:ui' as ui;

import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_back_button.dart';
import 'package:farah_sys_final/controllers/doctor_profile_controller.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// شاشة الملف الشخصي للطبيب — GetView؛ المنطق في DoctorProfileController.
class DoctorProfileScreen extends GetView<DoctorProfileController> {
  const DoctorProfileScreen({super.key});

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _grayText = Color(0xFF8A97A8);

  static List<BoxShadow> get _softShadow => [
        BoxShadow(
          color: const Color(0xFF64748B).withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          final user = controller.authController.currentUser.value;
          final name = user?.name ?? 'دكتور';
          final displayName =
              name.startsWith('د.') ? name : 'د. $name';
          final phone = user?.phoneNumber ?? 'غير محدد';
          final username = _displayUsername(user?.username);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 24.h),
            child: Column(
              children: [
                _buildTopBar(),
                SizedBox(height: 20.h),
                _buildProfileImage(),
                SizedBox(height: 14.h),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: AppFonts.lamaSans(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                SizedBox(height: 8.h),
                _buildRoleBadge(),
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    children: [
                      _buildContactCard(
                        name: name,
                        phone: phone,
                        username: username,
                      ),
                      SizedBox(height: 12.h),
                      Directionality(
                        textDirection: ui.TextDirection.rtl,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildInfoTile(
                                icon: Icons.work_outline_rounded,
                                iconColor: AppColors.doctorAccentPurple,
                                iconBg: const Color(0xFFF3EEFF),
                                label: 'المنصب',
                                value: 'طبيب أسنان',
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildInfoTile(
                                icon: Icons.medical_services_outlined,
                                iconColor: AppColors.doctorAccentGreen,
                                iconBg: const Color(0xFFE8FAF0),
                                label: 'التخصص',
                                value: 'طبيب أسنان عام',
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _buildActionsSection(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          const DoctorBackButton(),
          Expanded(
            child: Center(
              child: Text(
                'الملف الشخصي',
                style: AppFonts.lamaSans(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            ),
          ),
          SizedBox(width: 50.w),
        ],
      ),
    );
  }

  Widget _buildRoleBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.doctorHeroStart.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.doctorHeroStart.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            color: AppColors.doctorHeroStart,
            size: 16.sp,
          ),
          SizedBox(width: 6.w),
          Text(
            'طبيب معتمد',
            style: AppFonts.lamaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.doctorHeroStart,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    final user = controller.authController.currentUser.value;
    final imageUrl = user?.imageUrl;
    final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);
    final isUploadingImage = controller.isUploadingImage.value;
    final imageTimestamp = controller.imageTimestamp.value;

    Widget avatarChild;
    if (validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl)) {
      final imageUrlWithTimestamp = '$validImageUrl?t=$imageTimestamp';
      avatarChild = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrlWithTimestamp,
          fit: BoxFit.cover,
          width: 104.w,
          height: 104.w,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) =>
              Container(color: const Color(0xFFE8ECF0)),
          errorWidget: (context, url, error) => Icon(
            Icons.person_rounded,
            size: 48.sp,
            color: _grayText,
          ),
          memCacheWidth: 240,
          memCacheHeight: 240,
        ),
      );
    } else {
      avatarChild = Icon(
        Icons.person_rounded,
        size: 48.sp,
        color: _grayText,
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 116.w,
          height: 116.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.doctorHeroStart,
                AppColors.doctorHeroEnd,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.doctorHeroStart.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.all(4.w),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: EdgeInsets.all(3.w),
            child: CircleAvatar(
              radius: 52.r,
              backgroundColor: const Color(0xFFE8ECF0),
              child: avatarChild,
            ),
          ),
        ),
        if (isUploadingImage)
          SizedBox(
            width: 104.w,
            height: 104.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.doctorHeroStart,
            ),
          ),
        if (!isUploadingImage)
          Positioned(
            bottom: 2.h,
            right: 2.w,
            child: GestureDetector(
              onTap: controller.pickAndUploadImage,
              child: Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.doctorHeroStart,
                      AppColors.doctorHeroEnd,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 17.sp,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContactCard({
    required String name,
    required String phone,
    required String username,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          _buildContactRow(
            icon: Icons.person_outline_rounded,
            label: AppStrings.name,
            value: name,
          ),
          _divider(),
          _buildContactRow(
            icon: Icons.alternate_email_rounded,
            label: 'اسم المستخدم',
            value: username,
          ),
          _divider(),
          _buildContactRow(
            icon: Icons.phone_outlined,
            label: AppStrings.phoneNumber,
            value: phone,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: Colors.white, size: 17.sp),
            ),
            SizedBox(width: 12.w),
            Text(
              label,
              style: AppFonts.lamaSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.lamaSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: _softShadow,
      ),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: iconColor, size: 20.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              label,
              style: AppFonts.lamaSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: _grayText,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.lamaSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: _navy,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.edit_outlined,
          iconColor: _navy,
          iconBg: _bg,
          title: 'تعديل الملف الشخصي',
          subtitle: 'تحديث الاسم ورقم الهاتف',
          onTap: () => Get.toNamed(AppRoutes.editDoctorProfile),
        ),
        SizedBox(height: 10.h),
        _buildActionTile(
          icon: Icons.access_time_rounded,
          iconColor: AppColors.doctorAccentOrange,
          iconBg: const Color(0xFFFFF4E5),
          title: 'أوقات العمل',
          subtitle: 'إدارة جدول المواعيد الأسبوعي',
          onTap: () => Get.toNamed(AppRoutes.workingHours),
        ),
        SizedBox(height: 10.h),
        _buildActionTile(
          icon: Icons.logout_rounded,
          iconColor: AppColors.error,
          iconBg: const Color(0xFFFFEEEE),
          title: AppStrings.logout,
          subtitle: 'الخروج من الحساب الحالي',
          titleColor: AppColors.error,
          onTap: () => controller.logout(),
        ),
      ],
    );
  }

  Widget _buildActionTile({
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: _softShadow,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            child: Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14.r),
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
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: _grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.rotate(
                    angle: pi,
                    child: Icon(
                      Icons.chevron_left,
                      color: _grayText.withValues(alpha: 0.7),
                      size: 22.sp,
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

  String _displayUsername(String? username) {
    final value = username?.trim();
    if (value != null && value.isNotEmpty) return value;
    return 'غير محدد';
  }
}
