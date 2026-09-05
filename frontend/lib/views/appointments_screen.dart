import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/appointments_screen_controller.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/core/widgets/app_skeleton.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_back_button.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/widgets/appointment_list_card.dart';

class AppointmentsScreen extends GetView<AppointmentsScreenController> {
  const AppointmentsScreen({super.key});

  static const Color _bg = Color(0xFFF8FAFF);
  static const Color _navy = Color(0xFF1A3158);
  static const Color _grayText = Color(0xFF788FA5);
  static const Color _accentBlue = Color(0xFF5A9BD5);

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final cairoTheme = baseTheme.copyWith(
      textTheme: AppFonts.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppFonts.textTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: cairoTheme,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: controller.tabController,
                  children: [
                    _buildAppointmentsList('اليوم'),
                    _buildAppointmentsList('هذا الشهر'),
                    _buildAppointmentsList('المتأخرون'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final userType =
        Get.find<AuthController>().currentUser.value?.userType?.toLowerCase();
    final isDoctor = userType == 'doctor';

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          isDoctor ? const DoctorBackButton() : const BackButtonWidget(),
          Expanded(
            child: Column(
              children: [
                Text(
                  AppStrings.appointments,
                  style: AppFonts.lamaSans(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'تابع مواعيد مرضاك بسهولة ودقة',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showDateRangeFilterDialog(context),
            child: Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.tune_rounded,
                color: _accentBlue,
                size: 22.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: controller.tabController,
        indicator: BoxDecoration(
          color: _accentBlue,
          borderRadius: BorderRadius.circular(12.r),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.white,
        unselectedLabelColor: _grayText,
        labelStyle: AppFonts.lamaSans(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppFonts.lamaSans(
          fontSize: 13.sp,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: 4.w),
        tabs: const [
          Tab(text: 'اليوم'),
          Tab(text: 'هذا الشهر'),
          Tab(text: 'المتأخرون'),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList(String filter) {
    return Obx(() {
      final appointmentController = controller.appointmentController;
      final filteredAppointments = appointmentController.appointments;

      if (appointmentController.isLoading.value &&
          filteredAppointments.isEmpty) {
        return const SkeletonAppointmentList();
      }

      final activeFilter = controller.currentFilter.value;

      if (filteredAppointments.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.calendar_today_outlined,
          title: _emptyMessage(activeFilter),
          subtitle: 'لم يتم العثور على مواعيد',
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refreshAppointments,
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200 &&
                !appointmentController.isLoadingMoreAppointments.value &&
                appointmentController.hasMoreAppointments.value) {
              controller.loadMore();
            }
            return false;
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
            itemCount: filteredAppointments.length +
                (appointmentController.isLoadingMoreAppointments.value
                    ? 1
                    : 0),
            separatorBuilder: (_, index) {
              if (index >= filteredAppointments.length - 1) {
                return const SizedBox.shrink();
              }
              return SizedBox(height: 12.h);
            },
            itemBuilder: (context, index) {
              if (index == filteredAppointments.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final appointment = filteredAppointments[index];
              final now = DateTime.now();
              final status = appointment.status.toLowerCase();
              final isPast = appointment.date.isBefore(now) ||
                  status == 'completed' ||
                  status == 'cancelled' ||
                  status == 'no_show';
              final isLate =
                  appointment.isLate || activeFilter == 'المتأخرون';

              final authController = Get.find<AuthController>();
              final isReceptionist =
                  authController.currentUser.value?.userType ==
                      'receptionist';
              final patient = controller.patientController
                  .getPatientById(appointment.patientId);
              final patientName = patient?.name ?? appointment.patientName;
              final doctorName = appointment.doctorName;

              return AppointmentListCard(
                title: _cardTitle(
                  patientName: patientName,
                  doctorName: doctorName,
                  isReceptionist: isReceptionist,
                ),
                subtitle: _serviceText(appointment),
                date: appointment.date,
                time: appointment.time,
                avatarImageUrl: patient?.imageUrl,
                preferAvatar: true,
                tone: isLate
                    ? AppointmentCardTone.late
                    : isPast
                        ? AppointmentCardTone.past
                        : AppointmentCardTone.upcoming,
                footerText: isLate
                    ? 'موعد متأخر — يُنصح بالتواصل مع المريض'
                    : isPast
                        ? 'موعد سابق'
                        : 'الرجاء الحضور قبل الموعد ب نصف ساعة',
                onTap: _cardTapHandler(appointment),
              );
            },
          ),
        ),
      );
    });
  }

  String _emptyMessage(String filter) {
    switch (filter) {
      case 'اليوم':
        return 'لا توجد مواعيد اليوم';
      case 'هذا الشهر':
        return 'لا توجد مواعيد هذا الشهر';
      case 'المتأخرون':
        return 'لا توجد مواعيد متأخرة';
      default:
        return 'لا توجد مواعيد';
    }
  }

  VoidCallback? _cardTapHandler(AppointmentModel appointment) {
    final authController = Get.find<AuthController>();
    final isReceptionist =
        authController.currentUser.value?.userType == 'receptionist';
    if (isReceptionist || appointment.patientId.trim().isEmpty) return null;

    return () {
      final patient =
          controller.patientController.getPatientById(appointment.patientId);
      if (patient != null) {
        controller.patientController.selectPatient(patient);
      }
      Get.toNamed(
        AppRoutes.patientDetails,
        arguments: {
          'patientId': appointment.patientId,
          'appointmentId': appointment.id,
          'appointment': appointment,
        },
      );
    };
  }

  String _cardTitle({
    required String patientName,
    required String doctorName,
    required bool isReceptionist,
  }) {
    if (isReceptionist && doctorName.isNotEmpty) {
      return '$patientName • د. $doctorName';
    }
    return patientName;
  }

  String _serviceText(AppointmentModel appointment) {
    if (appointment.notes?.trim().isNotEmpty == true) {
      return appointment.notes!.trim();
    }
    if (appointment.stageName?.trim().isNotEmpty == true) {
      return appointment.stageName!.trim();
    }
    return 'حشوات قلع تنظيف';
  }

  void _showDateRangeFilterDialog(BuildContext screenContext) {
    DateTime? startDate = controller.customFilterStart;
    DateTime? endDate = controller.customFilterEnd;

    showDialog(
      context: screenContext,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate({
              required DateTime? current,
              required DateTime firstDate,
              required DateTime lastDate,
              required ValueChanged<DateTime> onPicked,
            }) async {
              final picked = await _showCalendarBottomSheet(
                screenContext,
                initialDate: current ?? DateTime.now(),
                firstDate: firstDate,
                lastDate: lastDate,
              );
              if (picked != null) {
                setDialogState(() => onPicked(picked));
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.92,
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'تصفية حسب التاريخ (من - إلى)',
                      style: AppFonts.lamaSans(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    _buildDatePickerField(
                      label: 'من تاريخ:',
                      date: startDate,
                      onTap: () => pickDate(
                        current: startDate,
                        firstDate: DateTime(2020),
                        lastDate: endDate ?? DateTime(2030),
                        onPicked: (date) => startDate = date,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _buildDatePickerField(
                      label: 'إلى تاريخ:',
                      date: endDate,
                      onTap: () => pickDate(
                        current: endDate,
                        firstDate: startDate ?? DateTime(2020),
                        lastDate: DateTime(2030),
                        onPicked: (date) => endDate = date,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _grayText,
                              side: const BorderSide(color: Color(0xFFE4E7EC)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (startDate == null || endDate == null) {
                                Get.snackbar(
                                  'تنبيه',
                                  'يرجى اختيار تاريخ البداية والنهاية',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                                return;
                              }
                              if (endDate!.isBefore(startDate!)) {
                                Get.snackbar(
                                  'تنبيه',
                                  'تاريخ النهاية يجب أن يكون بعد تاريخ البداية',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                                return;
                              }
                              Navigator.of(context).pop();
                              controller.rememberCustomRange(
                                startDate!,
                                endDate!,
                              );
                              Get.toNamed(
                                AppRoutes.appointmentsByDate,
                                arguments: {
                                  'startDate': startDate,
                                  'endDate': endDate,
                                },
                              )?.then((_) {
                                controller.loadForFilter(
                                  controller.currentFilter.value,
                                  isRefresh: true,
                                );
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentBlue,
                              foregroundColor: AppColors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'عرض المواعيد',
                                maxLines: 1,
                                style: AppFonts.lamaSans(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _showCalendarBottomSheet(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    var selectedDate = initialDate;

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E7EC),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  height: 320.h,
                  width: double.infinity,
                  child: CalendarDatePicker(
                    initialDate: initialDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    onDateChanged: (date) => selectedDate = date,
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(selectedDate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentBlue,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: const Text('تأكيد'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final dateFmt = DateFormat('d/M/yyyy', 'ar');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.lamaSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        SizedBox(height: 6.h),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE4E7EC)),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: _accentBlue,
                  size: 20.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    date != null ? dateFmt.format(date) : 'اختر التاريخ',
                    style: AppFonts.lamaSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: date != null ? _navy : _grayText,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _grayText,
                  size: 22.sp,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
