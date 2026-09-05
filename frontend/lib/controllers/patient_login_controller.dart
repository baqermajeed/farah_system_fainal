import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/routes/app_routes.dart';
import '../core/utils/network_utils.dart';
import '../core/utils/user_error_messages.dart';
import 'auth_controller.dart';

/// Controller لشاشة تسجيل دخول المريض.
class PatientLoginController extends GetxController {
  final phoneController = TextEditingController();
  static const Color actionNavy = Color(0xFF032252);
  static const String emptyPhoneMessage = 'يرجى إدخال رقم الهاتف';
  static const String invalidPhoneMessage =
      'رقم الهاتف يجب أن يبدأ بـ 07 ويتكون من 11 رقماً';

  final RxnString phoneError = RxnString();
  final phoneShakeTick = 0.obs;

  AuthController get auth => Get.find<AuthController>();

  void clearFieldErrors() {
    phoneError.value = null;
  }

  void onPhoneChanged(String _) => clearFieldErrors();

  bool isPhoneValid(String phone) {
    final cleaned = phone.trim();
    return RegExp(r'^07\d{9}$').hasMatch(cleaned);
  }

  Future<void> submit() async {
    if (auth.isLoading.value) return;

    clearFieldErrors();

    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      phoneError.value = emptyPhoneMessage;
      phoneShakeTick.value++;
      return;
    }
    if (!isPhoneValid(phone)) {
      phoneError.value = invalidPhoneMessage;
      phoneShakeTick.value++;
      return;
    }

    final error = await auth.requestOtp(phone, showErrorUi: false);
    if (error == null) {
      Get.toNamed(
        AppRoutes.otpVerification,
        arguments: {'phoneNumber': phone},
      );
      return;
    }

    if (NetworkUtils.isNetworkError(error) ||
        NetworkUtils.hasForbiddenConnectionText(error)) {
      return;
    }

    phoneError.value = UserErrorMessages.otpRequestMessage(raw: error);
    phoneShakeTick.value++;
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }
}
