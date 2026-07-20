import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/controllers/dental_implant_timeline_controller.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/models/implant_stage_model.dart';

class _TimelineAssets {
  static const back = 'assets/icon/backblack.png';
  static const head = 'assets/implant-stage/head.png';
  static const stageIcons = [
    'assets/implant-stage/stage1.png',
    'assets/implant-stage/stage2.png',
    'assets/implant-stage/stage3.png',
    'assets/implant-stage/stage4.png',
    'assets/implant-stage/stage5.png',
    'assets/implant-stage/stage6.png',
    'assets/implant-stage/stage7.png',
    'assets/implant-stage/stage8.png',
  ];
}

class DentalImplantTimelineScreen
    extends GetView<DentalImplantTimelineController> {
  const DentalImplantTimelineScreen({super.key});

  static const Color _navy = Color(0xFF1A2B5A);
  static const Color _subtitleBlue = Color(0xFF8A94A6);
  static const Color _mutedBlue = Color(0xFF8A94A6);
  static const Color _linePending = Color(0xFFD5E2F0);
  static const Color _green = Color(0xFF27AE60);
  static const Color _greenLine = Color(0xFF2ECC71);
  static const Color _currentBlue = Color(0xFF4A69FF);
  static const Color _cardShadow = Color(0x0D000000);
  static const Color _divider = Color(0xFFF0F4F8);
  static const Color _calendarBg = Color(0xFF6B7CFF);

  @override
  Widget build(BuildContext context) {
    final patientId = controller.patientId;

    final baseTheme = Theme.of(context);
    final theme = baseTheme.copyWith(
      textTheme: AppFonts.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppFonts.textTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFEAF3FF),
                Color(0xFFF7FAFF),
                Color(0xFFFFFFFF),
              ],
              stops: [0.0, 0.35, 1.0],
            ),
          ),
          child: SafeArea(
            child: Obx(() {
              final implantStageController = controller.implantStageController;
              if (implantStageController.isLoading.value &&
                  implantStageController.stages.isEmpty) {
                return const LoadingWidget(message: 'جاري تحميل المراحل...');
              }

              final patientStages =
                  implantStageController.stagesForPatient(patientId);
              final lastCompletedIndex =
                  controller.lastCompletedIndex(patientStages);
              final startDate = controller.treatmentStartDate(patientStages);

              return RefreshIndicator(
                color: _navy,
                onRefresh: controller.refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      if (startDate != null) ...[
                        SizedBox(height: 8.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildTreatmentStartCard(startDate),
                          ),
                        ),
                      ],
                      SizedBox(height: 16.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: _buildTimelineCard(
                          patientStages: patientStages,
                          patientId: patientId,
                          lastCompletedIndex: lastCompletedIndex,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: const BackButtonWidget(assetPath: _TimelineAssets.back),
          ),
          Expanded(
            child: Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeroIcon(),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مراحل زراعة أسنانك',
                          style: AppFonts.lamaSans(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Obx(
                          () => Text(
                            controller.doctorSubtitle(),
                            style: AppFonts.lamaSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: _subtitleBlue,
                            ),
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

  Widget _buildHeroIcon() {
    return Container(
      width: 108.w,
      height: 108.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFBFD8FF).withValues(alpha: 0.55),
            const Color(0xFFEAF3FF).withValues(alpha: 0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Center(
        child: Image.asset(
          _TimelineAssets.head,
          width: 92.w,
          height: 92.w,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildTreatmentStartCard(DateTime date) {
    return Container(
      width: 220.w,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: const [
          BoxShadow(
            color: _cardShadow,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      // من اليمين: الأيقونة ثم النص
      child: Row(
        textDirection: ui.TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: _calendarBg,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: _calendarBg.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بداية خطة العلاج',
                  style: AppFonts.lamaSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  _formatShortDate(date),
                  style: AppFonts.lamaSans(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    color: _mutedBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard({
    required List<ImplantStageModel> patientStages,
    required String patientId,
    required int? lastCompletedIndex,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: const [
          BoxShadow(
            color: _cardShadow,
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: List.generate(
          DentalImplantTimelineController.allStageNames.length,
          (index) {
            final stageName =
                DentalImplantTimelineController.allStageNames[index];
            final stage = controller.stageForName(
              stageName,
              patientStages,
              patientId,
            );
            final isLast = index ==
                DentalImplantTimelineController.allStageNames.length - 1;
            final isFirst = index == 0;
            final stageExists = stage.id.isNotEmpty;

            final isNextToLastCompleted =
                lastCompletedIndex != null && index == lastCompletedIndex + 1;

            final showAppointmentInfo = stage.isCompleted ||
                isNextToLastCompleted ||
                (isFirst && stageExists);

            final isCurrent = !stage.isCompleted &&
                (isNextToLastCompleted ||
                    (lastCompletedIndex == null && index == 0));

            final nextCompleted = index <
                    DentalImplantTimelineController.allStageNames.length - 1 &&
                controller
                    .stageForName(
                      DentalImplantTimelineController.allStageNames[
                          index + 1],
                      patientStages,
                      patientId,
                    )
                    .isCompleted;

            final lineCompleted = stage.isCompleted || nextCompleted;

            return _buildTimelineRow(
              index: index,
              stage: stage,
              isLast: isLast,
              isCurrent: isCurrent,
              lineCompleted: lineCompleted,
              showAppointmentInfo: showAppointmentInfo,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimelineRow({
    required int index,
    required ImplantStageModel stage,
    required bool isLast,
    required bool isCurrent,
    required bool lineCompleted,
    required bool showAppointmentInfo,
  }) {
    final isCompleted = stage.isCompleted;
    final stageNumber = index + 1;

    return IntrinsicHeight(
      child: Row(
        textDirection: ui.TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34.w,
            child: Column(
              children: [
                _buildTimelineNode(
                  stageNumber: stageNumber,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.5.w,
                      margin: EdgeInsets.symmetric(vertical: 3.h),
                      decoration: BoxDecoration(
                        color: lineCompleted ? _greenLine : _linePending,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 4.h, top: 2.h),
                  child: _buildStageContent(
                    index: index,
                    stage: stage,
                    isCompleted: isCompleted,
                    isCurrent: isCurrent,
                    showAppointmentInfo: showAppointmentInfo,
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 20.h,
                    thickness: 1,
                    color: _divider,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({
    required int stageNumber,
    required bool isCompleted,
    required bool isCurrent,
  }) {
    if (isCompleted) {
      return Container(
        width: 30.w,
        height: 30.w,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _green,
        ),
        child: Icon(Icons.check_rounded, color: Colors.white, size: 18.sp),
      );
    }

    if (isCurrent) {
      return Container(
        width: 34.w,
        height: 34.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: _currentBlue.withValues(alpha: 0.55), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: _currentBlue.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '$stageNumber',
          style: AppFonts.lamaSans(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
      );
    }

    return Container(
      width: 30.w,
      height: 30.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _linePending, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$stageNumber',
        style: AppFonts.lamaSans(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: _mutedBlue,
        ),
      ),
    );
  }

  Widget _buildStageContent({
    required int index,
    required ImplantStageModel stage,
    required bool isCompleted,
    required bool isCurrent,
    required bool showAppointmentInfo,
  }) {
    final description = _stageDescription(
      index: index,
      isCompleted: isCompleted,
      isCurrent: isCurrent,
      showAppointmentInfo: showAppointmentInfo,
      stageExists: stage.id.isNotEmpty,
    );

    final showDate = showAppointmentInfo && stage.id.isNotEmpty;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageIcon(index),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DentalImplantTimelineController.displayStageNames[index],
                  style: AppFonts.lamaSans(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w800,
                    color: isCompleted || isCurrent
                        ? _navy
                        : _navy.withValues(alpha: 0.75),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: AppFonts.lamaSans(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                    color: isCurrent ? _currentBlue : _subtitleBlue,
                    height: 1.35,
                  ),
                ),
                if (showDate) ...[
                  SizedBox(height: 4.h),
                  Text(
                    _formatFullDateTime(stage.scheduledAt),
                    style: AppFonts.lamaSans(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: _mutedBlue,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageIcon(int index) {
    return Image.asset(
      _TimelineAssets.stageIcons[index],
      width: 52.w,
      height: 52.w,
      fit: BoxFit.contain,
    );
  }

  String _stageDescription({
    required int index,
    required bool isCompleted,
    required bool isCurrent,
    required bool showAppointmentInfo,
    required bool stageExists,
  }) {
    if (isCompleted) {
      return DentalImplantTimelineController.completedDescriptions[index];
    }
    if (isCurrent || (showAppointmentInfo && stageExists)) {
      return 'الموعد القادم';
    }
    return 'سيتم تحديد الموعد لاحقاً';
  }

  String _formatShortDate(DateTime date) {
    try {
      return DateFormat('d MMMM yyyy', 'ar').format(date);
    } catch (_) {
      return DateFormat('d/M/yyyy').format(date);
    }
  }

  String _formatFullDateTime(DateTime date) {
    final day = _dayName(date);
    String datePart;
    try {
      datePart = DateFormat('d MMMM yyyy', 'ar').format(date);
    } catch (_) {
      datePart = DateFormat('d/M/yyyy').format(date);
    }
    return '$day $datePart - ${_formatTime(date)}';
  }

  String _dayName(DateTime date) {
    const days = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    return days[date.weekday % 7];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final isPm = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = isPm ? 'مساءً' : 'صباحاً';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }
}
