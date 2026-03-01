import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/widgets/back_button_widget.dart';
import 'package:frontend_desktop/controllers/working_hours_controller.dart';

class WorkingHoursPage extends StatelessWidget {
  WorkingHoursPage({super.key});

  final WorkingHoursController controller = Get.put(WorkingHoursController());

  /// تحويل الوقت من 24 ساعة إلى 12 ساعة
  String _convertTo12Hour(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length < 2) return time24;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1];

      if (hour == 0) {
        return '12:$minute ص';
      } else if (hour < 12) {
        return '$hour:$minute ص';
      } else if (hour == 12) {
        return '12:$minute م';
      } else {
        return '${hour - 12}:$minute م';
      }
    } catch (e) {
      return time24;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFF),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  const BackButtonWidget(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'إدارة أوقات العمل',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
            // Body
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoCard(),
                      SizedBox(height: 16.h),
                      ...List.generate(7, (index) => _buildDayCard(index)),
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _onDeleteAll,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFFF3B30),
                                ),
                                foregroundColor: const Color(0xFFFF3B30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: Text(
                                'حذف الكل',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFF3B30),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _onSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: Text(
                                'حفظ',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'حدد أوقات عملك لكل يوم من أيام الأسبوع',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(int dayIndex) {
    return Obx(() {
      final day = controller.workingHours[dayIndex];
      final isWorking = day['isWorking'] as bool;

      return Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Theme(
          data: ThemeData(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: Obx(() {
            final isExpanded = controller.expandedDays[dayIndex] ?? false;
            return ExpansionTile(
              tilePadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 4.h,
              ),
              childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              onExpansionChanged: (expanded) {
                controller.expandedDays[dayIndex] = expanded;
              },
              leading: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: isWorking
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isWorking ? AppColors.primary : Colors.grey[400],
                  size: 24.sp,
                ),
              ),
              title: Text(
                day['dayName'],
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                isWorking
                    ? '${_convertTo12Hour(day['startTime'])} - ${_convertTo12Hour(day['endTime'])}'
                    : 'عطلة',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: Switch(
                value: isWorking,
                onChanged: (value) {
                  controller.toggleDayWorking(dayIndex);
                },
                activeColor: AppColors.primary,
              ),
              children: isWorking
                  ? [
                      _buildTimeRow(
                        label: 'من',
                        value: day['startTime'],
                        onTap: () => _selectTime(
                          dayIndex,
                          day['startTime'],
                          isStart: true,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildTimeRow(
                        label: 'إلى',
                        value: day['endTime'],
                        onTap: () => _selectTime(
                          dayIndex,
                          day['endTime'],
                          isStart: false,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildSlotDurationRow(dayIndex, day['slotDuration']),
                      SizedBox(height: 12.h),
                      _buildApplyToAllDaysButton(dayIndex),
                    ]
                  : [],
            );
          }),
        ),
      );
    });
  }

  Widget _buildTimeRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    _convertTo12Hour(value),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotDurationRow(int dayIndex, int duration) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            'مدة الفترة',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    if (duration > 15) {
                      controller.updateSlotDuration(dayIndex, duration - 15);
                    }
                  },
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: AppColors.primary,
                    size: 24.sp,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$duration',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'دقيقة',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: () {
                    if (duration < 120) {
                      controller.updateSlotDuration(dayIndex, duration + 15);
                    }
                  },
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                    size: 24.sp,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApplyToAllDaysButton(int dayIndex) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          controller.applyDayToAllDays(dayIndex);
          Get.snackbar(
            'تم التطبيق',
            'تم تطبيق أوقات هذا اليوم على جميع الأيام',
            backgroundColor: AppColors.primary,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        },
        icon: Icon(Icons.copy_all, size: 18.sp),
        label: Text(
          'تطبيق على كل الأيام',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primary),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.symmetric(vertical: 10.h),
        ),
      ),
    );
  }

  Future<void> _selectTime(
    int dayIndex,
    String currentTime, {
    required bool isStart,
  }) async {
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final TimeOfDay? picked = await showTimePicker(
      context: Get.context!,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (isStart) {
        controller.updateStartTime(dayIndex, formattedTime);
      } else {
        controller.updateEndTime(dayIndex, formattedTime);
      }
    }
  }

  Future<void> _onSave() async {
    final result = await controller.saveWorkingHours();
    if (result['ok'] == true) {
      await Get.dialog<void>(
        AlertDialog(
          title: Text('تم الحفظ'),
          content: Text(result['message'] ?? 'تم حفظ أوقات العمل بنجاح'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('حسناً'),
            ),
          ],
        ),
      );
    } else {
      final rawMessage = result['message']?.toString() ?? '';
      final message = rawMessage.contains('start_time must be before end_time')
          ? 'حصل خطا وقت النهاية قبل وقت البداية'
          : (result['message'] ?? 'تعذر حفظ أوقات العمل');
      await Get.dialog<void>(
        AlertDialog(
          title: Text('تحذير'),
          content: Text(
            message,
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _onDeleteAll() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('حذف جميع أوقات العمل'),
        content: Text('هل أنت متأكد؟ سيتم حذف جميع أوقات العمل'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B30),
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await controller.deleteAllWorkingHours();
      if (result['ok'] == true) {
        Get.snackbar(
          'تم الحذف',
          result['message'] ?? 'تم حذف جميع أوقات العمل بنجاح',
          backgroundColor: AppColors.primary,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'فشل الحذف',
          result['message'] ?? 'تعذر حذف أوقات العمل',
          backgroundColor: const Color(0xFFFF3B30),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }
}
