import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/patient_welcome_controller.dart';
import 'package:farah_sys_final/views/patient_browse_screen.dart';

/// شاشة ترحيب المريض — GetView؛ المنطق في PatientWelcomeController.
class PatientWelcomeScreen extends GetView<PatientWelcomeController> {
  const PatientWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final messageStyle = AppFonts.lamaSans(
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
                      onTap: controller.authController.isLoading.value
                          ? null
                          : controller.confirmLogout,
                      child: SizedBox(
                        width: 20.w,
                        height: 30.h,
                        child: Center(
                          child: controller.authController.isLoading.value
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
                        child: Obx(
                          () {
                            final profileName = controller
                                .patientController.myProfile.value?.name;
                            final userName = controller
                                .authController.currentUser.value?.name;
                            final displayName =
                                profileName ?? userName ?? 'المريض';
                            return Text(
                              'مرحبا عزيزي "$displayName" انتظر\n'
                              'حتى يتم تحويلك من قبل موظف\n'
                              'الاستقبال الى طبيب معين لتبدأ رحلتك\n'
                              'العلاجية معنا',
                              textAlign: TextAlign.center,
                              style: messageStyle,
                            );
                          },
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
                style: AppFonts.lamaSans(
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
