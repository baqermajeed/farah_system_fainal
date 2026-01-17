import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../enums/patient_activity_filter_mode.dart';
import '../core/constants/app_colors.dart';

class PatientActivityFilterMenu extends StatelessWidget {
  final PatientActivityFilterMode mode;
  final ValueChanged<PatientActivityFilterMode> onChanged;

  const PatientActivityFilterMenu({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PatientActivityFilterMode>(
      tooltip: 'فلترة المرضى',
      onSelected: onChanged,
      itemBuilder: (context) => PatientActivityFilterMode.values
          .map(
            (item) => PopupMenuItem(
              value: item,
              child: Text(item.label),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode.label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 18, color: AppColors.info),
          ],
        ),
      ),
    );
  }
}

