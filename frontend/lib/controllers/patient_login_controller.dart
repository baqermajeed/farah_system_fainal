import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/routes/app_routes.dart';
import 'auth_controller.dart';

/// Controller لشاشة تسجيل دخول المريض.
class PatientLoginController extends GetxController {
  final phoneController = TextEditingController();
  static const Color actionNavy = Color(0xFF032252);

  AuthController get auth => Get.find<AuthController>();

  bool isPhoneValid(String phone) {
    final cleaned = phone.trim();
    return RegExp(r'^07\d{9}$').hasMatch(cleaned);
  }

  Future<void> submit() async {
    if (auth.isLoading.value) return;

    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال رقم الهاتف', snackPosition: SnackPosition.TOP);
      return;
    }
    if (!isPhoneValid(phone)) {
      Get.snackbar(
        'خطأ',
        'رقم الهاتف يجب أن يبدأ بـ 07 ويتكون من 11 رقماً',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    await auth.requestOtp(phone);
    Get.toNamed(
      AppRoutes.otpVerification,
      arguments: {'phoneNumber': phone},
    );
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }
}
