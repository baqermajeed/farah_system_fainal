import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';

/// زر كبسولي أساسي لصفحات المصادقة.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expanded = true,
    this.backgroundColor = const Color(0xFF032252),
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expanded;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28.r);
    final enabled = onPressed != null && !isLoading;

    final child = Material(
      color: backgroundColor,
      borderRadius: radius,
      elevation: 0,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: radius,
        splashColor: AppColors.white.withValues(alpha: 0.18),
        highlightColor: AppColors.white.withValues(alpha: 0.08),
        child: Container(
          width: expanded ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 16.h),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: 22.w,
                  height: 22.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}
