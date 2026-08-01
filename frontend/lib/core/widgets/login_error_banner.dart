import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';

class LoginErrorBanner extends StatelessWidget {
  const LoginErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 22.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
