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
import 'package:farah_sys_final/controllers/doctor_login_controller.dart';

class _LoginAssets {
  static const back = 'assets/icon/backblack.png';
}

/// شاشة تسجيل دخول الطبيب — GetView؛ المنطق في DoctorLoginController.
class DoctorLoginScreen extends GetView<DoctorLoginController> {
  const DoctorLoginScreen({super.key});

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
                  Obx(() {
                    final usernameError = controller.usernameError.value;
                    return AuthTextField(
                      hint: AppStrings.doctorName,
                      icon: Icons.person_outline_rounded,
                      controller: controller.usernameController,
                      onChanged: controller.onUsernameChanged,
                      errorText: usernameError != null && usernameError.isNotEmpty
                          ? usernameError
                          : null,
                      showErrorBorder: usernameError != null,
                      focusColor: DoctorLoginController.actionNavy,
                    ).shakeOnTick(controller.usernameShakeTick.value);
                  })
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .slideX(
                        begin: 0.08,
                        end: 0,
                        duration: 400.ms,
                        delay: 100.ms,
                      ),
                  SizedBox(height: 16.h),
                  Obx(() {
                    final passwordError = controller.passwordError.value;
                    return AuthTextField(
                      hint: AppStrings.password,
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      controller: controller.passwordController,
                      onChanged: controller.onPasswordChanged,
                      errorText: passwordError != null && passwordError.isNotEmpty
                          ? passwordError
                          : null,
                      showErrorBorder: passwordError != null,
                      focusColor: DoctorLoginController.actionNavy,
                    ).shakeOnTick(controller.passwordShakeTick.value);
                  })
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms)
                      .slideX(
                        begin: 0.08,
                        end: 0,
                        duration: 400.ms,
                        delay: 200.ms,
                      ),
                  SizedBox(height: 28.h),
                  Obx(
                    () => AuthButton(
                      label: controller.auth.isLoading.value
                          ? 'جاري الدخول...'
                          : AppStrings.login,
                      isLoading: controller.auth.isLoading.value,
                      onPressed: controller.submit,
                      backgroundColor: DoctorLoginController.actionNavy,
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
