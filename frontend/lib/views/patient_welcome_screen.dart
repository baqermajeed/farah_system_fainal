import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/views/patient_browse_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientWelcomeScreen extends StatefulWidget {
  const PatientWelcomeScreen({super.key});

  @override
  State<PatientWelcomeScreen> createState() => _PatientWelcomeScreenState();
}

class _PatientWelcomeScreenState extends State<PatientWelcomeScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final PatientController _patientController = Get.find<PatientController>();
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    // التحقق من حالة المريض كل 5 ثوانٍ
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkDoctorAssignment();
    });
    // التحقق فوراً عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDoctorAssignment();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDoctorAssignment() async {
    try {
      final hasDoctor = await _patientController.checkDoctorAssignment();
      if (hasDoctor && mounted) {
        // إذا تم ربط المريض بطبيب، الانتقال إلى الصفحة الرئيسية
        _checkTimer?.cancel();
        Get.offAllNamed(AppRoutes.patientHome);
      }
    } catch (e) {
      print('❌ [PatientWelcomeScreen] Error checking doctor assignment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _authController.currentUser.value?.name ?? 'المريض';
    final messageStyle = GoogleFonts.cairo(
      fontSize: 16.sp,
      fontWeight: FontWeight.bold,
      height: 1.6,
      color: const Color(0xFF6C9FB7),
    );

    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            children: [
              SizedBox(height: 24.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'الصفحة الرئيسية',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  Obx(
                    () => InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: _authController.isLoading.value
                          ? null
                          : () async {
                              final shouldLogout = await Get.dialog<bool>(
                                AlertDialog(
                                  title: Text(
                                    'تسجيل الخروج',
                                    textAlign: TextAlign.right,
                                  ),
                                  content: Text(
                                    'هل أنت متأكد من تسجيل الخروج؟',
                                    textAlign: TextAlign.right,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Get.back(result: false),
                                      child: Text('إلغاء'),
                                    ),
                                    TextButton(
                                      onPressed: () => Get.back(result: true),
                                      child: Text(
                                        'تسجيل الخروج',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldLogout == true) {
                                await _authController.logout();
                              }
                            },
                      child: SizedBox(
                        width: 20.w,
                        height: 30.h,
                        child: Center(
                          child: _authController.isLoading.value
                              ? SizedBox(
                                  width: 12.w,
                                  height: 12.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(AppColors.white),
                                  ),
                                )
                              : Icon(
                                  Icons.logout,
                                  size: 22.sp,
                                  color: const Color.fromARGB(255, 95, 181, 231),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/clean 1.png',
                        width: 220.w,
                        fit: BoxFit.contain,
                      ),
                      
                      Padding(
                        padding: EdgeInsets.only(
                          left: 12.w,
                          right: 12.w,
                          top: 40.h,
                        ),
                        child: Text(
                          'مرحبا عزيزي "$userName" انتظر\n'
                          'حتى يتم تحويلك من قبل موظف\n'
                          'الاستقبال الى طبيب معين لتبدأ رحلتك\n'
                          'العلاجية معنا',
                          textAlign: TextAlign.center,
                          style: messageStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'حتى يتم تحويلك الى الطبيب تصفح بعض المعلومات الطبية حول الاسنان 🌚👀 ' ,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6C9FB7),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 6.h),
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () {
                    Get.to(() => const PatientBrowseScreen());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B9FCC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'تصفح الآن',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }
}
