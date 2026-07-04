import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/models/patient_model.dart';

class FamilyMemberSelectionScreen extends StatelessWidget {
  const FamilyMemberSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final members = (Get.arguments?['members'] as List<PatientModel>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'اختر فرد العائلة',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'من تريد متابعة بياناته؟',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'جميع أفراد العائلة مرتبطون بنفس رقم الهاتف، ولكل فرد ملف طبي مستقل.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 24.h),
              Expanded(
                child: ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _FamilyMemberCard(
                      member: member,
                      onTap: () async {
                        await authController.selectFamilyMember(member.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({
    required this.member,
    required this.onTap,
  });

  final PatientModel member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26.r,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: member.imageUrl != null && member.imageUrl!.isNotEmpty
                    ? NetworkImage(member.imageUrl!)
                    : null,
                child: member.imageUrl == null || member.imageUrl!.isEmpty
                    ? Icon(Icons.person, color: AppColors.primary, size: 28.sp)
                    : null,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name.isNotEmpty ? member.name : 'بدون اسم',
                      style: GoogleFonts.cairo(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${member.age} سنة • ${member.city.isNotEmpty ? member.city : '—'}',
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (member.phoneNumber.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        member.phoneNumber,
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: AppColors.primary, size: 24.sp),
            ],
          ),
        ),
      ),
    );
  }
}
