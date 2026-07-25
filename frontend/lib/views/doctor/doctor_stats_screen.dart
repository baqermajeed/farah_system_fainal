import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/doctor_stats_controller.dart';

class DoctorStatsScreen extends GetView<DoctorStatsController> {
  const DoctorStatsScreen({super.key});

  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _heroStart = Color(0xFF1A4B84);
  static const Color _heroEnd = Color(0xFF4A90D9);
  static const Color _surface = Color(0xFFF4F7FB);
  static const Color _muted = Color(0xFF8A97A8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Obx(() {
        final isInitialLoading =
            controller.isLoading.value && controller.totalPatients == 0;

        if (controller.hasError.value && !controller.isLoading.value) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: 120.h),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: _muted, size: 48.sp),
                    SizedBox(height: 12.h),
                    Text(
                      'تعذر تحميل الإحصائيات',
                      style: AppFonts.lamaSans(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextButton(
                      onPressed: controller.loadStats,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          color: _heroStart,
          onRefresh: controller.loadStats,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeroHeader()),
              if (isInitialLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: _heroStart),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 32.h),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSummaryStrip(),
                      SizedBox(height: 20.h),
                      _buildKpiGrid(),
                      SizedBox(height: 24.h),
                      _buildSectionTitle('نشاط المواعيد الأسبوعي'),
                      SizedBox(height: 12.h),
                      _buildWeekChart(),
                      SizedBox(height: 24.h),
                      _buildSectionTitle('حالة المواعيد هذا الشهر'),
                      SizedBox(height: 12.h),
                      _buildStatusOverview(),
                      SizedBox(height: 24.h),
                      _buildSectionTitle('توزيع أنواع العلاج'),
                      SizedBox(height: 12.h),
                      _buildTreatmentDistribution(),
                      SizedBox(height: 24.h),
                      _buildInsightCard(),
                    ]),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_heroStart, _heroEnd],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30.h,
            left: -20.w,
            child: _decorCircle(120.w, 0.08),
          ),
          Positioned(
            bottom: 20.h,
            right: -30.w,
            child: _decorCircle(90.w, 0.1),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
              child: Column(
                children: [
                  Row(
                    textDirection: ui.TextDirection.ltr,
                    children: [
                      BackButtonWidget(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        assetPath: 'assets/images/back.png',
                      ),
                      Expanded(
                        child: Text(
                          'الإحصائيات والتقارير',
                          textAlign: TextAlign.center,
                          style: AppFonts.lamaSans(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 48.w),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    textDirection: ui.TextDirection.rtl,
                    children: [
                      Container(
                        width: 56.w,
                        height: 56.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                          size: 30.sp,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'لوحة الأداء',
                              style: AppFonts.lamaSans(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'نظرة شاملة على عيادتك ومرضاك',
                              style: AppFonts.lamaSans(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final completion = (controller.completionRate * 100).round();
    return Transform.translate(
      offset: Offset(0, -18.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          textDirection: ui.TextDirection.rtl,
          children: [
            _buildRingStat(
              value: '$completion%',
              label: 'نسبة الإنجاز',
              color: const Color(0xFF27AE60),
              progress: controller.completionRate,
            ),
            _verticalDivider(),
            _buildMiniStat(
              value: '${controller.monthAppointmentsCount}',
              label: 'مواعيد الشهر',
              icon: Icons.calendar_month_rounded,
              color: _heroStart,
            ),
            _verticalDivider(),
            _buildMiniStat(
              value: '${controller.todayAppointmentsCount}',
              label: 'مواعيد اليوم',
              icon: Icons.today_rounded,
              color: const Color(0xFFE74C3C),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 48.h,
      margin: EdgeInsets.symmetric(horizontal: 10.w),
      color: const Color(0xFFE8EDF3),
    );
  }

  Widget _buildRingStat({
    required String value,
    required String label,
    required Color color,
    required double progress,
  }) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 54.w,
            height: 54.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 5,
                    backgroundColor: color.withValues(alpha: 0.12),
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: AppFonts.lamaSans(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.lamaSans(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22.sp),
          SizedBox(height: 6.h),
          Text(
            value,
            style: AppFonts.lamaSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.lamaSans(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: AppFonts.lamaSans(
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
          color: _navy,
        ),
      ),
    );
  }

  Widget _buildKpiGrid() {
    final items = [
      _KpiItem(
        title: 'إجمالي المرضى',
        value: controller.totalPatientsLabel,
        icon: Icons.people_alt_rounded,
        colors: [const Color(0xFF4A90D9), const Color(0xFF6BB5F0)],
      ),
      _KpiItem(
        title: 'حالات علاج نشطة',
        value: '${controller.activeTreatments}',
        icon: Icons.medical_services_rounded,
        colors: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      ),
      _KpiItem(
        title: 'رسائل جديدة',
        value: '${controller.totalUnreadMessages}',
        icon: Icons.mark_chat_unread_rounded,
        colors: [const Color(0xFFFF9500), const Color(0xFFFFB347)],
      ),
      _KpiItem(
        title: 'مواعيد متأخرة',
        value: '${controller.lateAppointmentsCount}',
        icon: Icons.warning_amber_rounded,
        colors: [const Color(0xFFE74C3C), const Color(0xFFFF6B6B)],
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.15,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) => _KpiCard(item: items[index]),
    );
  }

  Widget _buildWeekChart() {
    final counts = controller.dailyAppointmentCounts;
    final labels = controller.weekDayLabels;
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: ui.TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر 7 أيام',
                style: AppFonts.lamaSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _heroStart.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'الإجمالي: ${counts.fold<int>(0, (a, b) => a + b)}',
                  style: AppFonts.lamaSans(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _heroStart,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 160.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = counts[index];
                final heightFactor =
                    maxCount == 0 ? 0.06 : (value / maxCount).clamp(0.06, 1.0);
                final isToday = index == 6;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$value',
                          style: AppFonts.lamaSans(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: isToday ? _heroStart : _muted,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: 100.h * heightFactor,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isToday
                                  ? [_heroStart, _heroEnd]
                                  : [
                                      _heroStart.withValues(alpha: 0.35),
                                      _heroEnd.withValues(alpha: 0.15),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.lamaSans(
                            fontSize: 9.sp,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w600,
                            color: isToday ? _navy : _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverview() {
    final completed = controller.completedAppointmentsCount;
    final pending = controller.pendingAppointmentsCount;
    final late = controller.lateAppointmentsCount;
    final total = math.max(completed + pending + late, 1);

    final segments = [
      _StatusSegment('مكتملة', completed, const Color(0xFF27AE60)),
      _StatusSegment('قيد الانتظار', pending, _heroStart),
      _StatusSegment('متأخرة', late, const Color(0xFFE74C3C)),
    ];

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: SizedBox(
              height: 14.h,
              child: Row(
                children: segments
                    .where((s) => s.count > 0)
                    .map(
                      (s) => Expanded(
                        flex: s.count,
                        child: Container(color: s.color),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          ...segments.map(
            (segment) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: segment.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      segment.label,
                      style: AppFonts.lamaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                  ),
                  Text(
                    '${segment.count}',
                    style: AppFonts.lamaSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: segment.color,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '(${((segment.count / total) * 100).round()}%)',
                    style: AppFonts.lamaSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentDistribution() {
    final distribution = controller.treatmentDistribution;
    if (distribution.isEmpty) {
      return _emptyCard('لا توجد بيانات علاج بعد');
    }

    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    final colors = [
      _heroStart,
      const Color(0xFF27AE60),
      const Color(0xFF8B5CF6),
      const Color(0xFFFF9500),
      const Color(0xFFE74C3C),
    ];

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: distribution.entries.toList().asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final percent = total == 0 ? 0.0 : item.value / total;
          final color = colors[index % colors.length];

          return Padding(
            padding: EdgeInsets.only(bottom: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Text(
                        item.key,
                        style: AppFonts.lamaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.value} مريض',
                      style: AppFonts.lamaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Stack(
                  children: [
                    Container(
                      height: 10.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2F7),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent.clamp(0.04, 1.0),
                      child: Container(
                        height: 10.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color.withValues(alpha: 0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInsightCard() {
    final insights = <String>[];
    if (controller.lateAppointmentsCount > 0) {
      insights.add(
        'لديك ${controller.lateAppointmentsCount} موعد متأخر — يُنصح بالتواصل مع المرضى.',
      );
    }
    if (controller.totalUnreadMessages > 0) {
      insights.add(
        'لديك ${controller.totalUnreadMessages} رسالة غير مقروءة بانتظار الرد.',
      );
    }
    if (controller.todayAppointmentsCount > 0) {
      insights.add(
        'لديك ${controller.todayAppointmentsCount} موعد مجدول اليوم.',
      );
    }
    if (insights.isEmpty) {
      insights.add('أداؤك ممتاز! لا توجد تنبيهات عاجلة حالياً.');
    }

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _heroStart.withValues(alpha: 0.08),
            _heroEnd.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _heroStart.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: ui.TextDirection.rtl,
            children: [
              Icon(Icons.lightbulb_rounded, color: _heroStart, size: 22.sp),
              SizedBox(width: 8.w),
              Text(
                'ملخص ذكي',
                style: AppFonts.lamaSans(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...insights.map(
            (text) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: ui.TextDirection.rtl,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 6.h),
                    width: 6.w,
                    height: 6.w,
                    decoration: const BoxDecoration(
                      color: _heroStart,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      text,
                      style: AppFonts.lamaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: _navy.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppFonts.lamaSans(
          fontSize: 14.sp,
          color: _muted,
        ),
      ),
    );
  }
}

class _KpiItem {
  const _KpiItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final _KpiItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: item.colors,
        ),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: item.colors.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: ui.TextDirection.rtl,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(item.icon, color: Colors.white, size: 20.sp),
          ),
          const Spacer(),
          Text(
            item.value,
            style: AppFonts.lamaSans(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            item.title,
            style: AppFonts.lamaSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSegment {
  const _StatusSegment(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}
