import 'dart:io';

import 'package:farah_sys_final/views/profile_image_crop_screen.dart';

/// قص صورة الملف الشخصي عبر شاشة Flutter آمنة (بدون UCrop).
Future<File?> cropProfileImage(String sourcePath) {
  return ProfileImageCropScreen.open(sourcePath);
}
