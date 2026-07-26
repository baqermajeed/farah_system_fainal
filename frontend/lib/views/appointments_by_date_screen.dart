import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/appointments_by_date_controller.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_back_button.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/widgets/appointment_list_card.dart';

class AppointmentsByDateScreen extends GetView<AppointmentsByDateController> {
  const AppointmentsByDateScreen({super.key});

  static const Color _bg = Color(0xFFF8FAFF);
  static const Color _navy = Color(0xFF1A3158);
  static const Color _grayText = Color(0xFF788FA5);

  String _screenTitle() {
    final start = controller.startDate;
    final end = controller.endDate;
    if (start == null || end == null) return 'المواعيد';

    final dateFmt = DateFormat('d/M/yyyy', 'ar');
    final sameDay =
        start.year == end.year && start.month == end.month && start.day == end.day;
    if (sameDay) {
      return 'مواعيد ${dateFmt.format(start)}';
    }
    return 'من ${dateFmt.format(start)} إلى ${dateFmt.format(end)}';
  }

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
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                child: Row(
                  textDirection: ui.TextDirection.ltr,
                  children: [
                    Get.find<AuthController>()
                                .currentUser
                                .value
                                ?.userType
                                ?.toLowerCase() ==
                            'doctor'
                        ? const DoctorBackButton()
                        : const BackButtonWidget(),
                    Expanded(
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _screenTitle(),
                              style: AppFonts.lamaSans(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'نتائج التصفية حسب التاريخ',
                            style: AppFonts.lamaSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: _grayText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 48.w),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  final appointmentController = controller.appointmentController;
                  final appointments = appointmentController.appointments;

                  if (controller.startDate == null || controller.endDate == null) {
                    return const EmptyStateWidget(
                      icon: Icons.calendar_today_outlined,
                      title: 'لم يتم اختيار فترة',
                      subtitle: 'يرجى اختيار تاريخ البداية والنهاية',
                    );
                  }

                  if (appointmentController.isLoading.value &&
                      appointments.isEmpty) {
                    return const LoadingWidget(message: 'جاري تحميل المواعيد...');
                  }

                  if (appointments.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.calendar_today_outlined,
                      title: 'لا توجد مواعيد في هذه الفترة',
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
                            !appointmentController
                                .isLoadingMoreAppointments.value &&
                            appointmentController.hasMoreAppointments.value) {
                          controller.loadMore();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                        itemCount: appointments.length +
                            (appointmentController
                                    .isLoadingMoreAppointments.value
                                ? 1
                                : 0),
                        separatorBuilder: (_, index) {
                          if (index >= appointments.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return SizedBox(height: 12.h);
                        },
                        itemBuilder: (context, index) {
                          if (index == appointments.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }

                          final appointment = appointments[index];
                          final now = DateTime.now();
                          final status = appointment.status.toLowerCase();
                          final isPast = appointment.date.isBefore(now) ||
                              status == 'completed' ||
                              status == 'cancelled' ||
                              status == 'no_show';
                          final isLate = appointment.isLate;

                          final authController = Get.find<AuthController>();
                          final isReceptionist =
                              authController.currentUser.value?.userType ==
                                  'receptionist';
                          final patient = controller.patientController
                              .getPatientById(appointment.patientId);
                          final patientName =
                              patient?.name ?? appointment.patientName;
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
                }),
              ),
            ],
          ),
        ),
      ),
    );
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
}
