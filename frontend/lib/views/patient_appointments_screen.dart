import 'package:flutter/material.dart';
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
import 'package:google_fonts/google_fonts.dart';

class PatientAppointmentsScreen extends StatelessWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appointmentController = Get.find<AppointmentController>();
    final patientController = Get.find<PatientController>();

    // Load appointments on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appointmentController.loadPatientAppointments();
      patientController.loadMyDoctor();
    });

    final baseTheme = Theme.of(context);
    final cairoTheme = baseTheme.copyWith(
      textTheme: GoogleFonts.cairoTextTheme(baseTheme.textTheme),
      primaryTextTheme: GoogleFonts.cairoTextTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: cairoTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4FEFF),
        body: SafeArea(
          child: Column(
            children: [
              // Header with light blue background
              Container(
                color: const Color(0xFFF4FEFF),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Stack(
                  children: [
                    // Back button (moved to the right)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(child: BackButtonWidget()),
                    ),

                    // Title and subtitle in center
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppStrings.appointments,
                            style: GoogleFonts.cairo(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Obx(() {
                            final doctor = patientController.myDoctor.value;
                            final doctorName =
                                doctor != null && doctor['name'] != null
                                    ? doctor['name']!
                                    : 'الطبيب';
                            return Text(
                              'مواعيدك مع الطبيب',
                              style: GoogleFonts.cairo(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Appointments List
              Expanded(
                child: Obx(() {
                  if (appointmentController.isLoading.value) {
                    return const LoadingWidget();
                  }

                  final allAppointments =
                      appointmentController.appointments.toList();
                  if (allAppointments.isEmpty) {
                    return EmptyStateWidget(
                      title: 'لا توجد مواعيد',
                      icon: Icons.calendar_today,
                    );
                  }

                  // Sort appointments by date (newest first)
                  allAppointments.sort((a, b) {
                    final aDate =
                        DateTime(a.date.year, a.date.month, a.date.day);
                    final bDate =
                        DateTime(b.date.year, b.date.month, b.date.day);
                    final aTime = _parseTime(a.time);
                    final bTime = _parseTime(b.time);
                    final aDateTime = aDate.add(
                      Duration(hours: aTime.hour, minutes: aTime.minute),
                    );
                    final bDateTime = bDate.add(
                      Duration(hours: bTime.hour, minutes: bTime.minute),
                    );
                    return bDateTime.compareTo(aDateTime);
                  });

                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 16.h,
                    ),
                    itemCount: allAppointments.length,
                    itemBuilder: (context, index) {
                      final appointment = allAppointments[index];
                      final appointmentDate = DateTime(
                        appointment.date.year,
                        appointment.date.month,
                        appointment.date.day,
                      );
                      final isPast = appointmentDate.isBefore(today);

                      return Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: _buildAppointmentCard(
                          appointment: appointment,
                          isPast: isPast,
                        ),
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

  Widget _buildAppointmentCard({
    required AppointmentModel appointment,
    required bool isPast,
  }) {
    final patientController = Get.find<PatientController>();
    final doctorName = appointment.doctorName.isNotEmpty
        ? appointment.doctorName
        : (patientController.myDoctor.value?['name'] ?? 'الطبيب');

    // تنسيق التاريخ
    final dateFormat = DateFormat('dd-MM-yyyy', 'ar');
    final formattedDate = dateFormat.format(appointment.date);

    // أسماء الأيام بالعربية
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

    // تنسيق الوقت
    final timeParts = appointment.time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? timeParts[1] : '00';
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeText = '$displayHour:$minute';
    final periodText = isPM ? 'مساءاً' : 'صباحاً';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: isPast ? Colors.grey[200] : AppColors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Spacing where image was (to prevent text from sticking to edge)
              SizedBox(width: 6.w),
              // Line 1: Doctor name text
              RichText(
                text: TextSpan(
                  style: GoogleFonts.cairo(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: isPast
                          ? 'موعدك السابق مع الدكتور "'
                          : 'موعدك القادم مع الدكتور "',
                    ),
                    TextSpan(
                      text: doctorName,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                    TextSpan(text: '" هو'),
                  ],
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(right: 10.w),
            // Appointment Details
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),
                // Line 2: Date row - "يوم الثلاثاء المصادف" + icon + date
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'يوم $dayName المصادف',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    SizedBox(width: 4.w),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.calendar_today,
                      size: 14.sp,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // Line 3: Time row - "في تمام الساعة" + blue button with time + period
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'في تمام الساعة',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      periodText,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: Text(
              'الرجاء الحضور قبل الموعد بنصف ساعة',
              textAlign: TextAlign.right,
              style: GoogleFonts.cairo(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color.fromARGB(255, 71, 148, 184),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
