import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/routes/app_routes.dart';
import '../core/theme/app_fonts.dart';
import '../core/utils/network_utils.dart';
import 'auth_controller.dart';

/// Controller لشاشة Splash — منطق الإقلاع خارج الـ View (نمط قريب MVC).
class SplashController extends GetxController {
  AuthController get auth => Get.find<AuthController>();

  bool _started = false;

  @override
  void onReady() {
    super.onReady();
    start();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // عرض الشعار لحظة قصيرة ثم متابعة الإقلاع
    await Future.delayed(const Duration(milliseconds: 800));

    final connected = await _ensureInternetConnection();
    if (!connected) {
      Get.offAllNamed(AppRoutes.onboarding);
      return;
    }

    try {
      // ينتظر استعادة الجلسة إن كانت جارية من main، ثم يوجّه حسب الدور
      await auth.checkLoggedInUser(navigate: true);
      if (!auth.isAuthenticated) {
        Get.offAllNamed(AppRoutes.onboarding);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SplashController] start error: $e');
      }
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
