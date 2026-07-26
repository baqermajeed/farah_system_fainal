import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/widgets/profile_cached_image.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_back_button.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/edit_doctor_profile_controller.dart';

/// شاشة تعديل الملف الشخصي للطبيب — GetView؛ المنطق في EditDoctorProfileController.
class EditDoctorProfileScreen extends GetView<EditDoctorProfileController> {
  const EditDoctorProfileScreen({super.key});

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _grayText = Color(0xFF8A97A8);
  static const Color _border = Color(0xFFE8ECF0);

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
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 32.h),
            child: Column(
              children: [
                _buildHeader(),
                SizedBox(height: 20.h),
                Obx(() => _buildProfileImage()),
                SizedBox(height: 8.h),
                Text(
                  'اضغط على الكاميرا لتغيير الصورة',
                  style: AppFonts.lamaSans(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                  ),
                ),
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionTitle(
                        'المعلومات الأساسية',
                        icon: Icons.person_outline_rounded,
                      ),
                      SizedBox(height: 10.h),
                      _buildFormCard(
                        children: [
                          _buildField(
                            label: AppStrings.name,
                            icon: Icons.badge_outlined,
                            fieldController: controller.nameController,
                            hint: 'أدخل الاسم الكامل',
                          ),
                          _fieldDivider(),
                          _buildField(
                            label: AppStrings.phoneNumber,
                            icon: Icons.phone_outlined,
                            fieldController: controller.phoneController,
                            hint: '07800000000',
                            readOnly: true,
                            suffix: Icon(
                              Icons.lock_outline,
                              size: 18.sp,
                              color: _grayText,
                            ),
                          ),
                          _fieldDivider(),
                          Obx(() {
                            final username = controller
                                    .authController.currentUser.value
                                    ?.username ??
                                '';
                            return _buildReadOnlyField(
                              label: 'اسم المستخدم',
                              icon: Icons.alternate_email_rounded,
                              value: username.trim().isNotEmpty
                                  ? username.trim()
                                  : 'غير محدد',
                              hint: 'يُستخدم لتسجيل الدخول',
                            );
                          }),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      _buildSectionTitle(
                        'المعلومات المهنية',
                        icon: Icons.medical_services_outlined,
                      ),
                      SizedBox(height: 10.h),
                      _buildFormCard(
                        children: [
                          _buildReadOnlyField(
                            label: 'المنصب',
                            icon: Icons.work_outline_rounded,
                            value: 'طبيب أسنان',
                          ),
                          _fieldDivider(),
                          _buildReadOnlyField(
                            label: 'التخصص',
                            icon: Icons.local_hospital_outlined,
                            value: 'طبيب أسنان عام',
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      Obx(() => _buildSaveButton(context)),
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

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          const DoctorBackButton(),
          Expanded(
            child: Column(
              children: [
                Text(
                  'تعديل الملف الشخصي',
                  style: AppFonts.lamaSans(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'حدّث بياناتك المهنية',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 50.w),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required IconData icon}) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: AppColors.doctorHeroStart.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: AppColors.doctorHeroStart, size: 17.sp),
          ),
          SizedBox(width: 10.w),
          Text(
            title,
            style: AppFonts.lamaSans(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _border),
        boxShadow: _softShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _fieldDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16.w,
      endIndent: 16.w,
      color: _border,
    );
  }

  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController fieldController,
    required String hint,
    TextInputType? keyboardType,
    bool readOnly = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _navy, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _grayText,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: fieldController,
              keyboardType: keyboardType,
              readOnly: readOnly,
              textAlign: TextAlign.right,
              style: AppFonts.lamaSans(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: readOnly ? _grayText : _navy,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppFonts.lamaSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: _grayText.withValues(alpha: 0.6),
                ),
                suffixIcon: suffix,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required IconData icon,
    required String value,
    String? hint,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _navy, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _grayText,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value.isNotEmpty ? value : 'غير محدد',
                    textAlign: TextAlign.right,
                    style: AppFonts.lamaSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ),
                if (hint != null) ...[
                  SizedBox(width: 8.w),
                  Icon(Icons.lock_outline, size: 16.sp, color: _grayText),
                ],
              ],
            ),
            if (hint != null) ...[
              SizedBox(height: 4.h),
              Text(
                hint,
                style: AppFonts.lamaSans(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: _grayText.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final isLoading = controller.isLoading.value;
    return GestureDetector(
      onTap: isLoading ? null : () => _saveProfile(context),
      child: AnimatedOpacity(
        opacity: isLoading ? 0.7 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.doctorHeroStart,
                AppColors.doctorHeroEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: _softShadow,
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'حفظ التغييرات',
                    style: AppFonts.lamaSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile(BuildContext context) async {
    if (controller.nameController.text.trim().isEmpty) {
      _showResultDialog(
        context,
        isSuccess: false,
        message: 'يرجى إدخال الاسم',
      );
      return;
    }

    try {
      await controller.saveChanges();

      Get.back();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (Get.context != null) {
          _showResultDialog(
            Get.context!,
            isSuccess: true,
            message: 'تم حفظ التغييرات بنجاح',
          );
        }
      });
    } catch (e) {
      _showResultDialog(
        context,
        isSuccess: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _showResultDialog(
    BuildContext context, {
    required bool isSuccess,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: (isSuccess
                            ? const Color(0xFF2EAF68)
                            : const Color(0xFFE25B5B))
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_rounded : Icons.close_rounded,
                    color: isSuccess
                        ? const Color(0xFF2EAF68)
                        : const Color(0xFFE25B5B),
                    size: 30.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  isSuccess ? 'تم الحفظ' : 'حدث خطأ',
                  style: AppFonts.lamaSans(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppFonts.lamaSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                  ),
                ),
                SizedBox(height: 20.h),
                GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        'حسناً',
                        style: AppFonts.lamaSans(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileImage() {
    final user = controller.authController.currentUser.value;
    final imageUrl = user?.imageUrl;
    final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);
    final hasImage =
        validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl);
    final isUploadingImage = controller.isUploadingImage.value;

    Widget avatar;
    if (hasImage) {
      avatar = ProfileCachedImage(
        imageUrl: imageUrl,
        size: 104.w,
        cacheVersion: controller.imageTimestamp.value,
        placeholder: _profilePlaceholder(),
        errorWidget: _profilePlaceholder(),
      );
    } else {
      avatar = _profilePlaceholder();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                AppColors.doctorHeroStart,
                AppColors.doctorHeroEnd,
              ],
            ),
          ),
          child: Container(
            width: 104.w,
            height: 104.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8ECF0),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatar,
          ),
        ),
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
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.doctorHeroStart,
                      AppColors.doctorHeroEnd,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
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

  Widget _profilePlaceholder() {
    return Icon(Icons.person_rounded, size: 48.sp, color: _grayText);
  }
}
