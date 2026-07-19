import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/services/chat_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class _HomeAssets {
  static const chat = 'assets/icon/chatddd.png';
  static const notif = 'assets/icon/notd.png';
  static const moon = 'assets/icon/Moon.png';
  static const sun = 'assets/icon/sun.png';
  static const heroBg =
      'assets/icon/ChatGPT Image Jul 11, 2026, 06_28_08 PM.png';
  static const implant = 'assets/icon/implanticon.png';
  static const dateIcon = 'assets/icon/date23.png';
}

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _grayText = Color(0xFF8A97A8);
  static const double _headerBoxSize = 50;
  static const double _headerBoxRadius = 16;

  static List<BoxShadow> get _headerBoxShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 8,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
      ];

  BoxDecoration get _headerBoxDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_headerBoxRadius.r),
        boxShadow: _headerBoxShadow,
      );

  final ChatService _chatService = ChatService();
  final RxInt _unreadCount = 0.obs;
  final RxInt _unreadNotificationsCount = 0.obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnreadCount();
      _loadUnreadNotificationsCount();
      _loadData();
    });
  }

  void _loadData() {
    final patientController = Get.find<PatientController>();
    final appointmentController = Get.find<AppointmentController>();

    patientController.loadMyProfile().catchError((e) {
      debugPrint('❌ [PatientHomeScreen] Error loading profile: $e');
    });
    appointmentController.loadPatientAppointments().catchError((e) {
      debugPrint('❌ [PatientHomeScreen] Error loading appointments: $e');
    });
    patientController.loadMyDoctors().catchError((e) {
      debugPrint('❌ [PatientHomeScreen] Error loading doctors: $e');
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final chatList = await _chatService.getChatList();
      if (chatList.isNotEmpty) {
        _unreadCount.value = chatList[0]['unread_count'] as int? ?? 0;
      } else {
        _unreadCount.value = 0;
      }
    } catch (e) {
      _unreadCount.value = 0;
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    try {
      final appointmentController = Get.find<AppointmentController>();
      int count = 0;
      final upcoming = appointmentController.getUpcomingAppointments();

      try {
        final box = await Hive.openBox('read_notifications');
        for (final appointment in upcoming) {
          final notificationId = 'appointment_${appointment.id}';
          final isRead = box.get(notificationId, defaultValue: false) as bool;
          if (!isRead) count++;
        }
      } catch (e) {
        count = upcoming.length;
      }

      count += _unreadCount.value;
      _unreadNotificationsCount.value = count;
    } catch (e) {
      _unreadNotificationsCount.value = 0;
    }
  }

  bool get _isMorning => DateTime.now().hour < 12;

  String _greeting() {
    if (_isMorning) return 'صبــاح الخــير';
    return 'مساء الخير';
  }

  String _greetingIcon() => _isMorning ? _HomeAssets.sun : _HomeAssets.moon;

  /// رسائل اليوم — تتغير مع بداية كل يوم جديد (بعد 12:00 منتصف الليل)
  static const List<String> _dailyMessages = [
    'اليوم بداية ابتسامة جديدة',
    'عنايتك تصنع فرقًا دائمًا',
    'اسنان صحية لحياة سعيدة',
    'ابدأ يومك بابتسامة مشرقة',
    'ثقتك تبدأ بابتسامتك الجميلة',
    'العناية تصنع ابتسامة تدوم',
    'صحتك الفموية أولويتنا دائمًا',
    'كل موعد خطوة للأفضل',
    'لأن ابتسامتك تستحق الأفضل',
    'أسنان أقوى ابتسامة أجمل',
    'جمالك يبدأ بابتسامتك دائمًا',
  ];

  /// كلمتان في السطر الأول والباقي في السطر الثاني
  (String line1, String line2) _dailyMessageLines() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayIndex =
        today.difference(DateTime(2020, 1, 1)).inDays.abs();
    final message = _dailyMessages[dayIndex % _dailyMessages.length];
    final words = message.trim().split(RegExp(r'\s+'));

    if (words.length <= 2) {
      return (message, '');
    }

    return (
      words.take(2).join(' '),
      words.skip(2).join(' '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final patientController = Get.find<PatientController>();
    final appointmentController = Get.find<AppointmentController>();

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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 28.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(authController, patientController),
                SizedBox(height: 18.h),
                _buildHeroBanner(appointmentController),
                SizedBox(height: 10.h),
                _buildDoctorsSection(patientController, appointmentController),
                SizedBox(height: 10.h),
                _buildImplantSection(patientController),
                SizedBox(height: 10.h),
                _buildAppointmentsSection(appointmentController),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    AuthController authController,
    PatientController patientController,
  ) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Obx(() {
              final user = authController.currentUser.value;
              final profile = patientController.myProfile.value;
              final patientName = user?.name ?? profile?.name ?? 'مريض';
              final imageUrl = ImageUtils.convertToValidUrl(
                user?.imageUrl ?? profile?.imageUrl,
              );

              return Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => Get.toNamed(AppRoutes.patientProfile),
                        child: Container(
                          width: _headerBoxSize.w,
                          height: _headerBoxSize.h,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(_headerBoxRadius.r),
                            boxShadow: _headerBoxShadow,
                            color: AppColors.primaryLight,
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(_headerBoxRadius.r),
                            child: imageUrl != null &&
                                    ImageUtils.isValidImageUrl(imageUrl)
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: _headerBoxSize.w,
                                    height: _headerBoxSize.h,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                      size: 24.sp,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 24.sp,
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2.h,
                        right: 2.w,
                        child: Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحبا ، $patientName',
                          style: AppFonts.lamaSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppStrings.welcomeToClinic,
                          style: AppFonts.lamaSans(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: _grayText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          SizedBox(width: 10.w),
          Obx(() => _headerIconButton(
                asset: _HomeAssets.chat,
                showBadge: _unreadCount.value > 0,
                onTap: () => _openChat(patientController),
              )),
          SizedBox(width: 10.w),
          Obx(() => _headerIconButton(
                asset: _HomeAssets.notif,
                showBadge: _unreadNotificationsCount.value > 0,
                onTap: () async {
                  await Get.toNamed(AppRoutes.notifications);
                  _loadUnreadNotificationsCount();
                },
              )),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required String asset,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _headerBoxSize.w,
            height: _headerBoxSize.h,
            decoration: _headerBoxDecoration,
            child: Center(
              child: Image.asset(
                asset,
                width: 28.w,
                height: 28.w,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: 6.h,
              left: 6.w,
              child: Container(
                width: 9.w,
                height: 9.w,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openChat(PatientController patientController) async {
    final doctors = patientController.myDoctors;
    final profile = patientController.myProfile.value;
    if (doctors.isEmpty || profile == null) return;

    final doctor = doctors.first;
    final doctorId = doctor['id'];
    final doctorName = doctor['name'] ?? 'طبيبك';
    if (doctorId == null) return;

    await Get.toNamed(
      AppRoutes.chat,
      arguments: {
        'patientId': profile.id,
        'doctorId': doctorId.toString(),
        'doctorName': 'د. $doctorName',
      },
    );
    await Future.delayed(const Duration(milliseconds: 300));
    _loadUnreadCount();
  }

  Widget _buildHeroBanner(AppointmentController appointmentController) {
    return Obx(() {
      final todayCount = appointmentController.getTodayAppointments().length;
      final countText = todayCount == 0
          ? 'لا توجد مواعيد اليوم'
          : 'لديك موعد اليوم';

      return ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Container(
          height: 235.h,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_HomeAssets.heroBg),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.25),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Directionality(
                      textDirection: ui.TextDirection.rtl,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              _greetingIcon(),
                              width: 35.w,
                              height: 35.h,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              _greeting(),
                              style: AppFonts.lamaSans(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Builder(
                      builder: (context) {
                        final (line1, line2) = _dailyMessageLines();
                        return Directionality(
                          textDirection: ui.TextDirection.rtl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line1,
                                textAlign: TextAlign.right,
                                style: AppFonts.lamaSans(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              if (line2.isNotEmpty) ...[
                                SizedBox(height: 6.h),
                                Text(
                                  line2,
                                  textAlign: TextAlign.right,
                                  style: AppFonts.lamaSans(
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 10.h),
                    Directionality(
                      textDirection: ui.TextDirection.rtl,
                      child: Text(
                        countText,
                        textAlign: TextAlign.right,
                        style: AppFonts.lamaSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: GestureDetector(
                        onTap: () =>
                            Get.toNamed(AppRoutes.patientAppointments),
                        child: Container(
                          width: 169.w,
                          height: 43.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D9D9)
                                .withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Directionality(
                            textDirection: ui.TextDirection.rtl,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.white,
                                  size: 18.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'عرض جدول المواعيد',
                                  style: AppFonts.lamaSans(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDoctorsSection(
    PatientController patientController,
    AppointmentController appointmentController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الاطباء الخاصين بك',
          textAlign: TextAlign.right,
          style: AppFonts.lamaSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
        SizedBox(height: 10.h),
        Obx(() {
          final doctors = patientController.myDoctors;
          if (doctors.isEmpty) {
            return _emptyCard('لا يوجد أطباء مرتبطين');
          }

          return Column(
            children: [
              for (var i = 0; i < doctors.length; i++) ...[
                _buildDoctorCard(
                  doctor: doctors[i],
                  doctorName: doctors[i]['name']?.toString().isNotEmpty == true
                      ? doctors[i]['name']!
                      : 'طبيبك',
                  nextVisitText: _formatNextVisit(
                    _nextAppointmentForDoctor(
                      doctors[i]['id']?.toString(),
                      appointmentController,
                    ),
                  ),
                  patientController: patientController,
                ),
                if (i < doctors.length - 1) SizedBox(height: 10.h),
              ],
            ],
          );
        }),
      ],
    );
  }

  Widget _buildDoctorCard({
    required Map<String, dynamic> doctor,
    required String doctorName,
    required String nextVisitText,
    required PatientController patientController,
  }) {
    final doctorImageUrl = ImageUtils.convertToValidUrl(doctor['imageUrl']);

    return Container(
      height: 100.h,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30.r),
              child: Container(
                width: 80.w,
                height: 80.h,
                color: AppColors.primaryLight,
                child: doctorImageUrl != null &&
                        ImageUtils.isValidImageUrl(doctorImageUrl)
                    ? CachedNetworkImage(
                        imageUrl: doctorImageUrl,
                        width: 80.w,
                        height: 80.h,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 32.sp,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 32.sp,
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'د. $doctorName',
                    style: AppFonts.lamaSans(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF012668),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    nextVisitText,
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
              onTap: () async {
                final profile = patientController.myProfile.value;
                final doctorId = doctor['id'];
                if (profile != null && doctorId != null) {
                  await Get.toNamed(
                    AppRoutes.chat,
                    arguments: {
                      'patientId': profile.id,
                      'doctorId': doctorId.toString(),
                      'doctorName': 'د. $doctorName',
                    },
                  );
                  await Future.delayed(const Duration(milliseconds: 300));
                  _loadUnreadCount();
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F8),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFF022568).withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Image.asset(
                        _HomeAssets.chat,
                        width: 24.w,
                        height: 24.w,
                      ),
                    ),
                  ),
                  Obx(() {
                    if (_unreadCount.value <= 0) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      top: 4.h,
                      left: 4.w,
                      child: Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImplantSection(PatientController patientController) {
    return Obx(() {
      final profile = patientController.myProfile.value;
      final hasImplant =
          profile?.treatmentHistory?.contains(AppStrings.implant) ?? false;
      if (!hasImplant) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مواعيد الزراعة',
            textAlign: TextAlign.right,
            style: AppFonts.lamaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.dentalImplantTimeline),
            child: Container(
              height: 100.h,
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color(0xFFF3F5F8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: Offset.zero,
                  ),
                ],
              ),
              child: Directionality(
                textDirection: ui.TextDirection.rtl,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80.w,
                      height: 69.h,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          ImageFiltered(
                            imageFilter:
                                ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 80.w,
                              height: 61.h,
                              color: const Color(0xFF649FCC)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          Image.asset(
                            _HomeAssets.implant,
                            width: 73.w,
                            height: 69.h,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'مواعيد زراعة الاسنان',
                            style: AppFonts.lamaSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'تابع مراحل زراعة اسنانك خطوة ب خطوة',
                            style: AppFonts.lamaSans(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: _grayText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34.w,
                      height: 34.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: Offset.zero,
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: 3.14159265359,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: const Color(0xFF032252),
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildAppointmentsSection(AppointmentController appointmentController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Row(
            children: [
              Text(
                AppStrings.appointments,
                style: AppFonts.lamaSans(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.patientAppointments),
                child: Text(
                  AppStrings.viewAll,
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _grayText,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Obx(() {
          final upcoming = appointmentController.getUpcomingAppointments();
          if (upcoming.isEmpty) {
            return _emptyCard('لا توجد مواعيد حالياً');
          }
          return _buildAppointmentCard(appointment: upcoming.first);
        }),
      ],
    );
  }

  Widget _buildAppointmentCard({required AppointmentModel appointment}) {
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
    final monthYear =
        DateFormat('MMMM yyyy', 'ar').format(appointment.date);

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
                    padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
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
                            color: _grayText,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          dayNumber,
                          style: AppFonts.lamaSans(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w800,
                            color: _navy,
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
                            color: _grayText,
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
                              color: _navy,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            serviceText,
                            style: AppFonts.lamaSans(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: _grayText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timeText,
                          style: AppFonts.lamaSans(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        Text(
                          periodText,
                          style: AppFonts.lamaSans(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: _grayText,
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
                    _HomeAssets.dateIcon,
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
                      color: _grayText,
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

  Widget _emptyCard(String message) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Center(
        child: Text(
          message,
          style: AppFonts.lamaSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: _grayText,
          ),
        ),
      ),
    );
  }

  AppointmentModel? _nextAppointmentForDoctor(
    String? doctorId,
    AppointmentController controller,
  ) {
    if (doctorId == null) return null;
    final upcoming = controller.getUpcomingAppointments();
    for (final appt in upcoming) {
      if (appt.doctorId == doctorId) return appt;
    }
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  String _formatNextVisit(AppointmentModel? appointment) {
    if (appointment == null) return 'لا توجد زيارة قادمة';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(
      appointment.date.year,
      appointment.date.month,
      appointment.date.day,
    );

    final timeParts = appointment.time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? timeParts[1] : '00';
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = isPM ? 'م' : 'ص';
    final timeText = '$displayHour:$minute $period';

    if (apptDay == today) {
      return 'الزيارة القادمة اليوم $timeText';
    }

    final dateText = DateFormat('d/M', 'ar').format(appointment.date);
    return 'الزيارة القادمة $dateText $timeText';
  }
}
