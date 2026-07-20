import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'auth_controller.dart';

/// Controller لشاشة التحقق من OTP — المنطق والحالة خارج الـ View.
class OtpVerificationController extends GetxController {
  static const int otpLength = 6;
  static const Color otpNumberColor = Color(0xFF032252);

  late final String phoneNumber;
  final List<TextEditingController> otpControllers =
      List.generate(otpLength, (_) => TextEditingController());
  final List<FocusNode> otpFocusNodes =
      List.generate(otpLength, (_) => FocusNode());

  final remainingSeconds = 60.obs;
  /// يُزاد لإعادة بناء واجهة خانات OTP عند التغيير.
  final otpUiTick = 0.obs;

  Timer? _timer;
  AuthController get auth => Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['phoneNumber'] != null) {
      phoneNumber = args['phoneNumber'].toString();
    } else {
      phoneNumber = '';
    }
    startTimer();
  }

  void startTimer() {
    _timer?.cancel();
    remainingSeconds.value = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        timer.cancel();
      }
    });
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void clearOtpFields() {
    for (final c in otpControllers) {
      c.clear();
    }
    otpFocusNodes.first.requestFocus();
    otpUiTick.value++;
  }

  void onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < otpControllers.length - 1) {
      otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      otpFocusNodes[index - 1].requestFocus();
    }
    otpUiTick.value++;
    verifyOtp();
  }

  void verifyOtp() {
    final otp = otpControllers.map((c) => c.text).join();
    if (otp.length == otpLength) {
      auth.verifyOtpAndLogin(phoneNumber: phoneNumber, code: otp);
    }
  }

  void onKeypadPressed(String value) {
    for (int i = 0; i < otpControllers.length; i++) {
      if (otpControllers[i].text.isEmpty) {
        otpControllers[i].text = value;
        onOtpChanged(i, value);
        break;
      }
    }
  }

  void onBackspacePressed() {
    for (int i = otpControllers.length - 1; i >= 0; i--) {
      if (otpControllers[i].text.isNotEmpty) {
        otpControllers[i].clear();
        otpFocusNodes[i].requestFocus();
        otpUiTick.value++;
        break;
      }
    }
  }

  Future<void> resendCode() async {
    if (remainingSeconds.value != 0) return;
    clearOtpFields();
    startTimer();
    await auth.requestOtp(phoneNumber);
  }

  @override
  void onClose() {
    _timer?.cancel();
    for (final c in otpControllers) {
      c.dispose();
    }
    for (final f in otpFocusNodes) {
      f.dispose();
    }
    super.onClose();
  }
}
