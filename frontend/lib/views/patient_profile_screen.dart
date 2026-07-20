import 'dart:math' show pi;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/patient_profile_controller.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

class _ProfileAssets {
  static const back = 'assets/icon/backblack.png';
}

/// شاشة الملف الشخصي للمريض — GetView؛ المنطق في PatientProfileController.
class PatientProfileScreen extends GetView<PatientProfileController> {
  const PatientProfileScreen({super.key});

  static const Color _bg = Color(0xFFF8FAFF);
  static const Color _navy = Color(0xFF1A3263);
  static const Color _grayText = Color(0xFF8A97A8);
  static const double _headerBoxSize = 50;
  static const double _headerBoxRadius = 16;

  static List<BoxShadow> get _softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
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
                    'إدارة حسابك وخيارات التطبيق',
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
                    iconBg: _bg,
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
                      await authController.logout();
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
            color: _bg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE8ECF0)),
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

  @override
  Widget build(BuildContext context) {
    final authController = controller.authController;
    final patientController = controller.patientController;

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
          child: Obx(() {
            if (patientController.isLoading.value &&
                patientController.myProfile.value == null) {
              return const LoadingWidget(message: 'جاري تحميل البيانات...');
            }

            final profile = patientController.myProfile.value;
            final user = authController.currentUser.value;
            final doctor = patientController.myDoctor.value;

            final name = profile?.name ?? user?.name ?? 'غير محدد';
            final phone =
                user?.phoneNumber ?? profile?.phoneNumber ?? 'غير محدد';
            final city = profile?.city ?? user?.city ?? 'غير محدد';
            final gender = _formatGender(profile?.gender ?? user?.gender);
            final age = profile?.age ?? user?.age ?? 0;
            final doctorName = doctor?['name']?.toString();
            final subtitle = doctorName != null && doctorName.isNotEmpty
                ? 'مريض لدى د. $doctorName'
                : 'مريض في عيادة فرح للأسنان';

            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 24.h),
              child: Column(
                children: [
                  _buildTopBar(context),
                  SizedBox(height: 20.h),
                  _buildProfileAvatar(profile?.imageUrl ?? user?.imageUrl),
                  SizedBox(height: 16.h),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: AppFonts.lamaSans(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppFonts.lamaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: _grayText,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: [
                        _buildContactCard(
                          phone: phone,
                          email: 'غير محدد',
                          location: city,
                        ),
                        SizedBox(height: 12.h),
                        Directionality(
                          textDirection: ui.TextDirection.rtl,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.calendar_month_outlined,
                                  label: AppStrings.age,
                                  value: age > 0 ? '$age سنة' : 'غير محدد',
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.person_outline,
                                  label: 'الجنس',
                                  value: gender,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        _buildEditButton(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const BackButtonWidget(assetPath: _ProfileAssets.back),
          GestureDetector(
            onTap: () => _showSettingsSheet(context),
            child: Container(
              width: _headerBoxSize.w,
              height: _headerBoxSize.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_headerBoxRadius.r),
                boxShadow: _headerShadow,
              ),
              child: Icon(
                Icons.settings_outlined,
                color: _navy,
                size: 24.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(String? imageUrl) {
    final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);
    final hasImage =
        validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl);
    final isUploadingImage = controller.isUploadingImage.value;
    final imageTimestamp = controller.imageTimestamp.value;

    Widget avatar;
    if (hasImage) {
      final url = '$validImageUrl?t=$imageTimestamp';
      avatar = CircleAvatar(
        radius: 52.r,
        backgroundColor: const Color(0xFFE8ECF0),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: 104.w,
            height: 104.w,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) =>
                Container(color: const Color(0xFFE8ECF0)),
            errorWidget: (context, url, error) => Icon(
              Icons.person,
              size: 48.sp,
              color: _grayText,
            ),
            memCacheWidth: 220,
            memCacheHeight: 220,
          ),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: 52.r,
        backgroundColor: const Color(0xFFE8ECF0),
        child: Icon(Icons.person, size: 48.sp, color: _grayText),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        avatar,
        if (isUploadingImage)
          SizedBox(
            width: 104.w,
            height: 104.w,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        if (!isUploadingImage)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: controller.pickAndUploadImage,
              child: Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: _headerShadow,
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: _navy,
                  size: 18.sp,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContactCard({
    required String phone,
    required String email,
    required String location,
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
            icon: Icons.phone_outlined,
            label: AppStrings.phoneNumber,
            value: phone,
          ),
          _divider(),
          _buildContactRow(
            icon: Icons.email_outlined,
            label: 'البريد الإلكتروني',
            value: email,
          ),
          _divider(),
          _buildContactRow(
            icon: Icons.location_on_outlined,
            label: 'الموقع',
            value: location,
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
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Row(
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, color: Colors.white, size: 16.sp),
            ),
            SizedBox(width: 12.w),
            Text(
              label,
              style: AppFonts.lamaSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.75),
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

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: _softShadow,
      ),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: _navy, size: 20.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    style: AppFonts.lamaSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: () async {
        await Get.toNamed(AppRoutes.editPatientProfile);
        controller.loadData();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: _softShadow,
        ),
        child: Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: _navy, size: 22.sp),
              SizedBox(width: 10.w),
              Text(
                'تعديل الملف الشخصي',
                style: AppFonts.lamaSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const Spacer(),
              Transform.rotate(
                angle: pi,
                child: Icon(Icons.chevron_left, color: _grayText, size: 24.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatGender(String? gender) {
    if (gender == null || gender.isEmpty) return 'غير محدد';
    final normalized = gender.toLowerCase();
    if (normalized == 'male' || normalized == 'ذكر' || normalized == 'm') {
      return 'ذكر';
    }
    if (normalized == 'female' || normalized == 'أنثى' || normalized == 'f') {
      return 'أنثى';
    }
    return gender;
  }
}
