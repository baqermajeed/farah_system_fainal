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

  // Premium palette — deep navy + refined accents
  static const Color _ink = Color(0xFF0A1628);
  static const Color _inkMid = Color(0xFF132238);
  static const Color _royal = Color(0xFF1E4D8C);
  static const Color _azure = Color(0xFF3B82F6);
  static const Color _sky = Color(0xFF60A5FA);
  static const Color _gold = Color(0xFFD4A853);
  static const Color _mint = Color(0xFF10B981);
  static const Color _coral = Color(0xFFF43F5E);
  static const Color _violet = Color(0xFF8B5CF6);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _surface = Color(0xFFF0F4FA);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _text = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: RefreshIndicator(
        color: _azure,
        backgroundColor: Colors.white,
        onRefresh: controller.loadStats,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildPremiumHeader()),
            Obx(() => _buildBodySliver()),
          ],
        ),
      ),
    );
  }

  Widget _buildBodySliver() {
    if (controller.isLoading.value) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: SizedBox(
            width: 36.w,
            height: 36.w,
            child: const CircularProgressIndicator(
              color: _azure,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    if (controller.hasError.value) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(),
      );
    }

    if (controller.revealedSections.value <= 0) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: SizedBox(
            width: 36.w,
            height: 36.w,
            child: const CircularProgressIndicator(
              color: _azure,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 36.h),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _sectionAt(index),
          childCount: controller.revealedSections.value,
        ),
      ),
    );
  }

  Widget _sectionAt(int index) {
    switch (index) {
      case 0:
        return _buildHeroCard();
      case 1:
        return SizedBox(height: 22.h);
      case 2:
        return _buildBentoGrid();
      case 3:
        return SizedBox(height: 26.h);
      case 4:
        return _sectionHeader(
          'تدفق المرضى',
          'المرضى الجدد المحوّلون',
          Icons.person_add_alt_1_rounded,
          _mint,
        );
      case 5:
        return Padding(
          padding: EdgeInsets.only(top: 14.h),
          child: _buildNewPatientsRow(),
        );
      case 6:
        return SizedBox(height: 26.h);
      case 7:
        return _sectionHeader(
          'صحة السجل',
          'حالة المرضى الحالية',
          Icons.favorite_rounded,
          _coral,
        );
      case 8:
        return Padding(
          padding: EdgeInsets.only(top: 14.h),
          child: _buildPatientStatusCards(),
        );
      case 9:
        return SizedBox(height: 26.h);
      case 10:
        return _sectionHeader(
          'الديموغرافيا',
          'الجنس والفئات العمرية',
          Icons.people_rounded,
          _violet,
        );
      case 11:
        return Padding(
          padding: EdgeInsets.only(top: 14.h),
          child: _buildDemographicsBlock(),
        );
      case 12:
        return SizedBox(height: 26.h);
      case 13:
        return _sectionHeader(
          'تحليل المواعيد',
          'النشاط الأسبوعي والشهري',
          Icons.calendar_month_rounded,
          _azure,
        );
      case 14:
        return Padding(
          padding: EdgeInsets.only(top: 14.h),
          child: Column(
            children: [
              _buildWeekChart(),
              SizedBox(height: 16.h),
              _buildAppointmentStatus(),
            ],
          ),
        );
      case 15:
        return Padding(
          padding: EdgeInsets.only(top: 26.h),
          child: Column(
            children: [
              _sectionHeader(
                'محفظة العلاج',
                'توزيع أنواع العلاج',
                Icons.medical_services_rounded,
                _gold,
              ),
              SizedBox(height: 14.h),
              _buildTreatmentList(),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildPremiumHeader() {
    return Container(
      height: 200.h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_ink, _inkMid, _royal],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -40.h, right: -30.w, child: _orb(160.w, _azure, 0.12)),
          Positioned(bottom: 10.h, left: -20.w, child: _orb(100.w, _gold, 0.08)),
          Positioned(top: 60.h, left: 40.w, child: _orb(60.w, _mint, 0.06)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 0),
              child: Column(
                children: [
                  Row(
                    textDirection: ui.TextDirection.ltr,
                    children: [
                      Transform.rotate(
                        angle: math.pi,
                        child: BackButtonWidget(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          assetPath: 'assets/images/back.png',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'الإحصائيات',
                          textAlign: TextAlign.center,
                          style: AppFonts.lamaSans(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      SizedBox(width: 44.w),
                    ],
                  ),
                  SizedBox(height: 22.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لوحة التحليلات',
                          style: AppFonts.lamaSans(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'رؤية استراتيجية لعيادتك',
                          style: AppFonts.lamaSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
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

  Widget _orb(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final completion = (controller.completionRate * 100).round();
    return Transform.translate(
      offset: Offset(0, -28.h),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFD)],
          ),
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: _azure.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          textDirection: ui.TextDirection.rtl,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إجمالي المرضى',
                    style: AppFonts.lamaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    controller.totalPatientsLabel,
                    style: AppFonts.lamaSans(
                      fontSize: 42.sp,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      _heroChip(
                        '${controller.todayAppointmentsCount}',
                        'اليوم',
                        _coral,
                      ),
                      SizedBox(width: 8.w),
                      _heroChip(
                        '${controller.monthAppointmentsCount}',
                        'الشهر',
                        _azure,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w),
            _buildCompletionRing(completion),
          ],
        ),
      ),
    );
  }

  Widget _heroChip(String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppFonts.lamaSans(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: AppFonts.lamaSans(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionRing(int percent) {
    return SizedBox(
      width: 80.w,
      height: 80.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: controller.completionRate.clamp(0.0, 1.0),
              strokeWidth: 6,
              backgroundColor: _mint.withValues(alpha: 0.12),
              color: _mint,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: AppFonts.lamaSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: _mint,
                ),
              ),
              Text(
                'إنجاز',
                style: AppFonts.lamaSans(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Bento grid ───────────────────────────────────────────────────────────

  Widget _buildBentoGrid() {
    final items = [
      _BentoItem(
        'جدد اليوم',
        '${controller.newPatientsToday}',
        Icons.bolt_rounded,
        [_mint, const Color(0xFF059669)],
      ),
      _BentoItem(
        'جدد الشهر',
        '${controller.newPatientsMonth}',
        Icons.trending_up_rounded,
        [_violet, const Color(0xFF6D28D9)],
      ),
      _BentoItem(
        'نشطون',
        '${controller.activePatients}',
        Icons.verified_rounded,
        [_azure, _royal],
      ),
      _BentoItem(
        'قيد المراجعة',
        '${controller.pendingPatients}',
        Icons.hourglass_top_rounded,
        [_amber, const Color(0xFFD97706)],
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.55,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _BentoCard(item: items[i]),
    );
  }

  // ─── New patients ─────────────────────────────────────────────────────────

  Widget _buildNewPatientsRow() {
    return Row(
      children: [
        Expanded(
          child: _accentStatCard(
            value: '${controller.newPatientsToday}',
            label: 'محوّلون اليوم',
            sublabel: 'مريض جديد',
            gradient: [_mint, const Color(0xFF047857)],
            icon: Icons.wb_sunny_rounded,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _accentStatCard(
            value: '${controller.newPatientsMonth}',
            label: 'محوّلون الشهر',
            sublabel: 'مريض جديد',
            gradient: [_royal, _azure],
            icon: Icons.date_range_rounded,
          ),
        ),
      ],
    );
  }

  Widget _accentStatCard({
    required String value,
    required String label,
    required String sublabel,
    required List<Color> gradient,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22.sp),
          const Spacer(),
          Text(
            value,
            style: AppFonts.lamaSans(
              fontSize: 32.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: AppFonts.lamaSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Text(
            sublabel,
            style: AppFonts.lamaSans(
              fontSize: 9.sp,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Patient status ───────────────────────────────────────────────────────

  Widget _buildPatientStatusCards() {
    final items = [
      ('نشط', controller.activePatients, _mint, Icons.check_circle_rounded),
      ('مراجعة', controller.pendingPatients, _amber, Icons.pending_rounded),
      ('غير نشط', controller.inactivePatients, _coral, Icons.remove_circle_rounded),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: item == items.last ? 0 : 8.w),
            child: _statusPill(item.$1, item.$2, item.$3, item.$4),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusPill(String label, int count, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(height: 10.h),
          Text(
            '$count',
            style: AppFonts.lamaSans(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          Text(
            label,
            style: AppFonts.lamaSans(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Demographics ─────────────────────────────────────────────────────────

  Widget _buildDemographicsBlock() {
    final totalGender = math.max(
      controller.maleCount + controller.femaleCount,
      1,
    );
    final femalePct = controller.femaleCount / totalGender;
    final malePct = controller.maleCount / totalGender;

    return _glassCard(
      child: Column(
        children: [
          Row(
            textDirection: ui.TextDirection.rtl,
            children: [
              Expanded(
                child: _genderStat(
                  'إناث',
                  controller.femaleCount,
                  femalePct,
                  const Color(0xFFEC4899),
                  Icons.female_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 60.h,
                color: const Color(0xFFE2E8F0),
                margin: EdgeInsets.symmetric(horizontal: 12.w),
              ),
              Expanded(
                child: _genderStat(
                  'ذكور',
                  controller.maleCount,
                  malePct,
                  _azure,
                  Icons.male_rounded,
                ),
              ),
            ],
          ),
          if (controller.ageBuckets.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Divider(color: _muted.withValues(alpha: 0.2), height: 1),
            ),
            ...controller.ageBuckets.asMap().entries.map((entry) {
              final i = entry.key;
              final bucket = entry.value;
              final maxAge = controller.ageBuckets
                  .fold<int>(0, (m, e) => math.max(m, e.count));
              final pct = maxAge == 0 ? 0.0 : bucket.count / maxAge;
              final colors = [_azure, _mint, _violet, _amber, _coral];
              return _ageBar(
                bucket.label,
                bucket.count,
                pct,
                colors[i % colors.length],
                isLast: i == controller.ageBuckets.length - 1,
              );
            }),
          ] else
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Text(
                'لا توجد بيانات عمرية',
                style: AppFonts.lamaSans(fontSize: 12.sp, color: _muted),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _genderStat(
    String label,
    int count,
    double pct,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26.sp),
        SizedBox(height: 8.h),
        Text(
          '$count',
          style: AppFonts.lamaSans(
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        Text(
          label,
          style: AppFonts.lamaSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        SizedBox(height: 8.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: pct.clamp(0.04, 1.0),
            minHeight: 4.h,
            backgroundColor: color.withValues(alpha: 0.1),
            color: color,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '${(pct * 100).round()}%',
          style: AppFonts.lamaSans(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _ageBar(
    String label,
    int count,
    double pct,
    Color color, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          SizedBox(
            width: 52.w,
            child: Text(
              label,
              style: AppFonts.lamaSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F7),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.03, 1.0),
                  child: Container(
                    height: 8.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.5)],
                      ),
                      borderRadius: BorderRadius.circular(6.r),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            '$count',
            style: AppFonts.lamaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Week chart ───────────────────────────────────────────────────────────

  Widget _buildWeekChart() {
    final counts = controller.dailyAppointmentCounts;
    final labels = controller.weekDayLabels;
    final maxCount = counts.fold<int>(0, math.max);
    final total = counts.fold<int>(0, (a, b) => a + b);

    return _glassCard(
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
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_azure.withValues(alpha: 0.15), _sky.withValues(alpha: 0.08)],
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: _azure.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'الإجمالي: $total',
                  style: AppFonts.lamaSans(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _royal,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 150.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = counts[index];
                final factor =
                    maxCount == 0 ? 0.05 : (value / maxCount).clamp(0.05, 1.0);
                final isToday = index == 6;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$value',
                          style: AppFonts.lamaSans(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: isToday ? _azure : _muted,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          height: 100.h * factor,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isToday
                                  ? [_royal, _sky]
                                  : [
                                      _azure.withValues(alpha: 0.25),
                                      _sky.withValues(alpha: 0.08),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.lamaSans(
                            fontSize: 8.sp,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w500,
                            color: isToday ? _text : _muted,
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

  // ─── Appointment status ───────────────────────────────────────────────────

  Widget _buildAppointmentStatus() {
    final segments = [
      _Seg('مكتملة', controller.completedAppointmentsCount, _mint),
      _Seg('انتظار', controller.pendingAppointmentsCount, _azure),
      _Seg('متأخرة', controller.lateAppointmentsCount, _coral),
    ];
    final total = math.max(
      segments.fold<int>(0, (s, e) => s + e.count),
      1,
    );

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حالة المواعيد — هذا الشهر',
            style: AppFonts.lamaSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          SizedBox(height: 14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: SizedBox(
              height: 12.h,
              child: Row(
                children: segments
                    .where((s) => s.count > 0)
                    .map(
                      (s) => Expanded(
                        flex: s.count,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [s.color, s.color.withValues(alpha: 0.7)],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          ...segments.map(
            (s) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: s.color.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      s.label,
                      style: AppFonts.lamaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: _text,
                      ),
                    ),
                  ),
                  Text(
                    '${s.count}',
                    style: AppFonts.lamaSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: s.color,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '${((s.count / total) * 100).round()}%',
                    style: AppFonts.lamaSans(
                      fontSize: 11.sp,
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

  // ─── Treatment list ───────────────────────────────────────────────────────

  Widget _buildTreatmentList() {
    final distribution = controller.treatmentDistribution;
    if (distribution.isEmpty) {
      return _glassCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Text(
              'لا توجد بيانات علاج',
              style: AppFonts.lamaSans(fontSize: 13.sp, color: _muted),
            ),
          ),
        ),
      );
    }

    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    final colors = [_royal, _mint, _violet, _amber, _coral, _azure];
    final entries = distribution.entries.toList();

    return Column(
      children: entries.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final item = entry.value;
        final color = colors[entry.key % colors.length];
        final pct = total == 0 ? 0.0 : item.value / total;

        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: _glassCard(
            padding: EdgeInsets.all(16.w),
            child: Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.6)],
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: AppFonts.lamaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
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
                                color: _text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Text(
                            '${item.value} مريض',
                            style: AppFonts.lamaSans(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.04, 1.0),
                          minHeight: 5.h,
                          backgroundColor: color.withValues(alpha: 0.1),
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────

  Widget _sectionHeader(
    String title,
    String subtitle,
    IconData icon,
    Color accent,
  ) {
    return Row(
      textDirection: ui.TextDirection.rtl,
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.lamaSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              Text(
                subtitle,
                style: AppFonts.lamaSans(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 160.h),
        Center(
          child: Column(
            children: [
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: _coral.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded, color: _coral, size: 32.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                'تعذر تحميل البيانات',
                style: AppFonts.lamaSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: controller.loadStats,
                child: Text(
                  'إعادة المحاولة',
                  style: AppFonts.lamaSans(
                    fontWeight: FontWeight.w700,
                    color: _azure,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Private models & cards ─────────────────────────────────────────────────

class _BentoItem {
  const _BentoItem(this.title, this.value, this.icon, this.gradient);
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({required this.item});
  final _BentoItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: item.gradient.first.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: item.gradient.first.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: ui.TextDirection.rtl,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: item.gradient),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(item.icon, color: Colors.white, size: 18.sp),
          ),
          const Spacer(),
          Text(
            item.value,
            style: AppFonts.lamaSans(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            item.title,
            style: AppFonts.lamaSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg {
  const _Seg(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;
}
