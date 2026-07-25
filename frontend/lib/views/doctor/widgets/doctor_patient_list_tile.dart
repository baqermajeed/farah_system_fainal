import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/widgets/app_avatar.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_glass_card.dart';

class DoctorPatientListTile extends StatelessWidget {
  const DoctorPatientListTile({
    super.key,
    required this.patient,
    required this.onTap,
    this.onChatTap,
    this.unreadCount = 0,
    this.subtitle,
    this.showChevron = true,
  });

  final PatientModel patient;
  final VoidCallback onTap;
  final VoidCallback? onChatTap;
  final int unreadCount;
  final String? subtitle;
  final bool showChevron;

  String get _treatment =>
      patient.treatmentHistory != null && patient.treatmentHistory!.isNotEmpty
          ? patient.treatmentHistory!.last
          : 'لا يوجد علاج';

  @override
  Widget build(BuildContext context) {
    return DoctorGlassCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      margin: EdgeInsets.only(bottom: 12.h),
      borderRadius: 16.r,
      showShadow: false,
      child: Row(
        children: [
          AppAvatar(
            imageUrl: patient.imageUrl,
            size: 52.w,
            cornerRadius: 14.r,
            backgroundColor: AppColors.doctorSurface,
            borderColor: AppColors.divider,
            borderWidth: 1,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  patient.name,
                  style: AppFonts.lamaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle ??
                      '${patient.age} سنة • ${patient.gender} • $_treatment',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.doctorLabel,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          if (onChatTap != null) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: onChatTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.chat_rounded,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (showChevron) ...[
            SizedBox(width: 4.w),
            RotatedBox(
              quarterTurns: 2,
              child: Icon(
                Icons.chevron_left_rounded,
                color: AppColors.primaryLight,
                size: 24.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
