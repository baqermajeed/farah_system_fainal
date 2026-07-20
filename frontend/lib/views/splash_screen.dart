import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/splash_controller.dart';

/// شاشة Splash — GetView؛ المنطق في SplashController.
class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // يضمن إنشاء الـ controller عند البناء إن لم يُسجَّل عبر binding
    controller;
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
