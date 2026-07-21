import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/services/patient_service.dart';

/// Controller لشاشة ترحيب المريض — يتابع ربط الطبيب دورياً وينقل تلقائياً.
class PatientWelcomeController extends GetxController {
  Timer? _checkTimer;

  AuthController get authController => Get.find<AuthController>();
  PatientController get patientController => Get.find<PatientController>();

  /// أكثر من فرد = حساب عائلي (إظهار زر الإعدادات بدل الخروج المباشر).
  final RxBool isFamilyAccount = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFamilyStatus();
    _checkDoctorAssignment();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkDoctorAssignment();
    });
  }

  @override
  void onClose() {
    _checkTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadFamilyStatus() async {
    try {
      final members = await PatientService().getFamilyProfiles();
      isFamilyAccount.value = members.length > 1;
    } catch (_) {
      isFamilyAccount.value = false;
    }
  }

  Future<void> _checkDoctorAssignment() async {
    try {
      final hasDoctor = await patientController.checkDoctorAssignment();
      if (hasDoctor) {
        _checkTimer?.cancel();
        Get.offAllNamed(AppRoutes.patientHome);
      }
    } catch (e) {
      print(
        '❌ [PatientWelcomeController] Error checking doctor assignment: $e',
      );
    }
  }

  Future<void> confirmLogout() async {
    final shouldLogout = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('تسجيل الخروج', textAlign: TextAlign.right),
        content: const Text(
          'هل أنت متأكد من تسجيل الخروج؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await authController.logout();
    }
  }
}
