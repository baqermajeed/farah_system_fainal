import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthController _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _auth.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_auth.booting.value) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (_auth.isAuthed && _auth.isAdmin) {
        return const DashboardScreen();
      }
      return const LoginScreen();
    });
  }
}


