import 'dart:io';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/widgets/custom_button.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  int _imageTimestamp = DateTime.now().millisecondsSinceEpoch;

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
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

      final imageFile = File(croppedFile.path);
      await _authService.uploadProfileImage(imageFile);

      // تحديث معلومات المستخدم
      await _authController.checkLoggedInUser(navigate: false);

      // إجبار تحديث الواجهة مع timestamp جديد لإعادة تحميل الصورة
      if (mounted) {
        setState(() {
          _imageTimestamp = DateTime.now().millisecondsSinceEpoch;
        });

        Get.snackbar(
          'نجح',
          'تم تحديث الصورة بنجاح',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: AppColors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'خطأ',
          'فشل تحديث الصورة: ${e.toString()}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: AppColors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Widget _buildProfileImage() {
    final user = _authController.currentUser.value;
    final imageUrl = user?.imageUrl;
    final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);

    if (validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl)) {
      // إضافة timestamp لإجبار إعادة التحميل عند التحديث
      final imageUrlWithTimestamp = '$validImageUrl?t=$_imageTimestamp';

      return Stack(
        children: [
          CircleAvatar(
            radius: 60.r,
            backgroundColor: AppColors.primaryLight,
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrlWithTimestamp,
                fit: BoxFit.cover, // Changed from contain to cover
                width: 120.w,
                height: 120.w,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (context, url) =>
                    Container(color: AppColors.primaryLight),
                errorWidget: (context, url, error) =>
                    Icon(Icons.person, size: 60.sp, color: AppColors.white),
                memCacheWidth: 240,
                memCacheHeight: 240,
              ),
            ),
          ),
          if (!_isUploadingImage)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickAndUploadImage,
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: AppColors.white,
                    size: 20.sp,
                  ),
                ),
              ),
            ),
          if (_isUploadingImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'جاري التحميل...',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 60.r,
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.person, size: 60.sp, color: AppColors.white),
        ),
        if (!_isUploadingImage)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickAndUploadImage,
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: AppColors.white,
                  size: 20.sp,
                ),
              ),
            ),
          ),
        if (_isUploadingImage)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.white,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'جاري التحميل...',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          'الملف الشخصي',
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
              Obx(() => _buildProfileImage()),
              SizedBox(height: 32.h),
              Obx(() {
                final user = _authController.currentUser.value;

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
                          user?.name ?? 'دكتور',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        'اسم المستخدم',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
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
                          user?.phoneNumber ?? 'doctor_user',
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
                          'طبيب أسنان',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        'التخصص',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
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
                          'طبيب أسنان عام',
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
                          Get.toNamed(AppRoutes.editDoctorProfile);
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
                        text: 'أوقات العمل',
                        onPressed: () {
                          Get.toNamed(AppRoutes.workingHours);
                        },
                        backgroundColor: AppColors.primary.withOpacity(0.8),
                        width: double.infinity,
                        icon: Icon(
                          Icons.access_time,
                          color: AppColors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      CustomButton(
                        text: AppStrings.logout,
                        onPressed: () async {
                          await _authController.logout();
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
