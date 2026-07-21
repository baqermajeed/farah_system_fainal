import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/views/patient_browse_tips.dart';

class PatientBrowseScreen extends StatelessWidget {
  const PatientBrowseScreen({super.key});

  static const String _backAsset = 'assets/icon/backblack.png';
  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _deepNavy = Color(0xFF0F2744);
  static const Color _accent = Color(0xFF5B9FCC);
  static const Color _grayText = Color(0xFF8A97A8);
  static const Color _surface = Color(0xFFF7F9FC);

  List<PatientBrowseTip> get _tips => kPatientBrowseTips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      textTheme: AppFonts.textTheme(Theme.of(context).textTheme),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
                  children: [
                    _buildIntroBanner(),
                    SizedBox(height: 20.h),
                    _buildFeaturedTip(_tips.first),
                    SizedBox(height: 22.h),
                    Row(
                      children: [
                        Text(
                          'نصائح للعناية',
                          style: AppFonts.lamaSans(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_tips.length} نصيحة',
                          style: AppFonts.lamaSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _grayText,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    ...List.generate(_tips.length - 1, (i) {
                      final tipIndex = i + 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _buildTipCard(
                          _tips[tipIndex],
                          index: tipIndex + 1,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          const BackButtonWidget(assetPath: _backAsset),
          Expanded(
            child: Text(
              'معلومات طبية',
              textAlign: TextAlign.center,
              style: AppFonts.lamaSans(
                fontSize: 18.sp,
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

  Widget _buildIntroBanner() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _deepNavy,
            _navy,
            _accent.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'صحة الفم والأسنان',
                    style: AppFonts.lamaSans(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'نصائح مختصرة\nلحماية ابتسامتك',
                  style: AppFonts.lamaSans(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'معلومات عملية من عيادة فرح — سهلة التطبيق يومياً.',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            width: 78.w,
            height: 78.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20.r),
            ),
            padding: EdgeInsets.all(10.w),
            child: Image.asset(
              'assets/images/clean 1.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedTip(PatientBrowseTip tip) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14.sp, color: _accent),
                    SizedBox(width: 6.w),
                    Text(
                      'نصيحة مميزة',
                      style: AppFonts.lamaSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                tip.title,
                style: AppFonts.lamaSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: _grayText,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  tip.text,
                  style: AppFonts.lamaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                    height: 1.55,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                width: 88.w,
                height: 88.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6FA),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                padding: EdgeInsets.all(8.w),
                child: Image.asset(tip.image, fit: BoxFit.contain),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(PatientBrowseTip tip, {required int index}) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: AppFonts.lamaSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: AppFonts.lamaSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  tip.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FA),
              borderRadius: BorderRadius.circular(14.r),
            ),
            padding: EdgeInsets.all(6.w),
            child: Image.asset(tip.image, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}
