import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();
  final _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _handleStartup();
    });
  }

  Future<void> _handleStartup() async {
    // أولاً: تحقق من الاتصال بالإنترنت، وأظهر دايلوج إذا لا يوجد اتصال
    final connected = await _ensureInternetConnection();
    if (!connected || !mounted) return;

    final isLoggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    if (!isLoggedIn) {
      Get.offAllNamed(AppRoutes.onboarding);
      return;
    }

    try {
      await _authController.checkLoggedInUser(navigate: false);
    } catch (e) {
      print('❌ [SplashScreen] Error checking logged in user: $e');
      // في حالة وجود خطأ، انتقل إلى صفحة اختيار المستخدم
      if (mounted) {
        Get.offAllNamed(AppRoutes.userSelection);
      }
      return;
    }

    if (!mounted) return;

    final userTypeValue = _authController.currentUser.value?.userType;
    final userType = userTypeValue?.toLowerCase();
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
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Image(
            image: AssetImage('assets/images/logo.png'),
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
