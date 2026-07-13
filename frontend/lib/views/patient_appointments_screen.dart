import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

class _AppointmentsAssets {
  static const dateIcon = 'assets/icon/date23.png';
  static const back = 'assets/icon/backblack.png';
}

class PatientAppointmentsScreen extends StatelessWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appointmentController = Get.find<AppointmentController>();
    final patientController = Get.find<PatientController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appointmentController.loadPatientAppointments();
      patientController.loadMyDoctor();
    });

    final baseTheme = Theme.of(context);
    final cairoTheme = baseTheme.copyWith(
      textTheme: AppFonts.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppFonts.textTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: cairoTheme,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Obx(() {
                  if (appointmentController.isLoading.value &&
                      appointmentController.appointments.isEmpty) {
                    return const LoadingWidget();
                  }

                  final appointments =
                      _sortedAppointments(appointmentController);

                  if (appointments.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'لا توجد مواعيد',
                      icon: Icons.calendar_today,
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    itemCount: appointments.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      return _buildAppointmentCard(
                        appointment: appointments[index],
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          const BackButtonWidget(assetPath: _AppointmentsAssets.back),
          Expanded(
            child: Column(
              children: [
                Text(
                  AppStrings.appointments,
                  style: AppFonts.lamaSans(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'جميع المواعيد مرتبة حسب التاريخ',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8A97A8),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 48.w),
        ],
      ),
    );
  }

  List<AppointmentModel> _sortedAppointments(
    AppointmentController controller,
  ) {
    final upcoming = controller.getUpcomingAppointments();

    final others = controller.appointments.where((appointment) {
      return !upcoming.any((u) => u.id == appointment.id);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return [...upcoming, ...others];
  }

  Widget _buildAppointmentCard({required AppointmentModel appointment}) {
    const navy = Color(0xFF1E3A5F);
    const grayText = Color(0xFF8A97A8);

    final patientController = Get.find<PatientController>();
    final doctorName = appointment.doctorName.isNotEmpty
        ? appointment.doctorName
        : (patientController.myDoctor.value?['name'] ?? 'طبيبك');

    final weekDays = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final dayName = weekDays[appointment.date.weekday % 7];
    final dayNumber = appointment.date.day.toString();
    final monthYear = DateFormat('MMMM yyyy', 'ar').format(appointment.date);

    final timeParts = appointment.time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? timeParts[1] : '00';
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeText = '$displayHour:$minute';
    final periodText = isPM ? 'مساءً' : 'صباحاً';

    final serviceText = (appointment.notes?.trim().isNotEmpty == true)
        ? appointment.notes!.trim()
        : (appointment.stageName?.trim().isNotEmpty == true)
            ? appointment.stageName!.trim()
            : 'حشوات قلع تنظيف';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Directionality(
            textDirection: ui.TextDirection.rtl,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 78.w,
                    padding: EdgeInsets.symmetric(
                      vertical: 14.h,
                      horizontal: 8.w,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20.r),
                      ),
                      border: Border(
                        left: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: AppFonts.lamaSans(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: grayText,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          dayNumber,
                          style: AppFonts.lamaSans(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w800,
                            color: navy,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          monthYear,
                          textAlign: TextAlign.center,
                          style: AppFonts.lamaSans(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 16.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'د. $doctorName',
                            style: AppFonts.lamaSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: navy,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            serviceText,
                            style: AppFonts.lamaSans(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: grayText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 16.h,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timeText,
                          style: AppFonts.lamaSans(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: navy,
                          ),
                        ),
                        Text(
                          periodText,
                          style: AppFonts.lamaSans(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: const Color(0xFFE8ECF0),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    _AppointmentsAssets.dateIcon,
                    width: 18.w,
                    height: 18.w,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'الرجاء الحضور قبل الموعد ب نصف ساعة',
                    style: AppFonts.lamaSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: grayText,
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
}
