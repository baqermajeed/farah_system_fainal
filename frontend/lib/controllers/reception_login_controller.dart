import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'auth_controller.dart';

/// Controller لشاشة تسجيل دخول الاستقبال.
class ReceptionLoginController extends GetxController {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  AuthController get auth => Get.find<AuthController>();

  Future<void> submit() async {
    if (auth.isLoading.value) return;

    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      Get.snackbar(
        'خطأ',
        'يرجى إدخال اسم المستخدم وكلمة المرور',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    await auth.loginDoctor(
      username: usernameController.text.trim(),
      password: passwordController.text,
    );
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
