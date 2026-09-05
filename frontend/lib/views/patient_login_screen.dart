import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/widgets/auth_button.dart';
import 'package:farah_sys_final/core/widgets/auth_text_field.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/core/widgets/decorative_background.dart';
import 'package:farah_sys_final/core/widgets/shake_animation.dart';
import 'package:farah_sys_final/controllers/patient_login_controller.dart';

class _LoginAssets {
  static const back = 'assets/icon/backblack.png';
}

/// شاشة تسجيل دخول المريض — GetView؛ المنطق في PatientLoginController.
class PatientLoginScreen extends GetView<PatientLoginController> {
  const PatientLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthDecoratedScaffold(
      scene: AuthDecorScene.login,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Column(
                children: [
                  SizedBox(height: 56.h),
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 250.h,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          child: Opacity(
                            opacity: 0.85,
                            child: Image.asset(
                              'assets/images/tooth_logo.png',
                              width: 280.w,
                              height: 280.h,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Image.asset(
                          'assets/images/logo.png',
                          width: 140.w,
                          height: 140.h,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 140.w,
                              height: 140.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              child: Icon(
                                Icons.local_hospital,
                                size: 70.sp,
                                color: AppColors.primary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    AppStrings.login,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 28.h),
                  Obx(
                    () => AuthTextField(
                      hint: AppStrings.phoneNumber,
                      icon: Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone,
                      controller: controller.phoneController,
                      onChanged: controller.onPhoneChanged,
                      errorText: controller.phoneError.value,
                      showErrorBorder: controller.phoneError.value != null,
                      focusColor: PatientLoginController.actionNavy,
                    ).shakeOnTick(controller.phoneShakeTick.value),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .slideX(
                        begin: 0.08,
                        end: 0,
                        duration: 400.ms,
                        delay: 100.ms,
                      ),
                  SizedBox(height: 28.h),
                  Obx(
                    () => AuthButton(
                      label: controller.auth.isLoading.value
                          ? 'جاري الدخول...'
                          : AppStrings.login,
                      isLoading: controller.auth.isLoading.value,
                      onPressed: controller.submit,
                      backgroundColor: PatientLoginController.actionNavy,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 450.ms, delay: 300.ms)
                      .slideY(
                        begin: 0.15,
                        end: 0,
                        duration: 450.ms,
                        delay: 300.ms,
                      ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16.h,
            left: 16,
            child: const BackButtonWidget(assetPath: _LoginAssets.back),
          ),
        ],
      ),
    );
  }
}
