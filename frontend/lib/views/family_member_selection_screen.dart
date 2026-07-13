import 'dart:math' show pi;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/models/patient_model.dart';

class _FamilyAssets {
  static const back = 'assets/icon/backblack.png';
}

class FamilyMemberSelectionScreen extends StatelessWidget {
  const FamilyMemberSelectionScreen({super.key});

  static const Color _bg = Color(0xFFF8FAFF);
  static const Color _navy = Color(0xFF032252);
  static const Color _grayText = Color(0xFF8A97A8);

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final members = (Get.arguments?['members'] as List<PatientModel>?) ?? [];
    final canPop = Navigator.canPop(context);

    final baseTheme = Theme.of(context);
    final theme = baseTheme.copyWith(
      textTheme: AppFonts.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppFonts.textTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(canPop: canPop),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
                child: Column(
                  children: [
                    Text(
                      'من تريد متابعة بياناته؟',
                      textAlign: TextAlign.center,
                      style: AppFonts.lamaSans(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'جميع أفراد العائلة مرتبطون بنفس رقم الهاتف، ولكل فرد ملف طبي مستقل.',
                      textAlign: TextAlign.center,
                      style: AppFonts.lamaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: _grayText,
                        height: 1.6,
                      ),
                    ),
                    if (members.isNotEmpty) ...[
                      SizedBox(height: 16.h),
                      _buildMembersCount(members.length),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Expanded(
                child: members.isEmpty
                    ? const EmptyStateWidget(
                        title: 'لا يوجد أفراد عائلة',
                        subtitle: 'لم يتم العثور على ملفات مرتبطة بهذا الرقم',
                        icon: Icons.people_outline,
                      )
                    : Obx(() {
                        if (authController.isLoading.value) {
                          return const LoadingWidget(
                            message: 'جاري تحميل الملف...',
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                          itemCount: members.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12.h),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            return _FamilyMemberCard(
                              member: member,
                              onTap: () async {
                                await authController.selectFamilyMember(
                                  member.id,
                                );
                              },
                            );
                          },
                        );
                      }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool canPop}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          if (canPop)
            const BackButtonWidget(assetPath: _FamilyAssets.back)
          else
            SizedBox(width: 48.w),
          Expanded(
            child: Text(
              'اختر فرد العائلة',
              textAlign: TextAlign.center,
              style: AppFonts.lamaSans(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ),
          SizedBox(width: 48.w),
        ],
      ),
    );
  }

  Widget _buildMembersCount(int count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _navy.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_outlined, size: 16.sp, color: _navy),
          SizedBox(width: 6.w),
          Text(
            '$count ${count == 1 ? 'فرد' : count == 2 ? 'فردان' : 'أفراد'}',
            style: AppFonts.lamaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
        ],
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

  static const Color _navy = Color(0xFF032252);
  static const Color _grayText = Color(0xFF8A97A8);
  static const Color _border = Color(0xFFE8ECF0);

  @override
  Widget build(BuildContext context) {
    final genderLabel = _genderLabel(member.gender);
    final hasImage =
        member.imageUrl != null && member.imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Row(
                children: [
                  _buildAvatar(hasImage),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name.isNotEmpty ? member.name : 'بدون اسم',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.lamaSans(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 6.w,
                          runSpacing: 6.h,
                          children: [
                            _buildChip(
                              icon: Icons.cake_outlined,
                              label: '${member.age} سنة',
                            ),
                            if (member.city.isNotEmpty)
                              _buildChip(
                                icon: Icons.location_on_outlined,
                                label: member.city,
                              ),
                            if (genderLabel.isNotEmpty)
                              _buildChip(
                                icon: Icons.person_outline,
                                label: genderLabel,
                              ),
                          ],
                        ),
                        if (member.phoneNumber.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Text(
                            member.phoneNumber,
                            style: AppFonts.lamaSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: _grayText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Transform.rotate(
                      angle: pi,
                      child: Icon(
                        Icons.chevron_left,
                        color: _navy,
                        size: 22.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool hasImage) {
    return Container(
      width: 58.w,
      height: 58.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _navy.withValues(alpha: 0.15),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: member.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _avatarPlaceholder(),
                errorWidget: (_, __, ___) => _avatarPlaceholder(),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return ColoredBox(
      color: _navy.withValues(alpha: 0.06),
      child: Icon(
        Icons.person_rounded,
        color: _navy.withValues(alpha: 0.55),
        size: 30.sp,
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: _grayText),
          SizedBox(width: 4.w),
          Text(
            label,
            style: AppFonts.lamaSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: _grayText,
            ),
          ),
        ],
      ),
    );
  }

  String _genderLabel(String gender) {
    final g = gender.trim().toLowerCase();
    if (g.contains('ذكر') || g == 'male' || g == 'm') return 'ذكر';
    if (g.contains('أنثى') || g.contains('انثى') || g == 'female' || g == 'f') {
      return 'أنثى';
    }
    return gender.trim();
  }
}
