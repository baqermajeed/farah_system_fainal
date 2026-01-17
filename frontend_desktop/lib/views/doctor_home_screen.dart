import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/routes/app_routes.dart';
import 'package:frontend_desktop/controllers/patient_controller.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/controllers/medical_record_controller.dart';
import 'package:frontend_desktop/controllers/gallery_controller.dart';
import 'package:frontend_desktop/controllers/appointment_controller.dart';
import 'package:frontend_desktop/controllers/working_hours_controller.dart';
import 'package:frontend_desktop/controllers/implant_stage_controller.dart';
import 'package:frontend_desktop/services/working_hours_service.dart';
import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/models/appointment_model.dart';
import 'package:frontend_desktop/models/implant_stage_model.dart';
import 'package:frontend_desktop/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Delegate for sticky TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final PatientController _patientController = Get.put(PatientController());
  final AuthController _authController = Get.put(AuthController());
  final MedicalRecordController _medicalRecordController = Get.put(
    MedicalRecordController(),
  );
  final GalleryController _galleryController = Get.put(GalleryController());
  final AppointmentController _appointmentController = Get.put(
    AppointmentController(),
  );
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController; // For patient file tabs
  late TabController _appointmentsTabController; // For appointments tabs
  final RxInt _currentTabIndex = 0.obs;
  final RxBool _showAppointments =
      false.obs; // Track if appointments should be shown

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _appointmentsTabController = TabController(length: 3, vsync: this);
    // Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _currentTabIndex.value = _tabController.index;
      }
    });
    // Load patients on init
    _patientController.loadPatients();
    // Load appointments on init
    _appointmentController.loadDoctorAppointments();
    // Listen to patient selection changes
    ever(_patientController.selectedPatient, (patient) {
      if (patient != null) {
        // Load records, gallery, and appointments when a patient is selected
        _medicalRecordController.loadPatientRecords(patient.id);
        _galleryController.loadGallery(patient.id);
        _appointmentController.loadPatientAppointmentsById(patient.id);

        // Load implant stages if treatment type is زراعة
        if (patient.treatmentHistory != null &&
            patient.treatmentHistory!.isNotEmpty &&
            patient.treatmentHistory!.last == 'زراعة') {
          final implantStageController = Get.put(ImplantStageController());
          implantStageController.ensureStagesLoaded(patient.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _appointmentsTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFF),
      body: Row(
        children: [
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Bar (Header)
                _buildTopBar(),

                // Content Area
                Expanded(
                  child: Row(
                    children: [
                      // Left Side - Appointments Table or Patient File
                      Expanded(
                        flex: 2,
                        child: Obx(() {
                          final selectedPatient =
                              _patientController.selectedPatient.value;
                          if (selectedPatient != null) {
                            _showAppointments.value = false;
                            return _buildPatientFile(selectedPatient);
                          } else if (_showAppointments.value) {
                            return _buildAppointmentsTable();
                          } else {
                            return _buildWelcomeState();
                          }
                        }),
                      ),

                      // Right Side - Patients List
                      _buildPatientsListSidebar(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right Sidebar Navigation (FARAH Logo)
          _buildRightSidebarNavigation(),
        ],
      ),
    );
  }

  // --- Widgets Components ---

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // First Row: Logo, Center Title, Profile
          Row(
            children: [
              // Logo in top left
              Image.asset(
                'assets/images/logo.png',
                width: 50.w,
                height: 50.h,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50.w,
                    height: 50.h,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      color: Colors.white,
                    ),
                  );
                },
              ),

              const Spacer(),

              // Center Title
              Text(
                'الصفحة الرئيسية',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),

              const Spacer(),

              // Right Side - Profile Section
              GestureDetector(
                onTap: () {
                  Get.toNamed(AppRoutes.doctorProfile);
                },
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(() {
                          final user = _authController.currentUser.value;
                          return Text(
                            user?.name ?? 'د. مهند المالكي',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          );
                        }),
                      ],
                    ),
                    SizedBox(width: 12.w),
                    Obx(() {
                      final user = _authController.currentUser.value;
                      final imageUrl = user?.imageUrl;
                      final validImageUrl = ImageUtils.convertToValidUrl(
                        imageUrl,
                      );

                      return CircleAvatar(
                        radius: 30.r,
                        backgroundColor: AppColors.primaryLight,
                        child:
                            validImageUrl != null &&
                                ImageUtils.isValidImageUrl(validImageUrl)
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: validImageUrl,
                                  fit: BoxFit.cover,
                                  width: 60.w,
                                  height: 60.h,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  placeholder: (context, url) => Container(
                                    color: AppColors.primaryLight,
                                    child: Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                      size: 30.sp,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    final name =
                                        user?.name ?? 'د. مهند المالكي';
                                    return Container(
                                      color: AppColors.primaryLight,
                                      child: Text(
                                        name.isNotEmpty ? name[0] : 'د',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 22.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0]
                                    : 'د',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // Second Row: Icons and Search Bar
          Row(
            children: [
              const Spacer(),
              // Action Icons on the left
              GestureDetector(
                onTap: () {
                  // Navigate to add patient screen
                  Get.toNamed(AppRoutes.addPatient)?.then((result) {
                    // Reload patients when returning from add patient screen
                    if (result == true) {
                      _patientController.loadPatients();
                    }
                  });
                },
                child: _buildActionIcon(Icons.person_add_outlined),
              ),
              SizedBox(width: 15.w),
              GestureDetector(
                onTap: () {
                  // Clear selected patient and show appointments table
                  _patientController.selectPatient(null);
                  _showAppointments.value = true;
                },
                child: _buildActionIcon(Icons.calendar_today_outlined),
              ),
              SizedBox(width: 30.w),
              // Search Bar on the right
              Container(
                width: 721.w,
                height: 45.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F9),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مريض....',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14.sp,
                    ),
                    suffixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[400],
                      size: 20.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 12.h,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Container(
      color: const Color(0xFFF4FEFF),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Welcome text with icons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Tooth icon
                Icon(
                  Icons.health_and_safety_outlined,
                  color: Colors.white,
                  size: 24.sp,
                ),
                SizedBox(width: 8.w),
                // Lips icon
                Icon(Icons.favorite, color: Colors.red, size: 24.sp),
                SizedBox(width: 12.w),
                // Welcome text
                Text(
                  'مرحباً... نتمنى لك يوماً مليئاً بالابتسامات .',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 60.h),
            // Tooth image with sparkles
            Stack(
              alignment: Alignment.center,
              children: [
                // Sparkle icons around the tooth
                Positioned(
                  top: -20.h,
                  left: 50.w,
                  child: Icon(
                    Icons.star,
                    color: Colors.yellow[700],
                    size: 30.sp,
                  ),
                ),
                Positioned(
                  top: 30.h,
                  right: 80.w,
                  child: Icon(
                    Icons.star,
                    color: Colors.yellow[700],
                    size: 25.sp,
                  ),
                ),
                Positioned(
                  bottom: 20.h,
                  left: 70.w,
                  child: Icon(
                    Icons.star,
                    color: Colors.yellow[700],
                    size: 28.sp,
                  ),
                ),
                // Main tooth image
                Image.asset(
                  'assets/images/clean_teeth.png',
                  width: 400.w,
                  height: 400.h,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 400.w,
                      height: 400.h,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                      child: const Icon(
                        Icons.local_hospital,
                        color: Colors.white,
                        size: 150,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsTable() {
    return Container(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'جدول المواعيد',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 20.h),
          // Tabs
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
            ),
            child: TabBar(
              controller: _appointmentsTabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.white, width: 2),
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
                Tab(text: 'اليوم'),
                Tab(text: 'هذا الشهر'),
                Tab(text: 'المتأخرون'),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          // Table Content
          Expanded(
            child: TabBarView(
              controller: _appointmentsTabController,
              children: [
                _buildAppointmentsTableContent('اليوم'),
                _buildAppointmentsTableContent('هذا الشهر'),
                _buildAppointmentsTableContent('المتأخرون'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTableContent(String filter) {
    return Obx(() {
      if (_appointmentController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      List<AppointmentModel> filteredAppointments = [];
      String emptyMessage = '';

      switch (filter) {
        case 'اليوم':
          filteredAppointments = _appointmentController.getTodayAppointments();
          emptyMessage = 'لا توجد مواعيد اليوم';
          break;
        case 'المتأخرون':
          filteredAppointments = _appointmentController.getLateAppointments();
          emptyMessage = 'لا توجد مواعيد متأخرة';
          break;
        case 'هذا الشهر':
          filteredAppointments = _appointmentController
              .getThisMonthAppointments();
          emptyMessage = 'لا توجد مواعيد هذا الشهر';
          break;
      }

      // ترتيب المواعيد حسب التاريخ
      filteredAppointments.sort((a, b) => a.date.compareTo(b.date));

      if (filteredAppointments.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 60.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 16.h),
              Text(
                emptyMessage,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  topRight: Radius.circular(12.r),
                ),
              ),
              child: Row(
                children: [
                  // اسم المريض (على اليمين)
                  Expanded(
                    flex: 3,
                    child: Text(
                      'اسم المريض',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // الموعد
                  Expanded(
                    flex: 2,
                    child: Text(
                      'الموعد',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // رقم الهاتف
                  Expanded(
                    flex: 2,
                    child: Text(
                      'رقم الهاتف',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // زر العرض
                  Expanded(
                    flex: 1,
                    child: Text(
                      'عرض',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            // Table Rows
            Expanded(
              child: ListView.builder(
                itemCount: filteredAppointments.length,
                itemBuilder: (context, index) {
                  final appointment = filteredAppointments[index];
                  final patient = _patientController.getPatientById(
                    appointment.patientId,
                  );
                  final patientName = patient?.name ?? appointment.patientName;
                  final patientPhone = patient?.phoneNumber ?? '';

                  // تنسيق التاريخ
                  final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
                  final formattedDate = dateFormat.format(appointment.date);

                  // تنسيق الوقت
                  final timeParts = appointment.time.split(':');
                  final hour = int.tryParse(timeParts[0]) ?? 0;
                  final minute = timeParts.length > 1 ? timeParts[1] : '00';
                  final isPM = hour >= 12;
                  final displayHour = hour > 12
                      ? hour - 12
                      : (hour == 0 ? 12 : hour);
                  final timeText = '$displayHour:$minute ${isPM ? 'م' : 'ص'}';

                  final appointmentText = '$formattedDate $timeText';

                  final isLate =
                      filter == 'المتأخرون' ||
                      (appointment.date.isBefore(DateTime.now()) &&
                          (appointment.status == 'scheduled' ||
                              appointment.status == 'pending'));

                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // اسم المريض (على اليمين)
                        Expanded(
                          flex: 3,
                          child: Text(
                            patientName,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // الموعد
                        Expanded(
                          flex: 2,
                          child: Text(
                            appointmentText,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: isLate
                                  ? Colors.red
                                  : AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // رقم الهاتف
                        Expanded(
                          flex: 2,
                          child: Text(
                            patientPhone,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // زر العرض
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                if (patient != null) {
                                  _patientController.selectPatient(patient);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'عرض',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPatientsListSidebar() {
    return Container(
      width: 450.w,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(25.w),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Text(
                  'جميع المرضى',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Patients List
          Expanded(
            child: Obx(() {
              if (_patientController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final patients = _patientController.patients;
              final query = _searchController.text.toLowerCase();
              final filteredPatients = patients.where((p) {
                return p.name.toLowerCase().contains(query) ||
                    p.phoneNumber.contains(query);
              }).toList();

              if (filteredPatients.isEmpty) {
                return Center(
                  child: Text(
                    'لا يوجد مرضى',
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(20.w),
                itemCount: filteredPatients.length,
                itemBuilder: (context, index) {
                  final patient = filteredPatients[index];
                  return _buildPatientCard(patient: patient);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard({required PatientModel patient}) {
    return Obx(() {
      final isSelected =
          _patientController.selectedPatient.value?.id == patient.id;
      return GestureDetector(
        onTap: () {
          _patientController.selectPatient(patient);
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.only(
            left: 20.w,
            right: 0.w,
            top: 2.h,
            bottom: 2.h,
          ),
          constraints: BoxConstraints(minHeight: 72.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Patient Info (on the left)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Patient Name
                      RichText(
                        textAlign: TextAlign.right,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(
                              text: 'الاسم : ',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF505558),
                              ),
                            ),
                            TextSpan(
                              text: patient.name,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 2.h),
                      // Age
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'العمر : ${patient.age} سنة',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF505558),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      // Treatment Type
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'نوع العلاج : ${patient.treatmentHistory != null && patient.treatmentHistory!.isNotEmpty ? patient.treatmentHistory!.last : 'لا يوجد'}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF505558),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              // Patient Image (on the right)
              Transform.translate(
                offset: Offset(-8.w, 0),
                child: Container(
                  width: 55.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: Builder(
                      builder: (context) {
                        final imageUrl = patient.imageUrl;
                        final validImageUrl = ImageUtils.convertToValidUrl(
                          imageUrl,
                        );

                        if (validImageUrl != null &&
                            ImageUtils.isValidImageUrl(validImageUrl)) {
                          return CachedNetworkImage(
                            imageUrl: validImageUrl,
                            fit: BoxFit.cover,
                            width: 55.w,
                            height: 60.h,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (context, url) => Container(
                              width: 55.w,
                              height: 60.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                color: AppColors.white,
                                size: 30.sp,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 55.w,
                              height: 60.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                color: AppColors.white,
                                size: 30.sp,
                              ),
                            ),
                          );
                        }

                        return Container(
                          width: 55.w,
                          height: 60.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.r),
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppColors.white,
                            size: 30.sp,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPatientFile(PatientModel patient) {
    return Container(
      color: const Color(0xFFF4FEFF),
      child: Column(
        children: [
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return [
                  // Patient Information Card
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.all(16.w),
                      padding: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Patient Image
                          Container(
                            width: 110.w,
                            height: 156.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: patient.imageUrl != null
                                  ? Image.network(
                                      patient.imageUrl!,
                                      width: 110.w,
                                      height: 156.h,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: AppColors.primaryLight,
                                              child: Center(
                                                child: Text(
                                                  patient.name.isNotEmpty
                                                      ? patient.name[0]
                                                      : '?',
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 40.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                    )
                                  : Container(
                                      color: AppColors.primaryLight,
                                      child: Center(
                                        child: Text(
                                          patient.name.isNotEmpty
                                              ? patient.name[0]
                                              : '?',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 40.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          // Patient Details and QR Code
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: 0.w,
                                top: 6.h,
                                bottom: 6.h,
                              ),
                              child: Column(
                                children: [
                                  // Name at the top
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'الاسم : ${patient.name}',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF649FCC),
                                      ),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  // Row with details and QR code
                                  Row(
                                    children: [
                                      // Patient Details column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                'العمر : ${patient.age} سنة',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF505558,
                                                  ),
                                                ),
                                                textAlign: TextAlign.right,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                'الجنس: ${patient.gender == 'male'
                                                    ? 'ذكر'
                                                    : patient.gender == 'female'
                                                    ? 'أنثى'
                                                    : patient.gender}',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF505558,
                                                  ),
                                                ),
                                                textAlign: TextAlign.right,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                'رقم الهاتف : ${patient.phoneNumber}',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF505558,
                                                  ),
                                                ),
                                                textAlign: TextAlign.right,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                'المدينة : ${patient.city}',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF505558,
                                                  ),
                                                ),
                                                textAlign: TextAlign.right,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                'نوع العلاج : ${patient.treatmentHistory != null && patient.treatmentHistory!.isNotEmpty ? patient.treatmentHistory!.last : 'لا يوجد'}',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF505558,
                                                  ),
                                                ),
                                                textAlign: TextAlign.right,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      // QR Code column
                                      Column(
                                        children: [
                                          // QR Code (clickable)
                                          GestureDetector(
                                            onTap: () {
                                              _showQrCodeDialog(
                                                context,
                                                patient.id,
                                              );
                                            },
                                            child: Container(
                                              width: 70.w,
                                              height: 70.w,
                                              padding: EdgeInsets.all(8.w),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8.r),
                                              ),
                                              child: QrImageView(
                                                data: patient.id,
                                                version: QrVersions.auto,
                                                size: 54.w,
                                                backgroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 8.h),
                                          // Edit treatment type button
                                          GestureDetector(
                                            onTap: () {
                                              _showTreatmentTypeDialog(
                                                context,
                                                patient,
                                              );
                                            },
                                            child: Container(
                                              width: 40.w,
                                              height: 40.w,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryLight,
                                                borderRadius:
                                                    BorderRadius.circular(8.r),
                                              ),
                                              child: Icon(
                                                Icons.edit,
                                                color: AppColors.primary,
                                                size: 20.sp,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sticky TabBar
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    sliver: SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        height: 48.h,
                        child: Container(
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: const Color(0xB3649FCC), // 70% of #649FCC
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFF505558),
                            labelStyle: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            tabs: const [
                              Tab(text: 'السجلات'),
                              Tab(text: 'المواعيد'),
                              Tab(text: 'المعرض'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: Column(
                children: [
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRecordsTab(patient),
                        _buildAppointmentsTab(patient),
                        _buildGalleryTab(patient),
                      ],
                    ),
                  ),

                  // Add Record Button (Dynamic based on tab)
                  Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Obx(() {
                      final selectedPatient =
                          _patientController.selectedPatient.value;
                      if (selectedPatient == null) {
                        return const SizedBox.shrink();
                      }

                      final tabIndex = _currentTabIndex.value;
                      return Container(
                        width: double.infinity,
                        height: 56.h,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            _onButtonPressed(tabIndex, selectedPatient.id);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: Text(
                            _getButtonText(tabIndex),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTab(PatientModel patient) {
    return Obx(() {
      if (_medicalRecordController.isLoading.value) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      final records = _medicalRecordController.records
          .where((record) => record.patientId == patient.id)
          .toList();

      if (records.isEmpty) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.divider,
                  ),
                  child: Icon(
                    Icons.block,
                    size: 50.sp,
                    color: AppColors.textHint,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا يوجد سجلات',
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        color: const Color(0xFFF4FEFF),
        child: ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return GestureDetector(
              onTap: () {
                _showRecordDetailsDialog(context, record);
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFF649FCC), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (record.notes != null && record.notes!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Text(
                          record.notes!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    if (record.images != null && record.images!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: record.images!.map((imageUrl) {
                            return Container(
                              width: 60.w,
                              height: 70.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppColors.divider,
                                      child: Icon(
                                        Icons.broken_image,
                                        color: AppColors.textHint,
                                        size: 30.sp,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          DateFormat('dd/MM/yyyy', 'ar').format(record.date),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF505558),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildAppointmentsTab(PatientModel patient) {
    // التحقق من نوع العلاج
    final isImplantTreatment =
        patient.treatmentHistory != null &&
        patient.treatmentHistory!.isNotEmpty &&
        patient.treatmentHistory!.last == 'زراعة';

    // إذا كان نوع العلاج زراعة، نعرض المراحل
    if (isImplantTreatment) {
      return _buildImplantStagesView(patient);
    }

    return Obx(() {
      if (_appointmentController.isLoading.value) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      final appointments = _appointmentController.appointments
          .where((apt) => apt.patientId == patient.id)
          .toList();

      if (appointments.isEmpty) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.divider,
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 50.sp,
                    color: AppColors.textHint,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا يوجد مواعيد',
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        color: const Color(0xFFF4FEFF),
        child: ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            return Container(
              margin: EdgeInsets.only(bottom: 16.h),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy', 'ar').format(appointment.date),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: appointment.status == 'completed'
                              ? Colors.green
                              : appointment.status == 'cancelled'
                              ? Colors.red
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          appointment.status == 'completed'
                              ? 'مكتمل'
                              : appointment.status == 'cancelled'
                              ? 'ملغي'
                              : 'مجدول',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'الوقت: ${appointment.time}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (appointment.notes != null &&
                      appointment.notes!.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Text(
                      appointment.notes!,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildImplantStagesView(PatientModel patient) {
    // الحصول على ImplantStageController (إنشاءه إذا لم يكن موجوداً)
    final implantStageController = Get.put(ImplantStageController());

    // تحميل المراحل إذا لم تكن محملة بعد
    if (!implantStageController.isLoading.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        implantStageController.ensureStagesLoaded(patient.id);
      });
    }

    return Obx(() {
      if (implantStageController.isLoading.value) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      // Only consider stages for this patient (controller may hold stages for multiple patients)
      final patientStages = implantStageController.stagesForPatient(patient.id);

      if (patientStages.isEmpty) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.divider,
                  ),
                  child: Icon(
                    Icons.medical_services,
                    size: 50.sp,
                    color: AppColors.textHint,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا توجد مراحل زراعة',
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textHint),
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await implantStageController.initializeStages(patient.id);
                      // After initialization, ensure we have fresh data
                      await implantStageController.loadStages(patient.id);
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: const Text('تهيئة مراحل الزراعة'),
                ),
              ],
            ),
          ),
        );
      }

      // تنسيق التاريخ والوقت
      String getDayName(DateTime date) {
        final days = [
          'الأحد',
          'الاثنين',
          'الثلاثاء',
          'الأربعاء',
          'الخميس',
          'الجمعة',
          'السبت',
        ];
        return days[date.weekday % 7];
      }

      String formatTime(DateTime date) {
        final hour = date.hour;
        final minute = date.minute;
        final isPM = hour >= 12;
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final period = isPM ? 'مساءاً' : 'صباحاً';
        return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
      }

      // قائمة جميع المراحل المحتملة
      final allStages = [
        "مرحلة زراعة الاسنان",
        "مرحلة رفع خيط العملية",
        "متابعة حالة المريض",
        "المتابعة الثانية لحالة المريض",
        "التقاط طبعة الاسنان",
        "التركيب التجريبي الاول",
        "التركيب التجريبي الثاني",
        "التركيب النهائي الاخير",
      ];

      // إيجاد آخر مرحلة مكتملة
      int? lastCompletedIndex;
      for (int i = patientStages.length - 1; i >= 0; i--) {
        if (patientStages[i].isCompleted) {
          // البحث عن فهرس المرحلة في القائمة الكاملة
          final stageName = patientStages[i].stageName;
          final indexInAll = allStages.indexOf(stageName);
          if (indexInAll != -1) {
            lastCompletedIndex = indexInAll;
            break;
          }
        }
      }

      return Container(
        color: const Color(0xFFF4FEFF),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          itemCount: allStages.length,
          itemBuilder: (context, index) {
            final stageName = allStages[index];
            // البحث عن المرحلة في المراحل المحملة
            final existingStage = patientStages.firstWhere(
              (s) => s.stageName == stageName,
              orElse: () => ImplantStageModel(
                id: '',
                patientId: patient.id,
                stageName: stageName,
                scheduledAt: DateTime.now(),
                isCompleted: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            final isLast = index == allStages.length - 1;

            // تحديد إذا كانت المرحلة التالية مكتملة
            bool hasNextCompleted = false;
            if (index < allStages.length - 1) {
              final nextStageName = allStages[index + 1];
              final nextStage = patientStages.firstWhere(
                (s) => s.stageName == nextStageName,
                orElse: () => ImplantStageModel(
                  id: '',
                  patientId: patient.id,
                  stageName: nextStageName,
                  scheduledAt: DateTime.now(),
                  isCompleted: false,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              hasNextCompleted = nextStage.isCompleted;
            }

            // تحديد إذا كانت هذه المرحلة هي التالية للمرحلة المكتملة الأخيرة
            bool isNextToLastCompleted = false;
            if (lastCompletedIndex != null) {
              isNextToLastCompleted = index == lastCompletedIndex + 1;
            }

            // المرحلة الأولى (مرحلة زراعة الاسنان) تظهر معلومات الموعد دائماً إذا كانت موجودة
            final isFirstStage = index == 0;
            // التحقق من أن المرحلة موجودة (تم إنشاؤها) - id غير فارغ
            final stageExists = existingStage.id.isNotEmpty;

            return _buildImplantStageItem(
              stage: existingStage,
              isLast: isLast,
              hasNextCompleted: hasNextCompleted,
              getDayName: getDayName,
              formatTime: formatTime,
              showAppointmentInfo:
                  existingStage.isCompleted ||
                  isNextToLastCompleted ||
                  (isFirstStage && stageExists),
              patientId: patient.id,
            );
          },
        ),
      );
    });
  }

  Widget _buildImplantStageItem({
    required ImplantStageModel stage,
    required bool isLast,
    required bool hasNextCompleted,
    required String Function(DateTime) getDayName,
    required String Function(DateTime) formatTime,
    required bool showAppointmentInfo,
    required String patientId,
  }) {
    final dateFormat = DateFormat('d/M/yyyy');
    final implantStageController = Get.put(ImplantStageController());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content - قابل للضغط للطبيب فقط لتعديل التاريخ (على اليمين)
        Expanded(
          child: GestureDetector(
            onTap: () {
              _showEditImplantStageDateDialog(
                context,
                patientId,
                stage.stageName,
                stage.scheduledAt,
              );
            },
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h, top: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stage.stageName,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: stage.isCompleted
                          ? AppColors.primary.withOpacity(0.7)
                          : AppColors.textPrimary,
                      decoration: stage.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: stage.isCompleted
                          ? AppColors.primary.withOpacity(0.7)
                          : null,
                      decorationThickness: 2,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  // إظهار معلومات الموعد فقط للمراحل المكتملة والموعد التالي
                  if (showAppointmentInfo) ...[
                    SizedBox(height: 8.h),
                    Text(
                      'موعدك سيكون في',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'تاريخ ${dateFormat.format(stage.scheduledAt)} يوم ${getDayName(stage.scheduledAt)} الساعة ${formatTime(stage.scheduledAt)}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        // Timeline Line and Circle (على اليسار)
        Column(
          children: [
            // Circle - قابل للضغط للطبيب فقط لإكمال/إلغاء إكمال المرحلة
            GestureDetector(
              onTap: () async {
                bool success;
                String message;
                if (stage.isCompleted) {
                  // إلغاء الإكمال
                  success = await implantStageController.uncompleteStage(
                    patientId,
                    stage.stageName,
                  );
                  message = success
                      ? 'تم إلغاء إكمال المرحلة بنجاح'
                      : 'فشل إلغاء إكمال المرحلة';
                } else {
                  // إكمال المرحلة
                  success = await implantStageController.completeStage(
                    patientId,
                    stage.stageName,
                  );
                  message = success
                      ? 'تم إكمال المرحلة بنجاح'
                      : 'فشل إكمال المرحلة';
                }

                if (success) {
                  Get.snackbar(
                    'نجح',
                    message,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.primary,
                    colorText: AppColors.white,
                  );
                } else {
                  final errorMsg =
                      implantStageController.errorMessage.value.isNotEmpty
                      ? implantStageController.errorMessage.value
                      : message;
                  Get.snackbar(
                    'خطأ',
                    errorMsg,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red,
                    colorText: AppColors.white,
                    duration: const Duration(seconds: 4),
                  );
                }
              },
              child: Container(
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stage.isCompleted
                      ? AppColors.primary
                      : AppColors.white,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: stage.isCompleted
                    ? Icon(Icons.check, color: AppColors.white, size: 20.sp)
                    : null,
              ),
            ),
            // Line
            if (!isLast)
              Container(
                width: 2,
                height: 50.h,
                color: stage.isCompleted || hasNextCompleted
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.3),
              ),
          ],
        ),
      ],
    );
  }

  void _showEditImplantStageDateDialog(
    BuildContext context,
    String patientId,
    String stageName,
    DateTime currentDate,
  ) {
    DateTime? selectedDate = currentDate;
    String? selectedTime;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.5,
                ),
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تعديل تاريخ المرحلة',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      // Date picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: AppColors.divider.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDate != null
                                    ? DateFormat(
                                        'dd/MM/yyyy',
                                        'ar',
                                      ).format(selectedDate!)
                                    : 'اختر التاريخ',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Time picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              selectedDate ?? DateTime.now(),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedTime =
                                  '${picked.hour}:${picked.minute.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: AppColors.divider.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedTime ?? 'اختر الوقت',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Icon(Icons.access_time, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  side: BorderSide(color: AppColors.divider),
                                ),
                              ),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (selectedDate == null ||
                                    selectedTime == null) {
                                  Get.snackbar(
                                    'تنبيه',
                                    'يرجى اختيار التاريخ والوقت',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.orange,
                                    colorText: AppColors.white,
                                  );
                                  return;
                                }

                                final implantStageController = Get.put(
                                  ImplantStageController(),
                                );
                                final success = await implantStageController
                                    .updateStageDate(
                                      patientId,
                                      stageName,
                                      selectedDate!,
                                      selectedTime!,
                                    );

                                if (success) {
                                  Navigator.of(context).pop();
                                  Get.snackbar(
                                    'نجح',
                                    'تم تحديث تاريخ المرحلة بنجاح',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: AppColors.primary,
                                    colorText: AppColors.white,
                                  );
                                } else {
                                  Get.snackbar(
                                    'خطأ',
                                    implantStageController
                                            .errorMessage
                                            .value
                                            .isNotEmpty
                                        ? implantStageController
                                              .errorMessage
                                              .value
                                        : 'فشل تحديث تاريخ المرحلة',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red,
                                    colorText: AppColors.white,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                'حفظ',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGalleryTab(PatientModel patient) {
    return Obx(() {
      if (_galleryController.isLoading.value) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      if (_galleryController.galleryImages.isEmpty) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.divider,
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    size: 50.sp,
                    color: AppColors.textHint,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا توجد صور',
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        color: const Color(0xFFF4FEFF),
        padding: EdgeInsets.all(16.w),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // Increased from 3 to 5 for smaller images
            crossAxisSpacing: 8.w,
            mainAxisSpacing: 8.h,
            childAspectRatio: 1.0,
          ),
          itemCount: _galleryController.galleryImages.length,
          itemBuilder: (context, index) {
            final image = _galleryController.galleryImages[index];
            final imageUrl = ImageUtils.convertToValidUrl(image.imagePath);
            return GestureDetector(
              onTap: () {
                _showGalleryImageDialog(context, image);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: imageUrl != null && ImageUtils.isValidImageUrl(imageUrl)
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        progressIndicatorBuilder: (context, url, progress) =>
                            Container(
                              color: AppColors.divider,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.progress,
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
                            Icons.broken_image,
                            color: AppColors.textHint,
                            size: 30.sp,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.divider,
                        child: Icon(
                          Icons.broken_image,
                          color: AppColors.textHint,
                          size: 30.sp,
                        ),
                      ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildActionIcon(IconData icon, {bool hasNotification = false}) {
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Icon(icon, color: Colors.grey[600], size: 24.sp),
        ),
        if (hasNotification)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 12.w,
              height: 12.w,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRightSidebarNavigation() {
    return Container(
      width: 120.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1E3A5F), // Dark blue
            const Color(0xFF2C5282), // Medium blue
          ],
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 40.h),
          // Logo Section
          Column(
            children: [
              // Logo Circle with Tooth Logo Image
              Container(
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 80.w,
                    height: 80.h,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // White Tooth
                          Icon(
                            Icons.medical_services,
                            color: Colors.white,
                            size: 40.sp,
                          ),
                          // Stars around
                          Positioned(
                            top: 10.h,
                            left: 10.w,
                            child: Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 12.sp,
                            ),
                          ),
                          Positioned(
                            top: 10.h,
                            right: 10.w,
                            child: Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 12.sp,
                            ),
                          ),
                          Positioned(
                            bottom: 15.h,
                            left: 15.w,
                            child: Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 10.sp,
                            ),
                          ),
                          Positioned(
                            bottom: 15.h,
                            right: 15.w,
                            child: Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 10.sp,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 15.h),
              // FARAH Text
              Text(
                'FARAH',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 5.h),
              Text(
                'Dental Clinic',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          SizedBox(height: 40.h),

          // Vertical Text
          Expanded(
            child: RotatedBox(
              quarterTurns: 1,
              child: Center(
                child: Text(
                  'مركز فرح التخصصي لطب الاسنان',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 40.h),

          // Bottom Icons
          Column(
            children: [
              // Tooth Logo at bottom
              Image.asset(
                'assets/images/tooth_logo.png',
                width: 40.w,
                height: 40.h,
                color: Colors.white,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.medical_services_outlined,
                    color: Colors.white,
                    size: 30.sp,
                  );
                },
              ),
              SizedBox(height: 20.h),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20.sp,
                ),
                onPressed: () {
                  _authController.logout();
                },
              ),
            ],
          ),

          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  String _getButtonText(int tabIndex) {
    switch (tabIndex) {
      case 0: // السجلات (Records)
        return 'اضافة سجل';
      case 1: // المواعيد (Appointments)
        return 'حجز موعد';
      case 2: // المعرض (Gallery)
        return 'اضافة صورة';
      default:
        return 'اضافة سجل';
    }
  }

  void _onButtonPressed(int tabIndex, String patientId) {
    switch (tabIndex) {
      case 0: // السجلات (Records)
        _showAddRecordDialog(context, patientId);
        break;
      case 1: // المواعيد (Appointments)
        _showBookAppointmentDialog(context, patientId);
        break;
      case 2: // المعرض (Gallery)
        _showAddImageDialog(context, patientId);
        break;
    }
  }

  void _showAddRecordDialog(BuildContext context, String patientId) {
    List<File> selectedImages = [];
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.5,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'اضافة سجل',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      // Notes field
                      TextFormField(
                        controller: noteController,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: 'أدخل الملاحظات أو التشخيص...',
                          hintStyle: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 14.sp,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: EdgeInsets.all(16.w),
                        ),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 16.h),
                      // Add images button
                      GestureDetector(
                        onTap: () async {
                          try {
                            if (Platform.isWindows ||
                                Platform.isLinux ||
                                Platform.isMacOS) {
                              // Use file_picker for desktop platforms
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.image,
                                    allowMultiple: true,
                                  );

                              if (result != null && result.files.isNotEmpty) {
                                setDialogState(() {
                                  selectedImages.addAll(
                                    result.files
                                        .where((file) => file.path != null)
                                        .map((file) => File(file.path!))
                                        .toList(),
                                  );
                                });
                              }
                            } else {
                              // Use image_picker for mobile platforms
                              final List<XFile> images = await _imagePicker
                                  .pickMultiImage(imageQuality: 85);
                              if (images.isNotEmpty) {
                                setDialogState(() {
                                  selectedImages.addAll(
                                    images.map((img) => File(img.path)),
                                  );
                                });
                              }
                            }
                          } catch (e) {
                            print(
                              '❌ [DoctorHomeScreen] Error picking images: $e',
                            );
                            if (context.mounted) {
                              Get.snackbar(
                                'خطأ',
                                'فشل اختيار الصور: ${e.toString()}',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                              );
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                color: AppColors.primary,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'إضافة صور (اختياري)',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Selected images preview
                      if (selectedImages.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Container(
                          height: 100.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedImages.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: EdgeInsets.only(left: 8.w),
                                width: 100.w,
                                height: 100.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: AppColors.divider,
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.r),
                                      child: Image.file(
                                        selectedImages[index],
                                        fit: BoxFit.cover,
                                        width: 100.w,
                                        height: 100.h,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4.h,
                                      left: 4.w,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            selectedImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4.w),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      SizedBox(height: 24.h),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  side: BorderSide(color: AppColors.divider),
                                ),
                              ),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // حفظ القيم قبل إغلاق الـ dialog
                                final noteText = noteController.text.trim();
                                final imagesToSend = selectedImages.isEmpty
                                    ? null
                                    : List<File>.from(selectedImages);

                                // إغلاق الـ dialog أولاً
                                Navigator.of(context).pop();

                                // انتظار قليلاً للتأكد من إغلاق الـ dialog
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );

                                try {
                                  await _medicalRecordController.addRecord(
                                    patientId: patientId,
                                    note: noteText.isEmpty ? null : noteText,
                                    imageFiles: imagesToSend,
                                  );
                                  // Reload records after adding
                                  await _medicalRecordController
                                      .loadPatientRecords(patientId);
                                } catch (e) {
                                  // Error already shown in controller
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                'حفظ',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          noteController.dispose();
        } catch (e) {
          // Controller already disposed
        }
      });
    });
  }

  void _showAddImageDialog(BuildContext context, String patientId) {
    File? selectedImage;
    final TextEditingController noteController = TextEditingController();
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.5,
                ),
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'اضافة صورة',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      // Image picker button
                      GestureDetector(
                        onTap: () async {
                          if (isUploading) return;

                          try {
                            if (Platform.isWindows ||
                                Platform.isLinux ||
                                Platform.isMacOS) {
                              // Use file_picker for desktop platforms
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.image,
                                    allowMultiple: false,
                                  );

                              if (result != null &&
                                  result.files.isNotEmpty &&
                                  result.files.first.path != null) {
                                setDialogState(() {
                                  selectedImage = File(
                                    result.files.first.path!,
                                  );
                                });
                              }
                            } else {
                              // Use image_picker for mobile platforms
                              final XFile? image = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                              );

                              if (image != null) {
                                setDialogState(() {
                                  selectedImage = File(image.path);
                                });
                              }
                            }
                          } catch (e) {
                            print(
                              '❌ [DoctorHomeScreen] Error picking image: $e',
                            );
                            if (context.mounted) {
                              Get.snackbar(
                                'خطأ',
                                'فشل اختيار الصورة: ${e.toString()}',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                              );
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 200.h,
                          decoration: BoxDecoration(
                            color: AppColors.divider.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.divider,
                              width: 1.5,
                            ),
                          ),
                          child: selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 48.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'اختر صورة',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Image.file(
                                    selectedImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 200.h,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Note text field
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'الشرح (اختياري)',
                          labelStyle: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                        maxLines: 3,
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      SizedBox(height: 32.h),
                      // Buttons
                      Row(
                        children: [
                          // Back button (left)
                          Expanded(
                            child: GestureDetector(
                              onTap: isUploading
                                  ? null
                                  : () {
                                      Navigator.of(dialogContext).pop();
                                    },
                              child: Container(
                                height: 48.h,
                                decoration: BoxDecoration(
                                  color: AppColors.divider,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: Text(
                                    'عودة',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          // Add button (right)
                          Expanded(
                            child: GestureDetector(
                              onTap: isUploading || selectedImage == null
                                  ? null
                                  : () async {
                                      setDialogState(() {
                                        isUploading = true;
                                      });

                                      final success = await _galleryController
                                          .uploadImage(
                                            patientId,
                                            selectedImage!,
                                            noteController.text.trim().isEmpty
                                                ? null
                                                : noteController.text.trim(),
                                          );

                                      if (dialogContext.mounted) {
                                        if (success) {
                                          Navigator.of(dialogContext).pop();
                                          Get.snackbar(
                                            'نجح',
                                            'تم رفع الصورة بنجاح',
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: AppColors.primary,
                                            colorText: Colors.white,
                                          );
                                          // Reload gallery
                                          await _galleryController.loadGallery(
                                            patientId,
                                          );
                                        } else {
                                          Get.snackbar(
                                            'خطأ',
                                            _galleryController
                                                .errorMessage
                                                .value,
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.red,
                                            colorText: Colors.white,
                                          );
                                          setDialogState(() {
                                            isUploading = false;
                                          });
                                        }
                                      }
                                    },
                              child: Container(
                                height: 48.h,
                                decoration: BoxDecoration(
                                  color: (isUploading || selectedImage == null)
                                      ? AppColors.divider
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: isUploading
                                      ? SizedBox(
                                          width: 20.w,
                                          height: 20.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          'اضافة',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
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
              ),
            );
          },
        );
      },
    );
  }

  void _showBookAppointmentDialog(BuildContext context, String patientId) {
    int currentStep = 1;
    DateTime? selectedDate;
    String? selectedTime;
    List<File> selectedImages = [];
    final TextEditingController notesController = TextEditingController();

    // Get patient and doctor ID
    final patient = _patientController.getPatientById(patientId);
    final doctorIds = patient?.doctorIds ?? [];
    final doctorId = doctorIds.isNotEmpty ? doctorIds.first : null;

    // Working hours controller
    final workingHoursController = Get.put(WorkingHoursController());

    // Available slots (will be loaded from API)
    List<String> availableSlots = [];
    bool isLoadingSlots = false;

    // Load working hours when dialog opens
    if (doctorId != null) {
      workingHoursController.loadWorkingHours();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  maxWidth: MediaQuery.of(context).size.width * 0.5,
                ),
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: currentStep == 1
                    ? _buildStep1DateTimeSelection(
                        context,
                        selectedDate,
                        selectedTime,
                        availableSlots,
                        isLoadingSlots,
                        workingHoursController,
                        doctorId,
                        (date) async {
                          setDialogState(() {
                            selectedDate = date;
                            selectedTime = null; // Reset time when date changes
                            isLoadingSlots = true;
                          });

                          // Load available slots for selected date
                          if (doctorId != null) {
                            try {
                              final dateStr =
                                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                              final slots = await _workingHoursService
                                  .getAvailableSlots(doctorId, dateStr);
                              setDialogState(() {
                                availableSlots = slots;
                                isLoadingSlots = false;
                              });
                            } catch (e) {
                              print(
                                '❌ [DoctorHomeScreen] Error loading available slots: $e',
                              );
                              setDialogState(() {
                                availableSlots = [];
                                isLoadingSlots = false;
                              });
                              Get.snackbar(
                                'خطأ',
                                'فشل جلب الأوقات المتاحة',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: AppColors.white,
                              );
                            }
                          } else {
                            setDialogState(() {
                              availableSlots = [];
                              isLoadingSlots = false;
                            });
                          }
                        },
                        (time) {
                          setDialogState(() {
                            selectedTime = time;
                          });
                        },
                        () {
                          if (selectedDate != null && selectedTime != null) {
                            setDialogState(() {
                              currentStep = 2;
                            });
                          } else {
                            Get.snackbar(
                              'تنبيه',
                              'يرجى اختيار التاريخ والوقت',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.orange,
                              colorText: AppColors.white,
                            );
                          }
                        },
                        () => Navigator.of(context).pop(),
                        setDialogState,
                      )
                    : _buildStep2NotesImages(
                        context,
                        notesController,
                        selectedImages,
                        (images) {
                          setDialogState(() {
                            selectedImages = images;
                          });
                        },
                        (index) {
                          setDialogState(() {
                            selectedImages.removeAt(index);
                          });
                        },
                        () {
                          setDialogState(() {
                            currentStep = 1;
                          });
                        },
                        () async {
                          if (selectedDate != null && selectedTime != null) {
                            // Parse time from 12-hour format (e.g., "2:30 م" or "9:00 ص")
                            final isPM = selectedTime!.contains(' م');
                            final timeStr = selectedTime!
                                .replaceAll(' م', '')
                                .replaceAll(' ص', '')
                                .trim();
                            final timeParts = timeStr.split(':');
                            var hour = int.parse(timeParts[0]);
                            final minute = timeParts.length > 1
                                ? int.parse(timeParts[1])
                                : 0;

                            // Convert to 24-hour format
                            if (isPM && hour != 12) {
                              hour += 12;
                            } else if (!isPM && hour == 12) {
                              hour = 0;
                            }

                            // Combine date and time
                            final appointmentDateTime = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              hour,
                              minute,
                            );

                            Navigator.of(context).pop();

                            try {
                              await _appointmentController.addAppointment(
                                patientId: patientId,
                                scheduledAt: appointmentDateTime,
                                note: notesController.text.isNotEmpty
                                    ? notesController.text
                                    : null,
                                imageFiles: selectedImages.isNotEmpty
                                    ? selectedImages
                                    : null,
                              );

                              // Reload appointments
                              _appointmentController
                                  .loadPatientAppointmentsById(patientId);
                            } catch (e) {
                              print(
                                '❌ [DoctorHomeScreen] Error adding appointment: $e',
                              );
                              // لا تعرض خطأ إذا كان الخطأ في parsing فقط (الموعد تمت إضافته)
                              final errorMsg = e.toString();
                              if (!errorMsg.contains('معالجة البيانات')) {
                                Get.snackbar(
                                  'خطأ',
                                  'فشل إضافة الموعد',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: Colors.red,
                                  colorText: AppColors.white,
                                );
                              }
                            }
                          }
                        },
                      ),
              ),
            );
          },
        );
      },
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          notesController.dispose();
        } catch (e) {
          // Controller already disposed
        }
      });
    });
  }

  /// Convert 24-hour time format to 12-hour format with ص/م
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

  Widget _buildStep1DateTimeSelection(
    BuildContext context,
    DateTime? selectedDate,
    String? selectedTime,
    List<String> availableSlots,
    bool isLoadingSlots,
    WorkingHoursController workingHoursController,
    String? doctorId,
    Function(DateTime) onDateSelected,
    Function(String) onTimeSelected,
    VoidCallback onNext,
    VoidCallback onBack,
    StateSetter setState,
  ) {
    // Day names in Arabic (0=Sunday, 6=Saturday)
    final weekDays = [
      'أحد',
      'اثنين',
      'ثلاثاء',
      'أربعاء',
      'خميس',
      'جمعة',
      'سبت',
    ];

    // Use selectedDate or today as reference
    final now = selectedDate ?? DateTime.now();

    return StatefulBuilder(
      builder: (context, setCalendarState) {
        // Calculate week start (Sunday = 0)
        final weekStart = now.subtract(Duration(days: now.weekday % 7));

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Title
              Text(
                'اختر تاريخ الموعد',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 24.h),

              // Week navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setCalendarState(() {
                            final newDate = (selectedDate ?? DateTime.now())
                                .subtract(const Duration(days: 7));
                            onDateSelected(newDate);
                          });
                        },
                        child: Icon(
                          Icons.chevron_left,
                          size: 24.r,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${(selectedDate ?? DateTime.now()).year} , ${(selectedDate ?? DateTime.now()).month}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () {
                          setCalendarState(() {
                            final newDate = (selectedDate ?? DateTime.now())
                                .add(const Duration(days: 7));
                            onDateSelected(newDate);
                          });
                        },
                        child: Icon(
                          Icons.chevron_right,
                          size: 24.r,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Week calendar (7 days in a row)
              Obx(() {
                return Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 16.h,
                    horizontal: 0.w,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final day = weekStart.add(Duration(days: index));
                      final isSelected =
                          selectedDate != null &&
                          day.day == selectedDate.day &&
                          day.month == selectedDate.month &&
                          day.year == selectedDate.year;
                      final isPast = day.isBefore(
                        DateTime.now().subtract(const Duration(days: 1)),
                      );

                      // Check if this day is a holiday (not working)
                      bool isHoliday = false;
                      if (workingHoursController.workingHours.isNotEmpty) {
                        final weekday = day.weekday % 7; // 0=Sunday, 6=Saturday
                        if (weekday <
                            workingHoursController.workingHours.length) {
                          final dayWorkingHours =
                              workingHoursController.workingHours[weekday];
                          isHoliday = dayWorkingHours['isWorking'] == false;
                        }
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: (isPast || isHoliday)
                              ? null
                              : () {
                                  onDateSelected(day);
                                  setCalendarState(() {});
                                },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 2.w),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF7FC8D6)
                                  : (isPast || isHoliday)
                                  ? Colors.grey[100]
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.r),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF7FC8D6),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  weekDays[day.weekday % 7],
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isPast || isHoliday)
                                        ? Colors.grey[400]
                                        : Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : (isPast || isHoliday)
                                        ? Colors.grey[400]
                                        : Colors.black87,
                                    decoration: isHoliday
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),

              SizedBox(height: 24.h),

              // Time selection title
              Text(
                'اختر وقت الموعد',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 16.h),

              // Time slots grid or loading/empty state
              SizedBox(
                height: 200.h, // Fixed height for scrollable area
                child: isLoadingSlots
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.h),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : availableSlots.isEmpty
                    ? Container(
                        padding: EdgeInsets.all(24.h),
                        child: Center(
                          child: Text(
                            selectedDate == null
                                ? 'يرجى اختيار تاريخ أولاً'
                                : 'لا توجد أوقات متاحة لهذا التاريخ',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8.w,
                          mainAxisSpacing: 8.h,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: availableSlots.length,
                        itemBuilder: (context, index) {
                          final time24 = availableSlots[index];
                          final time = _convertTo12Hour(time24);
                          final isSelected = selectedTime == time;

                          return GestureDetector(
                            onTap: () {
                              onTimeSelected(time);
                              setCalendarState(() {});
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.white,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              SizedBox(height: 24.h),

              // Hint box
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.yellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.orange,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'لطفا قم بادخال الوقت والتاريخ لتسجيل موعد المريض',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text(
                        'حجز',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onBack,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text(
                        'عودة',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep2NotesImages(
    BuildContext context,
    TextEditingController notesController,
    List<File> selectedImages,
    Function(List<File>) onImagesSelected,
    Function(int) onImageRemoved,
    VoidCallback onBack,
    VoidCallback onBook,
  ) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Add Notes section
          Text(
            'اضف ملاحضاتك (اختياري)',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 150.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: TextField(
              controller: notesController,
              maxLines: null,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'اكتب ملاحضاتك هنا',
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
              ),
              style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
            ),
          ),

          SizedBox(height: 24.h),

          // Add Images section
          Text(
            'اضف صور (اختياري)',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 16.h),

          GestureDetector(
            onTap: () async {
              try {
                if (Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS) {
                  // Use file_picker for desktop platforms
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    allowMultiple: true,
                  );

                  if (result != null && result.files.isNotEmpty) {
                    final List<File> newImages = result.files
                        .where((file) => file.path != null)
                        .map((file) => File(file.path!))
                        .toList();
                    onImagesSelected([...selectedImages, ...newImages]);
                  }
                } else {
                  // Use image_picker for mobile platforms
                  final List<XFile>? images = await _imagePicker.pickMultiImage(
                    imageQuality: 85,
                  );

                  if (images != null && images.isNotEmpty) {
                    final List<File> newImages = images
                        .map((xfile) => File(xfile.path))
                        .toList();
                    onImagesSelected([...selectedImages, ...newImages]);
                  }
                }
              } catch (e) {
                Get.snackbar(
                  'خطأ',
                  'فشل اختيار الصور',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: AppColors.white,
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.divider.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.image_outlined, color: AppColors.textSecondary),
                  SizedBox(width: 8.w),
                  Text(
                    'اضغط هنا لإضافة صور',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Images preview grid
          if (selectedImages.isNotEmpty) ...[
            SizedBox(height: 16.h),
            SizedBox(
              height: 150.h,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 8.w,
                  childAspectRatio: 1,
                ),
                itemCount: selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: EdgeInsets.only(left: 8.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.file(
                            selectedImages[index],
                            fit: BoxFit.cover,
                            width: 120.w,
                            height: 120.h,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4.h,
                        left: 4.w,
                        child: GestureDetector(
                          onTap: () {
                            onImageRemoved(index);
                          },
                          child: Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          SizedBox(height: 24.h),

          // Hint box
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.medical_services, color: Colors.red, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'يمكنك إدخال ملاحظاتك أو إضافة صور (كلاهما اختياري)',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Text(
                    'حجز',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'عودة',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.arrow_forward,
                        color: AppColors.primary,
                        size: 20.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRecordDetailsDialog(BuildContext context, dynamic record) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24.w),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تفاصيل السجل',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.divider.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16.sp,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        DateFormat('dd/MM/yyyy', 'ar').format(record.date),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Notes
                  if (record.notes != null && record.notes!.isNotEmpty) ...[
                    Text(
                      'الملاحظات:',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.divider.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        record.notes!,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  // Images
                  if (record.images != null && record.images!.isNotEmpty) ...[
                    Text(
                      'الصور:',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12.w,
                        mainAxisSpacing: 12.h,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: record.images!.length,
                      itemBuilder: (context, imgIndex) {
                        final imageUrl = ImageUtils.convertToValidUrl(
                          record.images![imgIndex],
                        );
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            if (imageUrl != null &&
                                ImageUtils.isValidImageUrl(imageUrl)) {
                              _showImageFullScreenDialog(context, imageUrl);
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child:
                                imageUrl != null &&
                                    ImageUtils.isValidImageUrl(imageUrl)
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    progressIndicatorBuilder:
                                        (context, url, progress) => Container(
                                          color: AppColors.divider,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: progress.progress,
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    AppColors.primary,
                                                  ),
                                            ),
                                          ),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: AppColors.divider,
                                          child: Icon(
                                            Icons.broken_image,
                                            color: AppColors.textHint,
                                            size: 30.sp,
                                          ),
                                        ),
                                  )
                                : Container(
                                    color: AppColors.divider,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: AppColors.textHint,
                                      size: 30.sp,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGalleryImageDialog(BuildContext context, dynamic galleryImage) {
    final imageUrl = ImageUtils.convertToValidUrl(galleryImage.imagePath);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24.w),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تفاصيل الصورة',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.divider.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Image
                  if (imageUrl != null && ImageUtils.isValidImageUrl(imageUrl))
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showImageFullScreenDialog(context, imageUrl);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          progressIndicatorBuilder: (context, url, progress) =>
                              Container(
                                height: 300.h,
                                color: AppColors.divider,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.progress,
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                          errorWidget: (context, url, error) => Container(
                            height: 300.h,
                            color: AppColors.divider,
                            child: Icon(
                              Icons.broken_image,
                              color: AppColors.textHint,
                              size: 50.sp,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 300.h,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.broken_image,
                        color: AppColors.textHint,
                        size: 50.sp,
                      ),
                    ),
                  SizedBox(height: 16.h),

                  // Date
                  if (galleryImage.createdAt != null &&
                      galleryImage.createdAt.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16.sp,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          galleryImage.createdAt,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                  // Note
                  if (galleryImage.note != null &&
                      galleryImage.note!.isNotEmpty) ...[
                    SizedBox(height: 16.h),
                    Text(
                      'الشرح:',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.divider.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        galleryImage.note!,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImageFullScreenDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black87,
            child: Stack(
              children: [
                // Full screen image with zoom
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      progressIndicatorBuilder: (context, url, progress) =>
                          Center(
                            child: CircularProgressIndicator(
                              value: progress.progress,
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                      errorWidget: (context, url, error) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 50.sp,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'فشل تحميل الصورة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 40.h,
                  right: 20.w,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQrCodeDialog(BuildContext context, String patientId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: AppColors.textPrimary,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // QR Code
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: QrImageView(
                    data: patientId,
                    version: QrVersions.auto,
                    size: 250.w,
                    backgroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTreatmentTypeDialog(BuildContext context, PatientModel patient) {
    // Treatment types (ordered). Shown in a 2-column grid to avoid empty gaps.
    final List<String> treatmentTypes = [
      'حشوات',
      'تبييض',
      'تنضيف',
      'قلع',
      'زراعة',
      'تقويم',
      'ابتسامة',
    ];

    // Get current selected treatments - نأخذ نوع العلاج الحالي فقط (آخر عنصر = الأحدث)
    Set<String> selectedTreatments = <String>{};

    // التحقق من نوع العلاج الحالي بشكل آمن
    List<String>? treatmentHistory = patient.treatmentHistory;

    if (treatmentHistory != null && treatmentHistory.isNotEmpty) {
      // نأخذ آخر عنصر (الأحدث) ونقسمه على "، " إذا كان يحتوي على عدة أنواع
      final currentTreatment = treatmentHistory.last;
      if (currentTreatment.isNotEmpty) {
        // تقسيم string على "، " للحصول على الأنواع الفردية
        final treatments = currentTreatment
            .split('، ')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        selectedTreatments = Set<String>.from(treatments);
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.5,
                ),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'قم بتحديد نوع علاج المريض',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),

                    // Treatment options (2-column grid, RTL)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: treatmentTypes.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8.w,
                        mainAxisSpacing: 6.h,
                        childAspectRatio: 4.5,
                      ),
                      itemBuilder: (context, index) {
                        final treatment = treatmentTypes[index];
                        final isSelected = selectedTreatments.contains(
                          treatment,
                        );
                        final isImplantSelected = selectedTreatments.contains(
                          'زراعة',
                        );
                        final isDisabled =
                            isImplantSelected && treatment != 'زراعة';

                        return _buildTreatmentOption(
                          treatment,
                          isSelected,
                          isDisabled,
                          () {
                            setDialogState(() {
                              if (treatment == 'زراعة') {
                                if (selectedTreatments.contains('زراعة')) {
                                  selectedTreatments.remove('زراعة');
                                } else {
                                  selectedTreatments.clear();
                                  selectedTreatments.add('زراعة');
                                }
                                return;
                              }

                              if (selectedTreatments.contains(treatment)) {
                                selectedTreatments.remove(treatment);
                              } else {
                                // If "زراعة" is selected, no other types allowed.
                                if (!selectedTreatments.contains('زراعة')) {
                                  selectedTreatments.add(treatment);
                                }
                              }
                            });
                          },
                        );
                      },
                    ),

                    // رسالة توضيحية عند اختيار "زراعة"
                    Builder(
                      builder: (context) {
                        final currentIsImplantSelected = selectedTreatments
                            .contains('زراعة');
                        if (currentIsImplantSelected) {
                          return Column(
                            children: [
                              SizedBox(height: 10.h),
                              Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.primary,
                                      size: 16.sp,
                                    ),
                                    SizedBox(width: 6.w),
                                    Expanded(
                                      child: Text(
                                        'نوع العلاج "زراعة" لا يمكن اختياره مع أنواع أخرى',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: AppColors.primary,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    SizedBox(height: 12.h),

                    // Buttons
                    Row(
                      children: [
                        // Back button (left)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              height: 40.h,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Center(
                                child: Text(
                                  'عودة',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        // Add button (right)
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              if (selectedTreatments.isEmpty) {
                                Get.snackbar(
                                  'تنبيه',
                                  'يرجى اختيار نوع العلاج على الأقل',
                                );
                                return;
                              }

                              // إذا كان "زراعة" مختارة، التأكد من أنها فقط
                              String treatmentType;
                              if (selectedTreatments.contains('زراعة')) {
                                treatmentType = 'زراعة';
                              } else {
                                // دمج جميع العلاجات المختارة في string واحد مفصول بفواصل
                                treatmentType = selectedTreatments.join('، ');
                              }

                              try {
                                await _patientController.setTreatmentType(
                                  patientId: patient.id,
                                  treatmentType: treatmentType,
                                );

                                // تحديث بيانات المريض في الصفحة
                                await _patientController.loadPatients();

                                // تحديث بيانات المريض الحالي في الـ controller
                                final updatedPatient = _patientController
                                    .getPatientById(patient.id);
                                if (updatedPatient != null) {
                                  _patientController.selectedPatient.value =
                                      updatedPatient;
                                }

                                Navigator.of(context).pop();
                                Get.snackbar(
                                  'نجح',
                                  'تم تحديث نوع العلاج بنجاح',
                                );
                              } catch (e) {
                                Get.snackbar(
                                  'خطأ',
                                  'حدث خطأ أثناء تحديث نوع العلاج',
                                );
                              }
                            },
                            child: Container(
                              height: 40.h,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Center(
                                child: Text(
                                  'اضافة',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
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

  Widget _buildTreatmentOption(
    String treatment,
    bool isSelected,
    bool isDisabled,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isDisabled
                ? AppColors.divider.withOpacity(0.3)
                : AppColors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Radio circle
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDisabled
                              ? AppColors.divider
                              : AppColors.textSecondary),
                    width: 1.2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 10.sp, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 6.w),
              // Treatment text
              Flexible(
                child: Text(
                  treatment,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDisabled
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
