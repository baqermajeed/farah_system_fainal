import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/implant_stage_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/models/implant_stage_model.dart';

class _TimelineAssets {
  static const back = 'assets/icon/backblack.png';
  static const implant = 'assets/icon/implanticon.png';
}

class DentalImplantTimelineScreen extends StatefulWidget {
  const DentalImplantTimelineScreen({super.key});

  @override
  State<DentalImplantTimelineScreen> createState() =>
      _DentalImplantTimelineScreenState();
}

class _DentalImplantTimelineScreenState
    extends State<DentalImplantTimelineScreen> {
  static const Color _bg = Color(0xFFF8FAFF);
  static const Color _navy = Color(0xFF032252);
  static const Color _grayText = Color(0xFF8A97A8);
  static const Color _border = Color(0xFFE8ECF0);

  static const List<String> _allStageNames = [
    'مرحلة زراعة الاسنان',
    'مرحلة رفع خيط العملية',
    'متابعة حالة المريض',
    'المتابعة الثانية لحالة المريض',
    'التقاط طبعة الاسنان',
    'التركيب التجريبي الاول',
    'التركيب التجريبي الثاني',
    'التركيب النهائي الاخير',
  ];

  late final ImplantStageController _implantStageController;
  late final PatientController _patientController;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _implantStageController = Get.put(ImplantStageController());
    _patientController = Get.find<PatientController>();
    _authController = Get.find<AuthController>();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final patientId = _authController.patientProfileId.value;
    if (patientId == null || patientId.isEmpty) return;

    await Future.wait([
      _patientController.loadMyDoctor(),
      _implantStageController.loadStages(patientId),
    ]);
  }

  String _doctorSubtitle() {
    final name = _patientController.myDoctor.value?['name']?.toString();
    if (name != null && name.isNotEmpty) {
      return 'مواعيدك مع د. $name';
    }
    return 'متابعة مراحل زراعة أسنانك';
  }

  int? _lastCompletedIndex(List<ImplantStageModel> patientStages) {
    int? lastCompletedIndex;
    for (int i = patientStages.length - 1; i >= 0; i--) {
      if (!patientStages[i].isCompleted) continue;
      final indexInAll = _allStageNames.indexOf(patientStages[i].stageName);
      if (indexInAll != -1) {
        lastCompletedIndex = indexInAll;
        break;
      }
    }
    return lastCompletedIndex;
  }

  ImplantStageModel _stageForName(
    String stageName,
    List<ImplantStageModel> patientStages,
    String patientId,
  ) {
    return patientStages.firstWhere(
      (s) => s.stageName == stageName,
      orElse: () => ImplantStageModel(
        id: '',
        patientId: patientId,
        stageName: stageName,
        scheduledAt: DateTime.now(),
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientId = _authController.patientProfileId.value ?? '';

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
              _buildHeader(),
              _buildTitleSection(),
              SizedBox(height: 12.h),
              Expanded(
                child: Obx(() {
                  if (_implantStageController.isLoading.value &&
                      _implantStageController.stages.isEmpty) {
                    return const LoadingWidget(
                      message: 'جاري تحميل المراحل...',
                    );
                  }

                  final patientStages =
                      _implantStageController.stagesForPatient(patientId);
                  final lastCompletedIndex = _lastCompletedIndex(patientStages);
                  final completedCount = patientStages
                      .where((s) => s.isCompleted)
                      .length;

                  return Column(
                    children: [
                      if (patientStages.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: _buildProgressChip(
                            completed: completedCount,
                            total: _allStageNames.length,
                          ),
                        ),
                      if (patientStages.isNotEmpty) SizedBox(height: 14.h),
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                          itemCount: _allStageNames.length,
                          separatorBuilder: (_, __) => SizedBox(height: 4.h),
                          itemBuilder: (context, index) {
                            final stageName = _allStageNames[index];
                            final stage = _stageForName(
                              stageName,
                              patientStages,
                              patientId,
                            );
                            final isLast = index == _allStageNames.length - 1;
                            final isFirst = index == 0;
                            final stageExists = stage.id.isNotEmpty;

                            final isNextToLastCompleted =
                                lastCompletedIndex != null &&
                                    index == lastCompletedIndex + 1;

                            final showAppointmentInfo = stage.isCompleted ||
                                isNextToLastCompleted ||
                                (isFirst && stageExists);

                            final isCurrent = !stage.isCompleted &&
                                (isNextToLastCompleted ||
                                    (lastCompletedIndex == null && index == 0));

                            final hasNextCompleted = index <
                                    _allStageNames.length - 1 &&
                                _stageForName(
                                  _allStageNames[index + 1],
                                  patientStages,
                                  patientId,
                                ).isCompleted;

                            return _buildTimelineItem(
                              stage: stage,
                              isLast: isLast,
                              isCurrent: isCurrent,
                              hasNextCompleted: hasNextCompleted,
                              showAppointmentInfo: showAppointmentInfo,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ),
              _buildInfoBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          const BackButtonWidget(assetPath: _TimelineAssets.back),
          Expanded(
            child: Text(
              'مراحل الزراعة',
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

  Widget _buildTitleSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مواعيد زراعة أسنانك',
                      style: AppFonts.lamaSans(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Obx(
                      () => Text(
                        _doctorSubtitle(),
                        style: AppFonts.lamaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: _grayText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: _navy.withValues(alpha: 0.12)),
                ),
                padding: EdgeInsets.all(10.w),
                child: Image.asset(
                  _TimelineAssets.implant,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressChip({required int completed, required int total}) {
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'التقدم',
                style: AppFonts.lamaSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const Spacer(),
              Text(
                '$completed من $total مراحل',
                style: AppFonts.lamaSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: _grayText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6.h,
              backgroundColor: _navy.withValues(alpha: 0.08),
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required ImplantStageModel stage,
    required bool isLast,
    required bool isCurrent,
    required bool hasNextCompleted,
    required bool showAppointmentInfo,
  }) {
    final isCompleted = stage.isCompleted;
    final lineColor = isCompleted || hasNextCompleted
        ? _navy
        : _navy.withValues(alpha: 0.18);

    return IntrinsicHeight(
      child: Row(
        textDirection: ui.TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36.w,
            child: Column(
              children: [
                _buildTimelineNode(
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 4.h),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
              child: _buildStageCard(
                stage: stage,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                showAppointmentInfo: showAppointmentInfo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({
    required bool isCompleted,
    required bool isCurrent,
  }) {
    if (isCompleted) {
      return Container(
        width: 28.w,
        height: 28.w,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _navy,
        ),
        child: Icon(Icons.check_rounded, color: Colors.white, size: 18.sp),
      );
    }

    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: isCurrent ? _navy : _navy.withValues(alpha: 0.25),
          width: isCurrent ? 2.5 : 2,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: isCurrent
          ? Center(
              child: Container(
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _navy,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStageCard({
    required ImplantStageModel stage,
    required bool isCompleted,
    required bool isCurrent,
    required bool showAppointmentInfo,
  }) {
    final dateFormat = DateFormat('d/M/yyyy');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isCurrent
              ? _navy.withValues(alpha: 0.35)
              : _border,
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isCurrent ? 0.06 : 0.03),
            blurRadius: isCurrent ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stage.stageName,
                    style: AppFonts.lamaSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: isCompleted
                          ? _grayText
                          : _navy,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: _grayText,
                    ),
                  ),
                ),
                _buildStatusBadge(isCompleted: isCompleted, isCurrent: isCurrent),
              ],
            ),
            if (showAppointmentInfo && stage.id.isNotEmpty) ...[
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FB),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'موعدك سيكون في',
                      style: AppFonts.lamaSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: _grayText,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'تاريخ ${dateFormat.format(stage.scheduledAt)} • ${_dayName(stage.scheduledAt)} • ${_formatTime(stage.scheduledAt)}',
                      style: AppFonts.lamaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isCompleted,
    required bool isCurrent,
  }) {
    final String label;
    final Color bg;
    final Color fg;

    if (isCompleted) {
      label = 'مكتملة';
      bg = _navy.withValues(alpha: 0.1);
      fg = _navy;
    } else if (isCurrent) {
      label = 'المرحلة الحالية';
      bg = _navy;
      fg = Colors.white;
    } else {
      label = 'قادمة';
      bg = const Color(0xFFF3F6FB);
      fg = _grayText;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        label,
        style: AppFonts.lamaSans(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFF5D5D5)),
      ),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Row(
          children: [
            Image.asset(
              'assets/images/first_aid_kit.png',
              width: 44.w,
              height: 44.w,
              fit: BoxFit.contain,
              cacheWidth: 180,
              cacheHeight: 180,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الفترة التقريبية لانتهاء مراحل الزراعة',
                    style: AppFonts.lamaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'تكون من 4 إلى 5 أشهر',
                    style: AppFonts.lamaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: _grayText,
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
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
}
