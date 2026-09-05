import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';

/// شبكة نقاط زخرفية خفيفة في الخلفية.
class DecorativeDotGrid extends StatelessWidget {
  const DecorativeDotGrid({
    super.key,
    this.rows = 4,
    this.columns = 7,
    this.alignment = Alignment.topLeft,
    this.padding,
    this.color = AppColors.dotGrid,
  });

  final int rows;
  final int columns;
  final Alignment alignment;
  final EdgeInsets? padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding ?? EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (row) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(columns, (col) {
                final fade = 0.35 + ((row + col) % 4) * 0.12;
                return Container(
                  width: 5.w,
                  height: 5.w,
                  margin: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: fade.clamp(0.25, 0.85)),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }
}
