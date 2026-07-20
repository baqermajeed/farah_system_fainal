import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/controllers/edit_patient_profile_controller.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

class _EditProfileAssets {
  static const back = 'assets/icon/backblack.png';
}

/// شاشة تعديل الملف الشخصي للمريض — GetView؛ المنطق في EditPatientProfileController.
class EditPatientProfileScreen extends GetView<EditPatientProfileController> {
  const EditPatientProfileScreen({super.key});

  static const Color _bg = Color(0xFFF8FAFF);
  static const Color _navy = Color(0xFF1A3263);
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
                    children: [
                      _buildFormCard(
                        children: [
                          _buildField(
                            label: AppStrings.name,
                            icon: Icons.person_outline,
                            controller: controller.nameController,
                            hint: 'أدخل الاسم',
                          ),
                          _fieldDivider(),
                          _buildField(
                            label: AppStrings.phoneNumber,
                            icon: Icons.phone_outlined,
                            controller: controller.phoneController,
                            hint: '0000 000 0000',
                            readOnly: true,
                            suffix: Icon(
                              Icons.lock_outline,
                              size: 18.sp,
                              color: _grayText,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildFormCard(
                        children: [
                          _buildField(
                            label: AppStrings.age,
                            icon: Icons.calendar_month_outlined,
                            controller: controller.ageController,
                            hint: 'أدخل العمر',
                            keyboardType: TextInputType.number,
                          ),
                          _fieldDivider(),
                          _buildGenderSection(),
                          _fieldDivider(),
                          _buildCitySection(context),
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
          const BackButtonWidget(assetPath: _EditProfileAssets.back),
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
                  'حدّث بياناتك الشخصية',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 48.w),
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
    required TextEditingController controller,
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
              controller: controller,
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

  Widget _buildGenderSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wc_outlined, color: _navy, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  'الجنس',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _grayText,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Obx(() {
              final selectedGender = controller.selectedGender.value;
              return Row(
                children: [
                  Expanded(
                    child: _buildGenderChip(
                      label: AppStrings.male,
                      isSelected: selectedGender == AppStrings.male,
                      onTap: () => controller.setGender(AppStrings.male),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildGenderChip(
                      label: AppStrings.female,
                      isSelected: selectedGender == AppStrings.female,
                      onTap: () => controller.setGender(AppStrings.female),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? _navy : _bg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? _navy : _border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppFonts.lamaSans(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : _navy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCitySection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: _navy, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  AppStrings.governorate,
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _grayText,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showCityPicker(context),
                borderRadius: BorderRadius.circular(12.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Obx(() {
                    final selectedCity = controller.selectedCity.value;
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedCity ?? 'اختر المحافظة',
                            style: AppFonts.lamaSans(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: selectedCity != null ? _navy : _grayText,
                            ),
                          ),
                        ),
                        Container(
                          width: 32.w,
                          height: 32.w,
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _navy,
                            size: 20.sp,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCityPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(maxHeight: 0.72.sh),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12.h),
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
                  'اختر المحافظة',
                  style: AppFonts.lamaSans(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'حدد المحافظة التي تقيم فيها',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                  ),
                ),
                SizedBox(height: 16.h),
                Flexible(
                  child: Obx(() {
                    final selectedCity = controller.selectedCity.value;
                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                      shrinkWrap: true,
                      itemCount: controller.cities.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final city = controller.cities[index];
                        final isSelected = selectedCity == city;
                        return _buildCityOption(
                          city: city,
                          isSelected: isSelected,
                          onTap: () {
                            controller.setCity(city);
                            Navigator.pop(sheetContext);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCityOption({
    required String city,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: isSelected ? _navy : _bg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected ? _navy : _border,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _navy.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: isSelected ? Colors.white : _navy,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    city,
                    style: AppFonts.lamaSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : _navy,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26.w,
                  height: 26.w,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : _border,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check_rounded, color: _navy, size: 16.sp)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final isLoading = controller.isLoading;
    return GestureDetector(
      onTap: isLoading ? null : () => _saveProfile(context),
      child: AnimatedOpacity(
        opacity: isLoading ? 0.7 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            color: _navy,
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
    if (controller.nameController.text.isEmpty) {
      _showResultDialog(
        context,
        isSuccess: false,
        message: 'يرجى إدخال الاسم',
      );
      return;
    }

    try {
      await controller.saveProfile();

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
      Get.back();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (Get.context != null) {
          _showResultDialog(
            Get.context!,
            isSuccess: false,
            message: 'فشل حفظ التغييرات',
          );
        }
      });
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
      final url = '$validImageUrl?t=${controller.imageTimestamp.value}';
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
            errorWidget: (context, url, error) =>
                Icon(Icons.person, size: 48.sp, color: _grayText),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
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
}
