import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'auth_controller.dart';

/// Controller لشاشة تسجيل دخول الاستقبال.
class ReceptionLoginController extends GetxController {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  static const Color actionNavy = Color(0xFF032252);

  final RxnString usernameError = RxnString();
  final RxnString passwordError = RxnString();
  final usernameShakeTick = 0.obs;
  final passwordShakeTick = 0.obs;

  AuthController get auth => Get.find<AuthController>();

  void clearFieldErrors() {
    usernameError.value = null;
    passwordError.value = null;
  }

  void onUsernameChanged(String _) => clearFieldErrors();

  void onPasswordChanged(String _) => clearFieldErrors();

  Future<void> submit() async {
    if (auth.isLoading.value) return;

    clearFieldErrors();

    var hasEmpty = false;
    if (usernameController.text.trim().isEmpty) {
      usernameError.value = 'يرجى إدخال اسم المستخدم';
      usernameShakeTick.value++;
      hasEmpty = true;
    }
    if (passwordController.text.isEmpty) {
      passwordError.value = 'يرجى إدخال كلمة المرور';
      passwordShakeTick.value++;
      hasEmpty = true;
    }
    if (hasEmpty) return;

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
