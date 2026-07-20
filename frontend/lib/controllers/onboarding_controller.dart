import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/routes/app_routes.dart';

/// Controller لشاشة الـ Onboarding — يدير PageController والانتقال بين الشرائح.
class OnboardingController extends GetxController {
  final PageController pageController = PageController();
  final RxInt currentIndex = 0.obs;

  void onPageChanged(int index) {
    currentIndex.value = index;
  }

  void goNext(int totalSlides) {
    if (currentIndex.value == totalSlides - 1) {
      Get.offAllNamed(AppRoutes.userSelection);
    } else {
      pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void goBack() {
    if (currentIndex.value > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void skip() => Get.offAllNamed(AppRoutes.userSelection);

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
