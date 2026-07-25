import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/widgets/appointment_list_card.dart';

class _AppointmentsAssets {
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
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        await Future.wait([
                          appointmentController.loadPatientAppointments(),
                          patientController.loadMyDoctor(),
                        ]);
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 120.h),
                          const EmptyStateWidget(
                            title: 'لا توجد مواعيد',
                            icon: Icons.calendar_today,
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      await Future.wait([
                        appointmentController.loadPatientAppointments(),
                        patientController.loadMyDoctor(),
                      ]);
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                      itemCount: appointments.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (context, index) {
                        final appointment = appointments[index];
                        final isUpcoming =
                            _isUpcomingAppointment(appointment);
                        final patientController = Get.find<PatientController>();
                        final doctorName = appointment.doctorName.isNotEmpty
                            ? appointment.doctorName
                            : (patientController.myDoctor.value?['name'] ??
                                'طبيبك');
                        final serviceText =
                            (appointment.notes?.trim().isNotEmpty == true)
                                ? appointment.notes!.trim()
                                : (appointment.stageName?.trim().isNotEmpty ==
                                        true)
                                    ? appointment.stageName!.trim()
                                    : 'حشوات قلع تنظيف';

                        return AppointmentListCard(
                          title: 'د. $doctorName',
                          subtitle: serviceText,
                          date: appointment.date,
                          time: appointment.time,
                          tone: isUpcoming
                              ? AppointmentCardTone.upcoming
                              : AppointmentCardTone.past,
                          footerText: isUpcoming
                              ? 'الرجاء الحضور قبل الموعد ب نصف ساعة'
                              : 'موعد سابق',
                        );
                      },
                    ),
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

  bool _isUpcomingAppointment(AppointmentModel appointment) {
    final status = appointment.status.toLowerCase();
    if (status == 'completed' || status == 'cancelled') return false;

    final timeParts = appointment.time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute =
        timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
    final appointmentDateTime = DateTime(
      appointment.date.year,
      appointment.date.month,
      appointment.date.day,
      hour,
      minute,
    );
    return !appointmentDateTime.isBefore(DateTime.now());
  }
}
