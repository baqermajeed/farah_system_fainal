import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';

class VisitTypeSelector extends StatelessWidget {
  final String? selectedVisitType;
  final Function(String) onVisitTypeChanged;

  const VisitTypeSelector({
    super.key,
    required this.selectedVisitType,
    required this.onVisitTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            label: AppStrings.newPatient,
            isSelected: selectedVisitType == AppStrings.newPatient,
            onTap: () => onVisitTypeChanged(AppStrings.newPatient),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: _buildButton(
            label: AppStrings.returningPatient,
            isSelected: selectedVisitType == AppStrings.returningPatient,
            onTap: () => onVisitTypeChanged(AppStrings.returningPatient),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white : AppColors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}


