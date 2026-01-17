import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/services/auth_service.dart';

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
    final isLoggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    if (!isLoggedIn) {
      Get.offAllNamed(AppRoutes.onboarding);
      return;
    }

    await _authController.checkLoggedInUser(navigate: false);
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
