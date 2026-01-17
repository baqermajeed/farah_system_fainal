import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';

class BackButtonWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? size;

  const BackButtonWidget({
    super.key,
    this.onTap,
    this.backgroundColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Get.back(),
      child: Image.asset(
        'assets/images/arrow-square-up.png',
        width: size?.w ?? 48.w,
        height: size?.w ?? 48.w,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to a simple back button if the asset is missing
          return Container(
            width: size?.w ?? 48.w,
            height: size?.w ?? 48.w,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.secondary,
              borderRadius: BorderRadius.circular(20.r),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20.sp,
            ),
          );
        },
      ),
    );
  }
}
