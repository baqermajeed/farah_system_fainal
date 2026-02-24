import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';
import 'package:frontend_desktop/core/widgets/custom_text_field.dart';
import 'package:frontend_desktop/core/widgets/back_button_widget.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';

class CallCenterLoginScreen extends StatefulWidget {
  const CallCenterLoginScreen({super.key});

  @override
  State<CallCenterLoginScreen> createState() => _CallCenterLoginScreenState();
}

class _CallCenterLoginScreenState extends State<CallCenterLoginScreen> {
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
                            width: 160.w,
                            height: 160.h,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 160.w,
                                height: 160.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.local_hospital,
                                  size: 80.sp,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // Title
                    Text(
                      AppStrings.callCenterLogin,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Username field
                    Center(
                      child: SizedBox(
                        width: 300.w,
                        child: CustomTextField(
                          controller: _usernameController,
                          labelText: AppStrings.receptionUsername,
                          hintText: 'اسم المستخدم',
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Password field
                    Center(
                      child: SizedBox(
                        width: 300.w,
                        child: CustomTextField(
                          controller: _passwordController,
                          labelText: AppStrings.password,
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock),
                          obscureText: true,
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Login button
                    Obx(
                      () => Center(
                        child: SizedBox(
                          width: 300.w,
                          height: 50.h,
                          child: ElevatedButton(
                          onPressed: _authController.isLoading.value
                              ? null
                              : () {
                                  _authController.loginDoctor(
                                    username: _usernameController.text,
                                    password: _passwordController.text,
                                    expectedUserType: 'call_center',
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: _authController.isLoading.value
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.white,
                                  ),
                                )
                              : Text(
                                  AppStrings.login,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.white,
                                  ),
                                ),
                        ),
                      ),
                    )),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
            // Back button
            const Positioned(
              top: 8,
              left: 8,
              child: BackButtonWidget(),
            ),
          ],
        ),
      ),
    );
  }
}

