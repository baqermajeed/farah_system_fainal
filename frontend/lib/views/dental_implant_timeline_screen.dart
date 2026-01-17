import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

class DentalImplantTimelineScreen extends StatelessWidget {
  const DentalImplantTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    
    // مراحل زراعة الأسنان للمريض
    final stages = [
      ImplantStage(
        title: 'مرحلة زراعة الاسنان',
        isCompleted: true,
        appointmentDate: DateTime(2025, 12, 11, 16, 0),
      ),
      ImplantStage(
        title: 'مرحلة رفع خيط العملية',
        isCompleted: true,
        appointmentDate: DateTime(2025, 12, 11, 16, 0),
        description: 'موعدك لرفع خيط العملية سيكون في',
      ),
      ImplantStage(
        title: 'متابعة حالة المريض',
        isCompleted: true,
        appointmentDate: DateTime(2025, 12, 11, 16, 0),
        description: 'موعد متابعة حالتك سيكون في',
      ),
      ImplantStage(
        title: 'المتابعة الثانية لحالة المريض',
        isCompleted: false,
        appointmentDate: DateTime(2025, 12, 11, 16, 0),
        description: 'موعد متابعة حالتك سيكون في',
      ),
      ImplantStage(
        title: 'التقاط طبعة الاسنان',
        isCompleted: false,
        appointmentDate: null,
      ),
      ImplantStage(
        title: 'التركيب التجريبي الاول',
        isCompleted: false,
        appointmentDate: null,
      ),
      ImplantStage(
        title: 'التركيب التجريبي الثاني',
        isCompleted: false,
        appointmentDate: null,
      ),
      ImplantStage(
        title: 'التركيب النهائي الاخير',
        isCompleted: false,
        appointmentDate: null,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: BackButtonWidget(),
              ),
            ),
            // Title Section
            Padding(
              // Keep icon spacing from the LEFT, but control text start from the RIGHT separately.
              padding: EdgeInsets.only(left: 140.w),
              child: Directionality(
                // Force Arabic layout: text starts from RIGHT, icon stays on LEFT.
                textDirection: ui.TextDirection.rtl,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'مواعيد زراعة اسنانك',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'مواعيدك مع د. مهند المالكي',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Container(
                      width: 48.w,
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.medical_services,
                        color: AppColors.white,
                        size: 24.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            // Timeline
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                itemCount: stages.length,
                itemBuilder: (context, index) {
                  final stage = stages[index];
                  final isLast = index == stages.length - 1;
                  
                  return _buildTimelineItem(
                    stage: stage,
                    isLast: isLast,
                    hasNextCompleted: index < stages.length - 1 && stages[index + 1].isCompleted,
                  );
                },
              ),
            ),
            // Info Box
            Container(
              margin: EdgeInsets.all(16.w),
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/first_aid_kit.png',
                    width: 50.w,
                    height: 50.w,
                    fit: BoxFit.contain,
                    // Prevent OOM/crashes by decoding a small version of the large asset.
                    cacheWidth: 200,
                    cacheHeight: 200,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الفترة التقريبة لانتهاء مراحل الزراعة بشكل كامل',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color:const ui.Color.fromARGB(255, 67, 67, 66),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'تكون من 4 الى 5 اشهر',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const ui.Color.fromARGB(255, 67, 67, 66),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required ImplantStage stage,
    required bool isLast,
    required bool hasNextCompleted,
  }) {
    final dateFormat = DateFormat('d/M/yyyy');
    final timeFormat = DateFormat('h:mm a');
    
    // Format day name manually
    String getDayName(DateTime date) {
      final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      return days[date.weekday % 7];
    }
    
    return Row(
      // Force the timeline bar to stay on the LEFT, regardless of app RTL.
      textDirection: ui.TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline Line and Circle
        Column(
          children: [
            // Circle
            Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stage.isCompleted ? AppColors.primary : AppColors.white,
                border: Border.all(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              child: stage.isCompleted
                  ? Icon(
                      Icons.check,
                      color: AppColors.white,
                      size: 20.sp,
                    )
                  : null,
            ),
            // Line
            if (!isLast)
              Container(
                width: 2,
                height: 80.h,
                color: stage.isCompleted || hasNextCompleted
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.3),
              ),
          ],
        ),
        SizedBox(width: 16.w),
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stage.title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: stage.isCompleted
                        ? AppColors.primary.withValues(alpha: 0.7)
                        : AppColors.textPrimary,
                  ),
                ),
                if (stage.appointmentDate != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    stage.description ?? 'موعدك سيكون في',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'تاريخ ${dateFormat.format(stage.appointmentDate!)} يوم ${getDayName(stage.appointmentDate!)} الساعة ${timeFormat.format(stage.appointmentDate!)}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ImplantStage {
  final String title;
  final bool isCompleted;
  final DateTime? appointmentDate;
  final String? description;

  ImplantStage({
    required this.title,
    required this.isCompleted,
    this.appointmentDate,
    this.description,
  });
}

