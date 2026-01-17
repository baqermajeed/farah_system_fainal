import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/widgets/custom_text_field.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';

class ReceptionLoginScreen extends StatefulWidget {
  const ReceptionLoginScreen({super.key});

  @override
  State<ReceptionLoginScreen> createState() => _ReceptionLoginScreenState();
}

class _ReceptionLoginScreenState extends State<ReceptionLoginScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content with padding
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    SizedBox(height: 56.h),
                    SizedBox(height: 12.h),
                    // Logo with background tooth icon
                    SizedBox(
                      height: 250.h,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Large faint tooth icon in background
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
                          // Main logo
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
                    // Login title
                    Text(
                      AppStrings.receptionLogin,
                      style: TextStyle(
                        fontFamily: 'Expo Arabic',
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Username field
                    CustomTextField(
                      labelText: AppStrings.receptionUsername,
                      hintText: 'اسم المستخدم',
                      controller: _usernameController,
                    ),
                    SizedBox(height: 16.h),
                    // Password field
                    CustomTextField(
                      labelText: AppStrings.password,
                      hintText: '••••••••',
                      controller: _passwordController,
                      obscureText: true,
                    ),
                    SizedBox(height: 24.h),
                    // Login button (without icon)
                    Obx(
                      () => Container(
                        width: double.infinity,
                        height: 50.h,
                        decoration: BoxDecoration(
                          color: _authController.isLoading.value
                              ? AppColors.textHint
                              : AppColors.secondary,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _authController.isLoading.value
                                ? null
                                : () async {
                                    if (_usernameController.text.isEmpty ||
                                        _passwordController.text.isEmpty) {
                                      Get.snackbar(
                                        'خطأ',
                                        'يرجى إدخال اسم المستخدم وكلمة المرور',
                                        snackPosition: SnackPosition.TOP,
                                      );
                                      return;
                                    }

                                    await _authController.loginDoctor(
                                      username: _usernameController.text.trim(),
                                      password: _passwordController.text,
                                    );
                                  },
                            borderRadius: BorderRadius.circular(16.r),
                            child: Center(
                              child: _authController.isLoading.value
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
                                        fontFamily: 'Expo Arabic',
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
            // Back button positioned at top left without padding
            Positioned(top: 16.h, left: 16, child: BackButtonWidget()),
          ],
        ),
      ),
    );
  }
}
