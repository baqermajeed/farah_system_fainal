import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/controllers/doctor_stats_controller.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_glass_card.dart';

class DoctorStatsTab extends GetView<DoctorStatsController> {
  const DoctorStatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.doctorSurface,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.loadStats,
        child: Obx(() {
          if (controller.isLoading.value && controller.totalPatients == 0) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 120.h),
                Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 100.h),
            children: [
              Text(
                'التقارير والإحصائيات',
                style: AppFonts.lamaSans(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 20.h),
              _buildMetricsGrid(),
              SizedBox(height: 24.h),
              Text(
                'مواعيد الأسبوع',
                style: AppFonts.lamaSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 12.h),
              _buildWeekChart(),
              SizedBox(height: 24.h),
              Text(
                'توزيع أنواع العلاج',
                style: AppFonts.lamaSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 12.h),
              _buildTreatmentDistribution(),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = [
      _MetricData(
        title: 'إجمالي المرضى',
        value: controller.totalPatientsLabel,
        icon: Icons.people_alt_rounded,
        color: AppColors.primary,
      ),
      _MetricData(
        title: 'مواعيد اليوم',
        value: '${controller.todayAppointmentsCount}',
        icon: Icons.calendar_today_rounded,
        color: AppColors.doctorAccentGreen,
      ),
      _MetricData(
        title: 'حالات علاج',
        value: '${controller.activeTreatments}',
        icon: Icons.medical_information_rounded,
        color: AppColors.doctorAccentPurple,
      ),
      _MetricData(
        title: 'رسائل جديدة',
        value: '${controller.totalUnreadMessages}',
        icon: Icons.mark_chat_unread_rounded,
        color: AppColors.doctorAccentOrange,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.35,
      ),
      itemCount: metrics.length,
      itemBuilder: (_, index) => _MetricCard(metric: metrics[index]),
    );
  }

  Widget _buildWeekChart() {
    final counts = controller.dailyAppointmentCounts;
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    const days = ['أ', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

    return DoctorGlassCard(
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 16.h),
      child: SizedBox(
        height: 140.h,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (index) {
            final value = counts[index];
            final heightFactor =
                maxCount == 0 ? 0.08 : (value / maxCount).clamp(0.08, 1.0);
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
                        color: AppColors.doctorLabel,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 80.h * heightFactor,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      days[index],
                      style: AppFonts.lamaSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.doctorLabel,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTreatmentDistribution() {
    final distribution = controller.treatmentDistribution;
    if (distribution.isEmpty) {
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

    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    final colors = [
      AppColors.primary,
      AppColors.doctorAccentGreen,
      AppColors.doctorAccentPurple,
      AppColors.doctorAccentOrange,
      AppColors.secondary,
    ];

    return DoctorGlassCard(
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
              textDirection: TextDirection.rtl,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      '${(percent * 100).round()}%',
                      style: AppFonts.lamaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.key,
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
                  borderRadius: BorderRadius.circular(6.r),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8.h,
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

class _MetricData {
  const _MetricData({
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return DoctorGlassCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(metric.icon, color: metric.color, size: 22.sp),
          ),
          const Spacer(),
          Text(
            metric.value,
            style: AppFonts.lamaSans(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 4.h),
          Text(
            metric.title,
            style: AppFonts.lamaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.doctorLabel,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
