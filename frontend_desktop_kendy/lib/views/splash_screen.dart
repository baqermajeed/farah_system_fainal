import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/core/routes/app_routes.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final AuthController _authController;
  
  @override
  void initState() {
    super.initState();
    // الحصول على AuthController (يتم تهيئته في main.dart)
    _authController = Get.find<AuthController>();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // انتظر ثانية واحدة لإظهار الشعار
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // أولاً: تحقق من الاتصال بالإنترنت، وأظهر دايلوج إذا لا يوجد اتصال
    final connected = await _ensureInternetConnection();
    if (!connected || !mounted) return;

    try {
      // التحقق من الجلسة المحفوظة
      // إذا فشل refresh token (401)، سيقوم checkLoggedInUser بمسح الجلسة والانتقال إلى userSelection تلقائياً
      await _authController.checkLoggedInUser(navigate: true);
    } catch (e) {
      print('❌ [SplashScreen] Error checking logged in user: $e');
      // في حالة وجود خطأ، تأكد من مسح الجلسة والانتقال إلى صفحة اختيار المستخدم
      try {
        await _authController.logout();
      } catch (logoutError) {
        print('⚠️ [SplashScreen] Error during logout: $logoutError');
      }
      if (mounted) {
        Get.offAllNamed(AppRoutes.userSelection);
      }
    }
  }

  /// يتحقق من الاتصال بالشبكة. إذا لم يكن هناك اتصال، يظهر دايلوج
  /// "تحقق من اتصالك بشبكة الإنترنت" مع زر لإعادة المحاولة.
  Future<bool> _ensureInternetConnection() async {
    while (true) {
      final hasConnection = await NetworkUtils.hasInternetConnection();
      if (hasConnection) {
        return true;
      }

      if (!mounted) return false;

      final retry = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('لا يوجد اتصال بالإنترنت'),
          content: const Text('تحقق من اتصالك بشبكة الإنترنت ثم حاول مرة أخرى.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      if (retry != true) {
        return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Image.asset(
            'assets/images/kendy_logo.png',
            width: 200.w,
            height: 200.h,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200.w,
                height: 200.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withOpacity(0.3),
                ),
                child: Icon(
                  Icons.local_hospital,
                  size: 100.sp,
                  color: AppColors.primary,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
