import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppointmentsByDateScreen extends StatefulWidget {
  const AppointmentsByDateScreen({super.key});

  @override
  State<AppointmentsByDateScreen> createState() =>
      _AppointmentsByDateScreenState();
}

class _AppointmentsByDateScreenState extends State<AppointmentsByDateScreen> {
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    // Get date from arguments
    final args = Get.arguments as Map<String, dynamic>?;
    selectedDate = args?['date'] as DateTime?;

    if (selectedDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAppointmentsForDate(selectedDate!);
      });
    }
  }

  void _loadAppointmentsForDate(DateTime date) async {
    final appointmentController = Get.find<AppointmentController>();
    final patientController = Get.find<PatientController>();

    // Normalize date to local date (remove time component)
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateFromStr = DateFormat('yyyy-MM-dd').format(normalizedDate);

    // date_to should be the next day (backend uses scheduled_at < end)
    final nextDay = normalizedDate.add(const Duration(days: 1));
    final dateToStr = DateFormat('yyyy-MM-dd').format(nextDay);

    // Load appointments for the selected date
    await appointmentController.loadDoctorAppointments(
      dateFrom: dateFromStr,
      dateTo: dateToStr,
    );

    // Load patients to get their names and images
    if (patientController.patients.isEmpty) {
      patientController.loadPatients();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentController = Get.find<AppointmentController>();
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    final formattedDate = selectedDate != null
        ? dateFormat.format(selectedDate!)
        : '';

    final baseTheme = Theme.of(context);
    final cairoTheme = baseTheme.copyWith(
      textTheme: AppFonts.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppFonts.textTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: cairoTheme,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Row(
                textDirection: ui.TextDirection.ltr,
                children: [
                  const BackButtonWidget(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'مواعيد $formattedDate',
                        style: AppFonts.lamaSans(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            // Appointments List
            Expanded(
              child: Obx(() {
                if (appointmentController.isLoading.value) {
                  return const LoadingWidget(message: 'جاري تحميل المواعيد...');
                }

                if (selectedDate == null) {
                  return EmptyStateWidget(
                    icon: Icons.calendar_today_outlined,
                    title: 'لم يتم اختيار تاريخ',
                    subtitle: 'يرجى اختيار تاريخ',
                  );
                }

                // Normalize selected date (remove time component)
                final normalizedSelectedDate = DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                );

                // Debug: Print all appointments and selected date
                print(
                  '🔍 [AppointmentsByDate] Selected date: $normalizedSelectedDate',
                );
                print(
                  '🔍 [AppointmentsByDate] Total appointments loaded: ${appointmentController.appointments.length}',
                );

                final appointments = appointmentController.appointments.where((
                  apt,
                ) {
                  // Normalize appointment date (remove time component)
                  final aptDate = DateTime(
                    apt.date.year,
                    apt.date.month,
                    apt.date.day,
                  );

                  // Debug: Print each appointment date
                  final matches =
                      aptDate.year == normalizedSelectedDate.year &&
                      aptDate.month == normalizedSelectedDate.month &&
                      aptDate.day == normalizedSelectedDate.day;

                  if (matches) {
                    print(
                      '✅ [AppointmentsByDate] Found matching appointment: ${apt.date}',
                    );
                  }

                  return matches;
                }).toList()..sort((a, b) => a.date.compareTo(b.date));

                print(
                  '🔍 [AppointmentsByDate] Filtered appointments count: ${appointments.length}',
                );

                if (appointments.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.calendar_today_outlined,
                    title: 'لا توجد مواعيد في هذا التاريخ',
                    subtitle: 'لم يتم العثور على مواعيد',
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appointment = appointments[index];
                    final now = DateTime.now();
                    final status = appointment.status.toLowerCase();
                    final isPast =
                        appointment.date.isBefore(now) ||
                        status == 'completed' ||
                        status == 'cancelled' ||
                        status == 'no_show';

                    final isLate = appointment.date.isBefore(now) &&
                        (status == 'scheduled' || status == 'pending');

                    return Padding(
                      padding: EdgeInsets.only(bottom: 16.h),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildAppointmentCard(
                          appointment: appointment,
                          isPast: isPast,
                          isLate: isLate,
                        ),
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
    bool isLate = false,
  }) {
    final patientController = Get.find<PatientController>();
    final authController = Get.find<AuthController>();
    final userType = authController.currentUser.value?.userType;
    final isReceptionist = userType == 'receptionist';

    final patient = patientController.getPatientById(appointment.patientId);
    final patientName = patient?.name ?? appointment.patientName;
    final patientImageUrl = patient?.imageUrl;
    final String? patientPhone = patient?.phoneNumber;
    final doctorName = appointment.doctorName;
    final strokeColor =
        isLate ? Colors.red : AppColors.primary.withValues(alpha: 0.3);

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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: strokeColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Patient Image (on the right in RTL)
              Builder(
                builder: (context) {
                  final validImageUrl =
                      ImageUtils.convertToValidUrl(patientImageUrl);
                  final hasImage = validImageUrl != null &&
                      ImageUtils.isValidImageUrl(validImageUrl);
                  
                  return Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: strokeColor,
                        width: 1, // stroke 1
                      ),
                    ),
                    child: ClipOval(
                      child: hasImage
                          ? CachedNetworkImage(
                              imageUrl: validImageUrl,
                              fit: BoxFit.cover,
                              width: 40.w,
                              height: 40.w,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              memCacheWidth: 60,
                              memCacheHeight: 80,
                              placeholder: (context, url) => Container(
                                color: const Color.fromARGB(255, 255, 255, 255),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.divider,
                                child: Icon(
                                  Icons.person,
                                  color: AppColors.textSecondary,
                                  size: 20.sp,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.divider,
                              child: Icon(
                                Icons.person,
                                color: AppColors.textSecondary,
                                size: 20.sp,
                              ),
                            ),
                    ),
                  );
                },
              ),
              SizedBox(width: 4.w),

              // Line 1: Patient name text (same as appointments screen)
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppFonts.lamaSans(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                    children: isReceptionist
                        ? [
                            const TextSpan(text: 'موعد المريض "'),
                            TextSpan(
                              text: patientName,
                              style: AppFonts.lamaSans(
                                fontWeight: FontWeight.w600,
                                color:
                                    AppColors.primary.withValues(alpha: 0.8),
                              ),
                            ),
                            const TextSpan(text: '" مع الطبيب "'),
                            TextSpan(
                              text: doctorName,
                              style: AppFonts.lamaSans(
                                fontWeight: FontWeight.w600,
                                color:
                                    AppColors.primary.withValues(alpha: 0.8),
                              ),
                            ),
                            const TextSpan(text: '"'),
                          ]
                        : [
                            const TextSpan(text: 'موعد مريضك "'),
                            TextSpan(
                              text: patientName,
                              style: AppFonts.lamaSans(
                                fontWeight: FontWeight.w600,
                                color:
                                    AppColors.primary.withValues(alpha: 0.8),
                              ),
                            ),
                            TextSpan(text: isPast ? '" السابق هو' : '" القادم هو'),
                          ],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          if (patientPhone != null && patientPhone.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.phone,
                        size: 14.sp,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          patientPhone,
                          style: AppFonts.lamaSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.only(right: 10.w),
            // Appointment Details
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4.h),
                // Line 2: Date row - "يوم الثلاثاء المصادف" + icon + date
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'يوم $dayName المصادف',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    SizedBox(width: 4.w),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 14.sp,
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
                SizedBox(height: 4.h),
                // Line 3: Time row - "في تمام الساعة" + blue button with time + period
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'في تمام الساعة',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    SizedBox(width: 4.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 4.h,
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
                    SizedBox(width: 4.w),
                    Text(
                      periodText,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
