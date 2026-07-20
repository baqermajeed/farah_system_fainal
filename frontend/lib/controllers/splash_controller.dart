import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/routes/app_routes.dart';
import '../core/theme/app_fonts.dart';
import '../core/utils/network_utils.dart';
import 'auth_controller.dart';

/// Controller لشاشة Splash — منطق الإقلاع خارج الـ View (نمط قريب MVC).
class SplashController extends GetxController {
  AuthController get auth => Get.find<AuthController>();

  @override
  void onReady() {
    super.onReady();
    Future.delayed(const Duration(seconds: 1), start);
  }

  Future<void> start() async {
    final connected = await _ensureInternetConnection();
    if (!connected) return;

    try {
      await auth.loadStoredAuth();
    } catch (e) {
      print('❌ [SplashController] Error restoring session: $e');
      Get.offAllNamed(AppRoutes.userSelection);
      return;
    }

    if (!auth.isAuthenticated) {
      Get.offAllNamed(AppRoutes.onboarding);
      return;
    }

    final userType = auth.currentUser.value?.userType.toLowerCase();
    switch (userType) {
      case 'patient':
        Get.offAllNamed(AppRoutes.patientHome);
        return;
      case 'doctor':
        Get.offAllNamed(AppRoutes.doctorHome);
        return;
      case 'receptionist':
        Get.offAllNamed(AppRoutes.receptionHome);
        return;
      default:
        Get.offAllNamed(AppRoutes.userSelection);
    }
  }

  Future<bool> _ensureInternetConnection() async {
    while (true) {
      final hasConnection = await NetworkUtils.hasInternetConnection();
      if (hasConnection) return true;

      final retry = await Get.dialog<bool>(
        AlertDialog(
          title: Text(
            'لا يوجد اتصال بالإنترنت',
            style: AppFonts.lamaSans(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'تحقق من اتصالك بشبكة الإنترنت ثم حاول مرة أخرى.',
            style: AppFonts.lamaSans(),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('إلغاء', style: AppFonts.lamaSans()),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: Text(
                'إعادة المحاولة',
                style: AppFonts.lamaSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      if (retry != true) return false;
    }
  }
}
