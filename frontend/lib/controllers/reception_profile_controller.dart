import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/services/auth_service.dart';

/// Controller لشاشة الملف الشخصي لموظف الاستقبال — المنطق والحالة خارج الـ View.
class ReceptionProfileController extends GetxController {
  AuthController get authController => Get.find<AuthController>();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  final RxBool isUploadingImage = false.obs;
  final RxInt imageTimestamp = RxInt(DateTime.now().millisecondsSinceEpoch);

  Future<void> pickAndUploadImage() async {
    if (isUploadingImage.value) return;

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

      isUploadingImage.value = true;

      await _authService.uploadProfileImage(File(croppedFile.path));
      await authController.checkLoggedInUser(navigate: false);

      imageTimestamp.value = DateTime.now().millisecondsSinceEpoch;

      Get.snackbar('تم', 'تم تحديث الصورة الشخصية بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفع الصورة: ${e.toString()}');
    } finally {
      isUploadingImage.value = false;
    }
  }

  Future<void> logout() => authController.logout();
}
