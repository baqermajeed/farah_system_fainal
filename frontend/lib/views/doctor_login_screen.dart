import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/widgets/custom_text_field.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/doctor_login_controller.dart';

class _LoginAssets {
  static const back = 'assets/icon/backblack.png';
}

/// شاشة تسجيل دخول الطبيب — GetView؛ المنطق في DoctorLoginController.
class DoctorLoginScreen extends GetView<DoctorLoginController> {
  const DoctorLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
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
                    SizedBox(height: 24.h),
                    Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: DoctorLoginController.actionNavy,
                        ),
                        inputDecorationTheme: Theme.of(context)
                            .inputDecorationTheme
                            .copyWith(
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.r),
                                borderSide: const BorderSide(
                                  color: DoctorLoginController.actionNavy,
                                  width: 2,
                                ),
                              ),
                            ),
                      ),
                      child: Obx(
                        () => Column(
                          children: [
                            CustomTextField(
                              labelText: AppStrings.doctorName,
                              controller: controller.usernameController,
                              onChanged: controller.onUsernameChanged,
                              errorText: controller.usernameError.value,
                            ),
                            SizedBox(height: 16.h),
                            CustomTextField(
                              labelText: AppStrings.password,
                              controller: controller.passwordController,
                              obscureText: true,
                              onChanged: controller.onPasswordChanged,
                              errorText: controller.passwordError.value,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Obx(
                      () => Container(
                        width: double.infinity,
                        height: 50.h,
                        decoration: BoxDecoration(
                          color: controller.auth.isLoading.value
                              ? AppColors.textHint
                              : DoctorLoginController.actionNavy,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: controller.auth.isLoading.value
                                ? null
                                : controller.submit,
                            borderRadius: BorderRadius.circular(16.r),
                            child: Center(
                              child: controller.auth.isLoading.value
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 20.h,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          AppColors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      AppStrings.login,
                                      style: TextStyle(
                                        fontFamily: AppFonts.family,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
      ),
    );
  }
}
