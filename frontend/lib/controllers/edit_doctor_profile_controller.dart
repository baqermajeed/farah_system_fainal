import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/core/utils/image_cropper_settings.dart';

/// Controller لشاشة تعديل الملف الشخصي للطبيب.
class EditDoctorProfileController extends GetxController {
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxBool isUploadingImage = false.obs;
  final RxInt imageTimestamp = RxInt(DateTime.now().millisecondsSinceEpoch);

  AuthController get authController => Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    loadCurrentData();
  }

  void loadCurrentData() {
    final user = authController.currentUser.value;
    nameController.text = user?.name ?? '';
    phoneController.text = user?.phoneNumber ?? '';
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  Future<void> pickAndUploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image == null) return;

      final croppedFile = await cropProfileImage(image.path);
      if (croppedFile == null) return;

      isUploadingImage.value = true;

      await _authService.uploadProfileImage(croppedFile);
      await authController.checkLoggedInUser(navigate: false);
      imageTimestamp.value = DateTime.now().millisecondsSinceEpoch;

      Get.snackbar(
        'نجح',
        'تم تحديث الصورة بنجاح',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: AppColors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل تحديث الصورة',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: AppColors.white,
        duration: const Duration(seconds: 2),
      );
    } finally {
      isUploadingImage.value = false;
    }
  }

  Future<void> saveChanges() async {
    if (nameController.text.trim().isEmpty) {
      throw Exception('يرجى إدخال الاسم');
    }

    isLoading.value = true;

    try {
      await _authService.updateProfile(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
      );

      await authController.checkLoggedInUser(navigate: false);
    } finally {
      isLoading.value = false;
    }
  }

  void showResultDialog({required bool isSuccess, required String message}) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 28.sp,
            ),
            SizedBox(width: 12.w),
            Text(
              isSuccess ? 'نجح' : 'فشل',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 16.sp, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'حسناً',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
