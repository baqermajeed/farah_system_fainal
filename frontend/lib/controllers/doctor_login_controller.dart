import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/utils/network_utils.dart';
import 'auth_controller.dart';

/// Controller لشاشة تسجيل دخول الطبيب.
class DoctorLoginController extends GetxController {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  static const Color actionNavy = Color(0xFF032252);
  static const String credentialsErrorMessage =
      'اسم المستخدم أو كلمة المرور غير صحيحة';

  /// `null` = لا خطأ، `''` = حدود حمراء بدون نص، نص = رسالة تحت الحقل.
  final RxnString usernameError = RxnString();
  final RxnString passwordError = RxnString();

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

    final username = usernameController.text.trim();
    final password = passwordController.text;
    var hasEmpty = false;

    if (username.isEmpty) {
      usernameError.value = 'يرجى إدخال اسم المستخدم';
      hasEmpty = true;
    }
    if (password.isEmpty) {
      passwordError.value = 'يرجى إدخال كلمة المرور';
      hasEmpty = true;
    }
    if (hasEmpty) return;

    final error = await auth.loginDoctor(
      username: username,
      password: password,
      showErrorUi: false,
    );

    if (error == null) return;

    // أخطاء الشبكة تُعرض كحوار من AuthController — لا نعلّم الحقول
    if (NetworkUtils.isNetworkError(error) ||
        NetworkUtils.hasForbiddenConnectionText(error)) {
      return;
    }

    // بيانات دخول خاطئة: حدود حمراء + أيقونة + رسالة واضحة
    usernameError.value = '';
    passwordError.value = credentialsErrorMessage;
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
