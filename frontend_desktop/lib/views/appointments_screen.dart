import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';
import 'package:frontend_desktop/controllers/appointment_controller.dart';
import 'package:frontend_desktop/controllers/patient_controller.dart';
import 'package:frontend_desktop/models/appointment_model.dart';
import 'package:frontend_desktop/core/widgets/loading_widget.dart';
import 'package:frontend_desktop/core/widgets/empty_state_widget.dart';
import 'package:frontend_desktop/core/widgets/back_button_widget.dart';
import 'package:frontend_desktop/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Delegate for sticky TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final appointmentController = Get.find<AppointmentController>();
    final patientController = Get.find<PatientController>();

    // Load appointments and patients on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appointmentController.loadDoctorAppointments();
      // Load patients to get their names and images
      if (patientController.patients.isEmpty) {
        // استخدام التحميل الذكي لضمان توفر أحدث قائمة للمرضى
        patientController.loadPatientsSmart();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFF),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder:
                    (BuildContext context, bool innerBoxIsScrolled) {
                      return <Widget>[
                        // Header
                        SliverAppBar(
                          backgroundColor: const Color(0xFFF4FEFF),
                          pinned: false,
                          floating: false,
                          expandedHeight: 0,
                          toolbarHeight: 80.h,
                          automaticallyImplyLeading: false,
                          flexibleSpace: Container(
                            color: const Color(0xFFF4FEFF),
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 16.h,
                            ),
                            child: Row(
                              textDirection: ui.TextDirection.ltr,
                              children: [
                                // Back button always on the LEFT
                                const BackButtonWidget(),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      AppStrings.appointments,
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                // Filter button on the RIGHT
                                GestureDetector(
                                  onTap: () => _showDateFilterDialog(context),
                                  child: Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Icon(
                                      Icons.filter_list,
                                      color: AppColors.primary,
                                      size: 24.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Tabs - Sticky Header
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverTabBarDelegate(
                            child: Container(
                              height: 48.0,
                              margin: EdgeInsets.symmetric(horizontal: 24.w),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicator: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 2,
                                  ),
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                labelColor: AppColors.white,
                                unselectedLabelColor: AppColors.textSecondary,
                                labelStyle: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                unselectedLabelStyle: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.normal,
                                ),
                                tabs: const [
                                  Tab(text: 'المتأخرون'),
                                  Tab(text: 'هذا الشهر'),
                                  Tab(text: 'اليوم'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ];
                    },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAppointmentsList('المتأخرون'),
                    _buildAppointmentsList('هذا الشهر'),
                    _buildAppointmentsList('اليوم'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(String filter) {
    final appointmentController = Get.find<AppointmentController>();

    return Obx(() {
      if (appointmentController.isLoading.value) {
        return const LoadingWidget(message: 'جاري تحميل المواعيد...');
      }

      List<AppointmentModel> filteredAppointments = [];
      String emptyMessage = '';

      switch (filter) {
        case 'اليوم':
          filteredAppointments = appointmentController.getTodayAppointments();
          emptyMessage = 'لا توجد مواعيد اليوم';
          break;
        case 'المتأخرون':
          filteredAppointments = appointmentController.getLateAppointments();
          emptyMessage = 'لا توجد مواعيد متأخرة';
          break;
        case 'هذا الشهر':
          filteredAppointments = appointmentController.getThisMonthAppointments();
          emptyMessage = 'لا توجد مواعيد هذا الشهر';
          break;
      }

      // ترتيب المواعيد حسب التاريخ
      filteredAppointments.sort((a, b) => a.date.compareTo(b.date));

      if (filteredAppointments.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.calendar_today_outlined,
          title: emptyMessage,
          subtitle: 'لم يتم العثور على مواعيد',
        );
      }

      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        itemCount: filteredAppointments.length,
        itemBuilder: (context, index) {
          final appointment = filteredAppointments[index];
          final now = DateTime.now();
          final status = appointment.status.toLowerCase();
          final isPast =
              appointment.date.isBefore(now) ||
              status == 'completed' ||
              status == 'cancelled' ||
              status == 'no_show';

          // "متأخر" = موعد قبل الآن ولسه حالته scheduled/pending
          final isLate = filter == 'المتأخرون' ||
              (appointment.date.isBefore(now) &&
                  (status == 'scheduled' || status == 'pending'));

          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: _buildAppointmentCard(
              appointment: appointment,
              isPast: isPast,
              isLate: isLate,
            ),
          );
        },
      );
    });
  }

  Widget _buildAppointmentCard({
    required AppointmentModel appointment,
    required bool isPast,
    bool isLate = false,
  }) {
    final patientController = Get.find<PatientController>();

    final patient = patientController.getPatientById(appointment.patientId);
    final patientName = patient?.name ?? appointment.patientName;
    final patientImageUrl = patient?.imageUrl;
    final String? patientPhone = patient?.phoneNumber;
    final strokeColor =
        isLate ? Colors.red : AppColors.primary.withOpacity(0.3);

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
                  final validImageUrl = ImageUtils.convertToValidUrl(patientImageUrl);
                  final hasImage = validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl);
                  
                  return Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: strokeColor,
                        width: 1,
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

              // Line 1: Patient name text
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: 'موعد مريضك "'),
                      TextSpan(
                        text: patientName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary.withOpacity(0.8),
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
                        color: AppColors.primary.withOpacity(0.7),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          patientPhone,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary.withOpacity(0.8),
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
                        color: AppColors.primary.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.calendar_today,
                      size: 14.sp,
                      color: AppColors.primary.withOpacity(0.7),
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

  void _showDateFilterDialog(BuildContext context) {
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'اختر التاريخ',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      height: 300.h,
                      width: double.infinity,
                      child: CalendarDatePicker(
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        onDateChanged: (date) {
                          setDialogState(() {
                            selectedDate = date;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'إلغاء',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (selectedDate != null) {
                              Navigator.of(context).pop();
                              // Reload appointments for selected date
                              final appointmentController =
                                  Get.find<AppointmentController>();
                              appointmentController.loadDoctorAppointments();
                              Get.snackbar(
                                'تم',
                                'تم تحميل المواعيد للتاريخ المحدد',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppColors.primary,
                                colorText: AppColors.white,
                              );
                            } else {
                              Get.snackbar(
                                'تنبيه',
                                'يرجى اختيار تاريخ',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.orange,
                                colorText: AppColors.white,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: Text(
                            'عرض المواعيد',
                            style: TextStyle(color: AppColors.white),
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
}
