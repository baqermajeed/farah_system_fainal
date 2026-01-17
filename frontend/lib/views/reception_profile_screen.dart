import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/widgets/custom_button.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

class ReceptionProfileScreen extends StatefulWidget {
  const ReceptionProfileScreen({super.key});

  @override
  State<ReceptionProfileScreen> createState() => _ReceptionProfileScreenState();
}

class _ReceptionProfileScreenState extends State<ReceptionProfileScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isUploadingImage = false;
  int _imageTimestamp = DateTime.now().millisecondsSinceEpoch;

  Future<void> _pickAndUploadProfileImage() async {
    if (_isUploadingImage) return;

    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (xFile == null) return;

      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: xFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'تعديل الصورة',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'تعديل الصورة',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      await _authService.uploadProfileImage(File(croppedFile.path));
      await _authController.checkLoggedInUser(navigate: false);

      setState(() {
        _imageTimestamp = DateTime.now().millisecondsSinceEpoch;
      });

      Get.snackbar('تم', 'تم تحديث الصورة الشخصية بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفع الصورة: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = _authController;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    // Back button always on the LEFT
                    const BackButtonWidget(),
                    Expanded(
                      child: Center(
                        child: Text(
                          AppStrings.receptionProfile,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    // Empty space on the RIGHT to keep title centered
                    SizedBox(width: 40.w),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              // Profile Image
              GestureDetector(
                onTap: _pickAndUploadProfileImage,
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    Obx(() {
                      final user = authController.currentUser.value;
                      final validUrl = ImageUtils.convertToValidUrl(user?.imageUrl);
                      final hasImage = validUrl != null && ImageUtils.isValidImageUrl(validUrl);
                      final displayUrl =
                          hasImage ? '$validUrl?t=$_imageTimestamp' : null;

                      return CircleAvatar(
                        radius: 60.r,
                        backgroundColor: AppColors.primaryLight,
                        child: ClipOval(
                          child: hasImage
                              ? CachedNetworkImage(
                                  imageUrl: displayUrl!,
                                  width: 120.r,
                                  height: 120.r,
                                  fit: BoxFit.cover,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  memCacheWidth: 240,
                                  memCacheHeight: 240,
                                  placeholder: (context, url) => Container(
                                    color: AppColors.primaryLight,
                                    child: Center(
                                      child: _isUploadingImage
                                          ? const CircularProgressIndicator()
                                          : Icon(
                                              Icons.person,
                                              size: 60.sp,
                                              color: AppColors.white,
                                            ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.person,
                                    size: 60.sp,
                                    color: AppColors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 60.sp,
                                  color: AppColors.white,
                                ),
                        ),
                      );
                    }),
                    // Small edit badge
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: _isUploadingImage
                            ? SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                size: 16.sp,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              Obx(() {
                final user = authController.currentUser.value;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.divider,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          user?.name ?? 'موظف الاستقبال',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        AppStrings.receptionUsername,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.divider,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          user?.phoneNumber ?? 'reception_user',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        AppStrings.phoneNumber,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.divider,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          user?.phoneNumber ?? 'غير محدد',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        'المنصب',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.divider,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'موظف استقبال',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 32.h),
                      CustomButton(
                        text: 'تعديل الملف الشخصي',
                        onPressed: () {
                          Get.toNamed(AppRoutes.editReceptionProfile);
                        },
                        backgroundColor: AppColors.primary,
                        width: double.infinity,
                        icon: Icon(
                          Icons.edit,
                          color: AppColors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      CustomButton(
                        text: AppStrings.logout,
                        onPressed: () async {
                          await authController.logout();
                        },
                        backgroundColor: AppColors.error,
                        width: double.infinity,
                        icon: Icon(
                          Icons.exit_to_app,
                          color: AppColors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(height: 32.h),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
