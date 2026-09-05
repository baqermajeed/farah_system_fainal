import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/splash_controller.dart';
import 'package:farah_sys_final/core/widgets/decorative_background.dart';

/// شاشة Splash — GetView؛ المنطق في SplashController.
class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // يضمن إنشاء الـ controller عند البناء إن لم يُسجَّل عبر binding
    controller;
    return AuthDecoratedScaffold(
      scene: AuthDecorScene.splash,
      body: Center(
        child: Image(
          image: const AssetImage('assets/images/logo.png'),
          width: 200.w,
          height: 200.h,
          fit: BoxFit.contain,
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(
              begin: const Offset(0.82, 0.82),
              end: const Offset(1, 1),
              duration: 800.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}
