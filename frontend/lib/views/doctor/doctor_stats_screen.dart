import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_back_button.dart';
import 'package:farah_sys_final/controllers/doctor_stats_controller.dart';
import 'package:farah_sys_final/models/doctor_stats_model.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_glass_card.dart';
import 'package:farah_sys_final/core/widgets/app_skeleton.dart';

class DoctorStatsScreen extends GetView<DoctorStatsController> {
  const DoctorStatsScreen({super.key});

  static const _headerGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0A1628), Color(0xFF132238), Color(0xFF1E4D8C)],
    stops: [0.0, 0.55, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.doctorSurface,
      body: Obx(() {
        if (controller.isLoading.value) {
          return Column(
            children: [
              _StatsHeader(onBack: Get.back),
              const Expanded(
                child: SkeletonStatsPage(),
              ),
            ],
          );
        }

        if (controller.hasError.value) {
          return Column(
            children: [
              _StatsHeader(onBack: Get.back),
              Expanded(child: _ErrorBody(onRetry: controller.loadStats)),
            ],
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.loadStats,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _StatsHeader(onBack: Get.back)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 36.h),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 16.h),
                    _sectionTitle('المرضى'),
                    SizedBox(height: 12.h),
                    _PatientMetricsRow(controller: controller),
                    SizedBox(height: 24.h),
                    _sectionTitle('حالة المرضى'),
                    SizedBox(height: 12.h),
                    _PatientStatusCard(controller: controller),
                    if (controller.showDemographics) ...[
                      SizedBox(height: 24.h),
                      _sectionTitle('الديموغرافيا'),
                      SizedBox(height: 12.h),
                      _DemographicsCard(controller: controller),
                    ],
                    SizedBox(height: 24.h),
                    _sectionTitle('نشاط المواعيد الأسبوعي'),
                    SizedBox(height: 12.h),
                    _WeekChart(controller: controller),
                    SizedBox(height: 24.h),
                    _sectionTitle('توزيع أنواع العلاج'),
                    SizedBox(height: 12.h),
                    _TreatmentCard(controller: controller),
                  ]),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: AppFonts.lamaSans(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }

}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: DoctorStatsScreen._headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 24.h),
          child: Column(
            children: [
              Row(
                textDirection: ui.TextDirection.ltr,
                children: [
                  const DoctorBackButton(),
                  Expanded(
                    child: Text(
                      'الإحصائيات',
                      textAlign: TextAlign.center,
                      style: AppFonts.lamaSans(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                  SizedBox(width: 44.w),
                ],
              ),
              SizedBox(height: 18.h),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة التحليلات',
                      style: AppFonts.lamaSans(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'رؤية استراتيجية لعيادتك',
                      style: AppFonts.lamaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientMetricsRow extends StatelessWidget {
  const _PatientMetricsRow({required this.controller});

  final DoctorStatsController controller;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _PatientMetricData(
        title: 'إجمالي المرضى',
        value: controller.totalPatientsLabel,
        icon: Icons.people_alt_rounded,
        color: AppColors.primary,
      ),
      _PatientMetricData(
        title: 'جدد اليوم',
        value: '${controller.newPatientsToday}',
        icon: Icons.person_add_alt_1_rounded,
        color: AppColors.doctorAccentGreen,
      ),
      _PatientMetricData(
        title: 'جدد الشهر',
        value: '${controller.newPatientsMonth}',
        icon: Icons.trending_up_rounded,
        color: AppColors.doctorAccentPurple,
      ),
    ];

    return Row(
      textDirection: TextDirection.rtl,
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) SizedBox(width: 10.w),
          Expanded(child: _PatientMetricTile(metric: metrics[i])),
        ],
      ],
    );
  }
}

class _PatientMetricTile extends StatelessWidget {
  const _PatientMetricTile({required this.metric});

  final _PatientMetricData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: metric.color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: metric.color.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  metric.color,
                  metric.color.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(metric.icon, color: Colors.white, size: 18.sp),
          ),
          SizedBox(height: 10.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              metric.value,
              style: AppFonts.lamaSans(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            metric.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppFonts.lamaSans(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.doctorLabel,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientMetricData {
  const _PatientMetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _DemographicsCard extends StatelessWidget {
  const _DemographicsCard({required this.controller});

  final DoctorStatsController controller;

  Color _genderColor(String key) {
    return key == 'female' ? const Color(0xFFEC4899) : AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return DoctorGlassCard(
      child: Column(
        children: [
          if (controller.genderItems.isNotEmpty)
            Row(
              textDirection: TextDirection.rtl,
              children: [
                for (var i = 0; i < controller.genderItems.length; i++) ...[
                  if (i > 0) SizedBox(width: 12.w),
                  Expanded(
                    child: _genderTile(
                      controller.genderItems[i],
                      _genderColor(controller.genderItems[i].key),
                    ),
                  ),
                ],
              ],
            ),
          if (controller.ageBuckets.isNotEmpty) ...[
            if (controller.genderItems.isNotEmpty) ...[
              SizedBox(height: 16.h),
              const Divider(height: 1),
              SizedBox(height: 12.h),
            ],
            ...controller.ageBuckets.map((bucket) {
              final barValue = (bucket.percent / 100).clamp(0.04, 1.0);
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    SizedBox(
                      width: 48.w,
                      child: Text(
                        bucket.label,
                        style: AppFonts.lamaSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: barValue,
                          minHeight: 6.h,
                          backgroundColor: AppColors.divider,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${bucket.count}',
                      style: AppFonts.lamaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _genderTile(DoctorStatsBreakdownItem item, Color color) {
    final barValue = (item.percent / 100).clamp(0.04, 1.0);
    return Column(
      children: [
        Text(
          '${item.count}',
          style: AppFonts.lamaSans(
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          item.label,
          style: AppFonts.lamaSans(fontSize: 11.sp, color: AppColors.doctorLabel),
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: barValue,
            minHeight: 4.h,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.controller});

  final DoctorStatsController controller;

  @override
  Widget build(BuildContext context) {
    final days = controller.weeklyAppointments;
    final maxCount = days.fold<int>(0, (max, day) => math.max(max, day.count));
    final total = controller.weeklyAppointmentsTotal;

    return DoctorGlassCard(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر 7 أيام',
                style: AppFonts.lamaSans(
                  fontSize: 12.sp,
                  color: AppColors.doctorLabel,
                ),
              ),
              Text(
                'الإجمالي: $total',
                style: AppFonts.lamaSans(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 130.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final factor = maxCount == 0
                    ? 0.08
                    : (day.count / maxCount).clamp(0.08, 1.0);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${day.count}',
                          style: AppFonts.lamaSans(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: day.isToday
                                ? AppColors.primary
                                : AppColors.doctorLabel,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          height: 80.h * factor,
                          decoration: BoxDecoration(
                            color: day.isToday
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          day.dayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.lamaSans(
                            fontSize: 8.sp,
                            fontWeight:
                                day.isToday ? FontWeight.w700 : FontWeight.w500,
                            color: AppColors.doctorLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientStatusCard extends StatelessWidget {
  const _PatientStatusCard({required this.controller});

  final DoctorStatsController controller;

  @override
  Widget build(BuildContext context) {
    return _StatusBreakdownCard(
      items: controller.patientStatusItems,
      colorForKey: _patientStatusColor,
    );
  }

  Color _patientStatusColor(String key) {
    switch (key) {
      case 'active':
        return AppColors.doctorAccentGreen;
      case 'inactive':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({
    required this.items,
    required this.colorForKey,
  });

  final List<DoctorStatsBreakdownItem> items;
  final Color Function(String key) colorForKey;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((item) => item.count > 0).toList();

    return DoctorGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visibleItems.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: SizedBox(
                height: 12.h,
                child: Row(
                  children: visibleItems
                      .map(
                        (item) => Expanded(
                          flex: item.count,
                          child: Container(color: colorForKey(item.key)),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            SizedBox(height: 16.h),
          ],
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == items.length - 1;
            final color = colorForKey(item.key);

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppFonts.lamaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${item.count}',
                    style: AppFonts.lamaSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '(${item.percent}%)',
                    style: AppFonts.lamaSans(
                      fontSize: 11.sp,
                      color: AppColors.doctorLabel,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TreatmentCard extends StatelessWidget {
  const _TreatmentCard({required this.controller});

  final DoctorStatsController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.treatmentItems;
    if (items.isEmpty) {
      return DoctorGlassCard(
        child: Text(
          'لا توجد بيانات علاج بعد',
          style: AppFonts.lamaSans(
            fontSize: 14.sp,
            color: AppColors.doctorLabel,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final colors = [
      AppColors.primary,
      AppColors.doctorAccentGreen,
      AppColors.doctorAccentPurple,
      AppColors.doctorAccentOrange,
      AppColors.secondary,
    ];

    return DoctorGlassCard(
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final color = colors[index % colors.length];
          final barValue = (item.percent / 100).clamp(0.04, 1.0);

          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      '${item.count} مريض',
                      style: AppFonts.lamaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.type,
                        style: AppFonts.lamaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: barValue,
                    minHeight: 6.h,
                    backgroundColor: AppColors.divider,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 80.h),
        Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 48.sp),
        SizedBox(height: 16.h),
        Text(
          'تعذر تحميل البيانات',
          textAlign: TextAlign.center,
          style: AppFonts.lamaSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'إعادة المحاولة',
            style: AppFonts.lamaSans(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
