import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/core/utils/image_cropper_settings.dart';

/// Controller لشاشة الملف الشخصي للطبيب — المنطق والحالة خارج الـ View.
class DoctorProfileController extends GetxController {
  AuthController get authController => Get.find<AuthController>();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  final RxBool isUploadingImage = false.obs;
  final RxInt imageTimestamp = RxInt(DateTime.now().millisecondsSinceEpoch);

  Future<void> pickAndUploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
        uiSettings: appImageCropperUiSettings(),
      );

      if (croppedFile == null) return;

      isUploadingImage.value = true;

      final imageFile = File(croppedFile.path);
      await _authService.uploadProfileImage(imageFile);

      // تحديث معلومات المستخدم
      await authController.checkLoggedInUser(navigate: false);

      // إجبار تحديث الواجهة مع timestamp جديد لإعادة تحميل الصورة
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
        'فشل تحديث الصورة: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: AppColors.white,
        duration: const Duration(seconds: 2),
      );
    } finally {
      isUploadingImage.value = false;
    }
  }

  Future<void> logout() => authController.logout();
}
