import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';
import 'package:frontend_desktop/core/routes/app_routes.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  String? selectedUserType;

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
                          
                        ],
                      ),
                    ),
                    SizedBox(height: 40.h),
                    // "اختر نوع المستخدم" text
                    Text(
                      AppStrings.selectUserType,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 32.h),
                    // Doctor button
                    Center(
                      child: _buildUserTypeButton(
                        label: AppStrings.doctor,
                        isSelected: selectedUserType == 'doctor',
                        onTap: () {
                          setState(() {
                            selectedUserType = 'doctor';
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Receptionist button
                    Center(
                      child: _buildUserTypeButton(
                        label: 'موظف',
                        isSelected: selectedUserType == 'receptionist',
                        onTap: () {
                          setState(() {
                            selectedUserType = 'receptionist';
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Call center button
                    Center(
                      child: _buildUserTypeButton(
                        label: 'call center',
                        isSelected: selectedUserType == 'call_center',
                        onTap: () {
                          setState(() {
                            selectedUserType = 'call_center';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Next button
              Padding(
                padding: EdgeInsets.only(bottom: 32.h),
                child: Center(
                  child: GestureDetector(
                    onTap: selectedUserType == null
                        ? null
                        : () {
                            if (selectedUserType == 'doctor') {
                              Get.toNamed(AppRoutes.doctorLogin);
                            } else if (selectedUserType == 'receptionist') {
                              Get.toNamed(AppRoutes.receptionLogin);
                            } else if (selectedUserType == 'call_center') {
                              Get.toNamed(AppRoutes.callCenterLogin);
                            }
                          },
                    child: Opacity(
                      opacity: selectedUserType == null ? 0.5 : 1.0,
                      child: Container(
                        width: 300.w, // match the buttons above
                        height: 56.h,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Centered text
                            Text(
                              AppStrings.next,
                              style: TextStyle(
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
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: AppColors.white,
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
              ? AppColors.secondary
              : AppColors.primaryLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textSecondary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
