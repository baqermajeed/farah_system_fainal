import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';

/// إعدادات موحّدة لشاشة قص الصورة (تتجنب تداخل شريط حالة الهاتف مع زر التأكيد).
List<PlatformUiSettings> appImageCropperUiSettings({
  String title = 'تعديل الصورة',
}) {
  return [
    AndroidUiSettings(
      toolbarTitle: title,
      toolbarColor: AppColors.primary,
      toolbarWidgetColor: Colors.white,
      activeControlsWidgetColor: AppColors.primary,
      statusBarLight: false,
      initAspectRatio: CropAspectRatioPreset.square,
      lockAspectRatio: true,
    ),
    IOSUiSettings(
      title: title,
      aspectRatioLockEnabled: true,
      resetAspectRatioEnabled: false,
    ),
  ];
}
