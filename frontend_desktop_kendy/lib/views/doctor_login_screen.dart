import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';
import 'package:frontend_desktop/core/widgets/custom_text_field.dart';
import 'package:frontend_desktop/core/widgets/back_button_widget.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthController _authController = Get.put(AuthController());

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      Get.snackbar(
        'خطأ',
        'يرجى إدخال اسم المستخدم وكلمة المرور',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    // Call AuthController login
    await _authController.loginDoctor(
      username: _usernameController.text,
      password: _passwordController.text,
    );
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
                          
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Login title
                    Text(
                      AppStrings.login,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Username field
                    Center(
                      child: SizedBox(
                        width: 300.w,
                        child: CustomTextField(
                          labelText: AppStrings.doctorName,
                          controller: _usernameController,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Password field
                    Center(
                      child: SizedBox(
                        width: 300.w,
                        child: CustomTextField(
                          labelText: AppStrings.password,
                          hintText: '••••••••',
                          controller: _passwordController,
                          obscureText: true,
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    // Login button
                    Obx(
                      () => Center(
                        child: Container(
                          width: 300.w,
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
                                  : _handleLogin,
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
                    ),
                  ],
                ),
              ),
            ),
            // Back button positioned at top left without padding
            Positioned(top: 16.h, left: 16, child: const BackButtonWidget()),
          ],
        ),
      ),
    );
  }
}
