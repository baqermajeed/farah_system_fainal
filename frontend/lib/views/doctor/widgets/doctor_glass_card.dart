import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';

class DoctorGlassCard extends StatelessWidget {
  const DoctorGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.onTap,
    this.gradient,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? 20.r;
    final content = Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.doctorCard) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow ? AppColors.doctorCardShadow : null,
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}
