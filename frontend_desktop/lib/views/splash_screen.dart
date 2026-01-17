import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/core/routes/app_routes.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';

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

    try {
      // التحقق من الجلسة المحفوظة
      await _authController.checkLoggedInUser(navigate: true);
    } catch (e) {
      print('❌ [SplashScreen] Error checking logged in user: $e');
      // في حالة وجود خطأ، انتقل إلى صفحة اختيار المستخدم
      if (mounted) {
        Get.offAllNamed(AppRoutes.userSelection);
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
            'assets/images/logo.png',
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
