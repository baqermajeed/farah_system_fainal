import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/controllers/user_selection_controller.dart';

/// شاشة اختيار نوع المستخدم — GetView؛ المنطق في UserSelectionController.
class UserSelectionScreen extends GetView<UserSelectionController> {
  const UserSelectionScreen({super.key});

  static const Color _actionNavy = Color(0xFF032252);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with background tooth icon
                    SizedBox(
                      height: 300.h,
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
                                width: 400.w,
                                height: 400.h,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          // Main logo
                          Image.asset(
                            'assets/images/logo.png',
                            width: 200.w,
                            height: 200.h,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200.w,
                                height: 200.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.local_hospital,
                                  size: 100.sp,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 40.h),
                    // "اختر نوع المستخدم" text
                    Text(
                      AppStrings.selectUserType,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 32.h),
                    // Patient button
                    Center(
                      child: Obx(
                        () => _buildUserTypeButton(
                          label: AppStrings.patient,
                          isSelected:
                              controller.selectedUserType.value == 'patient',
                          onTap: () => controller.selectUserType('patient'),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Doctor button
                    Center(
                      child: Obx(
                        () => _buildUserTypeButton(
                          label: AppStrings.doctor,
                          isSelected:
                              controller.selectedUserType.value == 'doctor',
                          onTap: () => controller.selectUserType('doctor'),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Receptionist button
                    Center(
                      child: Obx(
                        () => _buildUserTypeButton(
                          label: 'موظف',
                          isSelected:
                              controller.selectedUserType.value ==
                              'receptionist',
                          onTap: () =>
                              controller.selectUserType('receptionist'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Next button
              Padding(
                padding: EdgeInsets.only(bottom: 32.h),
                child: Obx(
                  () => GestureDetector(
                    onTap: controller.selectedUserType.value == null
                        ? null
                        : controller.navigateNext,
                    child: Opacity(
                      opacity: controller.selectedUserType.value == null
                          ? 0.5
                          : 1.0,
                      child: Container(
                        width: double.infinity,
                        height: 56.h,
                        decoration: BoxDecoration(
                          color: _actionNavy,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Centered text
                            Text(
                              AppStrings.next,
                              style: TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                            // Arrow icon on the left
                            Positioned(
                              left: 8.w,
                              child: Container(
                                width: 40.w,
                                height: 40.h,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: _actionNavy,
                                    size: 20.sp,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildUserTypeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 300.w,
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: isSelected
              ? _actionNavy.withValues(alpha: 0.7)
              : AppColors.primaryLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : AppColors.textSecondary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
