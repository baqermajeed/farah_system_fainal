import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/dental_chart_controller.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/widgets/dental_chart/dental_chart_constants.dart';
import 'package:farah_sys_final/widgets/dental_chart/dental_chart_painters.dart';
import 'package:farah_sys_final/widgets/dental_chart/dental_status_picker_sheet.dart';

class PatientDentalChartTab extends StatelessWidget {
  const PatientDentalChartTab({
    super.key,
    required this.patient,
    required this.controller,
  });

  final PatientModel patient;
  final DentalChartController controller;

  @override
  Widget build(BuildContext context) {
    controller.ensureLoaded(patient.id);

    return Obx(() {
      controller.revision.value;
      final chart = controller.chart;
      final selectedTooth = controller.selectedTooth;
      final loading = controller.isLoading.value;

      return Container(
        color: const Color(0xFFF4FEFF),
        child: loading && chart.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 12.h),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 9.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          'Dental Chart (FDI) - اضغط على أي سن لتغيير حالته',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final chartWidth = constraints.maxWidth;
                            final upperDesignWidth = _archDesignWidth(
                              DentalChartConstants.upperTeethFdi,
                            );
                            final lowerDesignWidth = _archDesignWidth(
                              DentalChartConstants.lowerTeethFdi,
                            );
                            final scrollContentWidth = math.max(
                              chartWidth,
                              math.max(upperDesignWidth, lowerDesignWidth) +
                                  (24.w),
                            );
                            final upperScale = _archScaleFactor(
                              DentalChartConstants.upperTeethFdi,
                              chartWidth,
                            );
                            final lowerScale = _archScaleFactor(
                              DentalChartConstants.lowerTeethFdi,
                              chartWidth,
                            );

                            return Column(
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: scrollContentWidth,
                                    child: Column(
                                      children: [
                                        Text(
                                          'الفك العلوي',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1F2A44),
                                          ),
                                        ),
                                        SizedBox(height: 6.h),
                                        _buildDentalArchRow(
                                          teeth: DentalChartConstants.upperTeethFdi,
                                          chart: chart,
                                          selectedTooth: selectedTooth,
                                          numbersOnTop: true,
                                          scale: upperScale,
                                          onToothTap: (toothNo) =>
                                              _showDentalStatusPicker(
                                            context,
                                            toothNo: toothNo,
                                          ),
                                        ),
                                        SizedBox(height: 6.h),
                                        SizedBox(
                                          height: 72.h,
                                          child: Stack(
                                            children: [
                                              Positioned(
                                                top: 34.h,
                                                left: 8.w,
                                                right: 8.w,
                                                child: Container(
                                                  height: 1.2,
                                                  color: const Color(0xFFD6DBE3),
                                                ),
                                              ),
                                              Center(
                                                child: Container(
                                                  width: 1.2,
                                                  color: const Color(0xFFD6DBE3),
                                                ),
                                              ),
                                              Positioned(
                                                top: 28.h,
                                                left: 0,
                                                child: Text(
                                                  'يمين',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: const Color(0xFF6C7A90),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 28.h,
                                                right: 0,
                                                child: Text(
                                                  'يسار',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: const Color(0xFF6C7A90),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _buildDentalArchRow(
                                          teeth: DentalChartConstants.lowerTeethFdi,
                                          chart: chart,
                                          selectedTooth: selectedTooth,
                                          numbersOnTop: false,
                                          scale: lowerScale,
                                          onToothTap: (toothNo) =>
                                              _showDentalStatusPicker(
                                            context,
                                            toothNo: toothNo,
                                          ),
                                        ),
                                        SizedBox(height: 6.h),
                                        Text(
                                          'الفك السفلي',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1F2A44),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Wrap(
                                  spacing: 6.w,
                                  runSpacing: 6.h,
                                  alignment: WrapAlignment.center,
                                  children: DentalChartConstants.dentalStatuses
                                      .map(
                                        (status) => Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.w,
                                            vertical: 4.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: DentalChartConstants
                                                .statusColor(status)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999.r),
                                            border: Border.all(
                                              color: DentalChartConstants
                                                  .statusColor(status)
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 10.sp,
                                              color: DentalChartConstants
                                                  .statusColor(status),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                SizedBox(height: 4.h),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    });
  }

  double _archDesignWidth(List<String> teeth) {
    var total = 0.0;
    for (final tooth in teeth) {
      final kind = DentalChartConstants.toothKindFromNumber(tooth);
      total += DentalChartConstants.toothWidth(kind, (v) => v.w);
      total += 2.w;
    }
    return total;
  }

  double _archScaleFactor(List<String> teeth, double availableWidth) {
    // Keep natural tooth size and rely on horizontal scrolling.
    return 1.0;
  }

  Widget _buildDentalArchRow({
    required List<String> teeth,
    required Map<String, Set<String>> chart,
    required String? selectedTooth,
    required bool numbersOnTop,
    required double scale,
    required ValueChanged<String> onToothTap,
  }) {
    final total = teeth.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: teeth.asMap().entries.map((entry) {
        final index = entry.key;
        final toothNo = entry.value;
        final yOffset = _archYOffset(
          index: index,
          total: total,
          isUpper: numbersOnTop,
          scale: scale,
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 1.w * scale),
          child: Transform.translate(
            offset: Offset(0, yOffset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (numbersOnTop) ...[
                  Text(
                    toothNo,
                    style: TextStyle(
                      fontSize: (9 * scale).sp,
                      color: const Color(0xFF1D68D9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h * scale),
                ],
                _buildToothVisual(
                  toothNo: toothNo,
                  statuses: chart[toothNo] ?? const <String>{},
                  isSelected: selectedTooth == toothNo,
                  isUpper: numbersOnTop,
                  scale: scale,
                  onTap: () => onToothTap(toothNo),
                ),
                if (!numbersOnTop) ...[
                  SizedBox(height: 2.h * scale),
                  Text(
                    toothNo,
                    style: TextStyle(
                      fontSize: (9 * scale).sp,
                      color: const Color(0xFF1D68D9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  double _archYOffset({
    required int index,
    required int total,
    required bool isUpper,
    required double scale,
  }) {
    if (total <= 1) return 0;
    final center = (total - 1) / 2;
    final normalizedDist = ((index - center).abs() / center).clamp(0.0, 1.0);
    final curve = normalizedDist * normalizedDist * normalizedDist;
    final amplitude = 14.h * scale;
    return isUpper ? curve * amplitude : -(curve * amplitude);
  }

  Widget _buildToothVisual({
    required String toothNo,
    required Set<String> statuses,
    required bool isSelected,
    required bool isUpper,
    required double scale,
    required VoidCallback onTap,
  }) {
    final borderColor =
        isSelected ? const Color(0xFF4CA7FF) : const Color(0xFFB9C0CC);
    final kind = DentalChartConstants.toothKindFromNumber(toothNo);
    final width = DentalChartConstants.toothWidth(kind, (v) => v.w) * scale;
    final height = 60.h * scale;
    final radius = 14.r * scale;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ToothShapePainter(
                    borderColor: borderColor,
                    isUpper: isUpper,
                    strokeWidth: (isSelected ? 2.0 : 1.4) * scale,
                    toothKind: kind,
                  ),
                ),
              ),
            ),
            if (DentalChartConstants.hasStatus(
              statuses,
              DentalChartConstants.smileStatus,
            ))
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: ToothSmileCoatingPainter(
                        isUpper: isUpper,
                        toothKind: kind,
                      ),
                    ),
                  ),
                ),
              ),
            if (isSelected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: 2.w * scale,
                      vertical: 3.h * scale,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF4CA7FF),
                        width: 1.8 * scale,
                      ),
                      borderRadius: BorderRadius.circular(radius),
                      color: const Color(0x124CA7FF),
                    ),
                  ),
                ),
              ),
            if (DentalChartConstants.hasStatus(statuses, 'حشوة'))
              Center(
                child: Container(
                  width: 18.w * scale,
                  height: 28.h * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2D24C),
                    borderRadius: BorderRadius.circular(10.r * scale),
                  ),
                ),
              ),
            if (DentalChartConstants.hasStatus(statuses, 'تسوس'))
              Center(
                child: Container(
                  width: 11.w * scale,
                  height: 11.w * scale,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D3035),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (DentalChartConstants.hasStatus(statuses, 'قص لثة'))
              Positioned(
                top: isUpper ? 4.h * scale : null,
                bottom: isUpper ? null : 4.h * scale,
                left: 6.w * scale,
                right: 6.w * scale,
                child: Container(
                  height: 10.h * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE25555),
                    borderRadius: BorderRadius.circular(10.r * scale),
                  ),
                ),
              ),
            if (DentalChartConstants.hasStatus(statuses, 'فينير'))
              Positioned(
                top: isUpper ? 4.h * scale : null,
                bottom: isUpper ? null : 4.h * scale,
                left: 6.w * scale,
                right: 6.w * scale,
                child: Container(
                  height: 10.h * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFFAB8AF7),
                    borderRadius: BorderRadius.circular(10.r * scale),
                  ),
                ),
              ),
            if (DentalChartConstants.hasStatus(statuses, 'تاج'))
              Positioned.fill(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: 3.w * scale,
                    vertical: 4.h * scale,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF4CA7FF),
                      width: 1.3 * scale,
                    ),
                    borderRadius: BorderRadius.circular(radius),
                    color: const Color(0x224CA7FF),
                  ),
                ),
              ),
            if (DentalChartConstants.hasStatus(statuses, 'جسر'))
              Positioned(
                left: 5.w * scale,
                right: 5.w * scale,
                top: 24.h * scale,
                child: Container(
                  height: 5.h * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1CB7D8),
                    borderRadius: BorderRadius.circular(6.r * scale),
                  ),
                ),
              ),
            if (DentalChartConstants.hasStatus(statuses, 'مفقود'))
              Center(
                child: Icon(
                  Icons.close_rounded,
                  size: (18 * scale).sp,
                  color: const Color(0xFF565C66),
                ),
              ),
            if (DentalChartConstants.hasStatus(statuses, 'قلع'))
              Center(
                child: Icon(
                  Icons.close_rounded,
                  size: (18 * scale).sp,
                  color: const Color(0xFFC0392B),
                ),
              ),
            if (DentalChartConstants.hasStatus(statuses, 'زراعة'))
              Center(
                child: Icon(
                  Icons.hardware,
                  size: (16 * scale).sp,
                  color: const Color(0xFF1CB7D8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDentalStatusPicker(
    BuildContext context, {
    required String toothNo,
  }) async {
    await showDentalStatusPickerSheet(
      context: context,
      controller: controller,
      toothNo: toothNo,
    );
  }
}
