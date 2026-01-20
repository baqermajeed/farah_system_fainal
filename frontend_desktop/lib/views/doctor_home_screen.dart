import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';
import 'package:frontend_desktop/core/widgets/custom_text_field.dart';
import 'package:frontend_desktop/core/widgets/gender_selector.dart';
import 'package:frontend_desktop/core/utils/operation_dialog.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/controllers/patient_controller.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/controllers/medical_record_controller.dart';
import 'package:frontend_desktop/controllers/gallery_controller.dart';
import 'package:frontend_desktop/controllers/appointment_controller.dart';
import 'package:frontend_desktop/controllers/working_hours_controller.dart';
import 'package:frontend_desktop/controllers/implant_stage_controller.dart';
import 'package:frontend_desktop/services/working_hours_service.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/auth_service.dart';
import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/models/appointment_model.dart';
import 'package:frontend_desktop/models/implant_stage_model.dart';
import 'package:frontend_desktop/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/models/doctor_model.dart';

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
  final PatientService _patientService = PatientService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController; // For patient file tabs
  late TabController _appointmentsTabController; // For appointments tabs
  final RxInt _currentTabIndex = 0.obs;
  final RxBool _showAppointments =
      false.obs; // Track if appointments should be shown
  final TextEditingController _qrScanController = TextEditingController();

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

        // Set default tab to Records (index 2) when a patient is selected
        _tabController.animateTo(2);
        _currentTabIndex.value = 2;

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
    _qrScanController.dispose();
    _tabController.dispose();
    _appointmentsTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFF),
      body: Stack(
        children: [
          // Decorative tooth image in top-left, outside TopBar so it isn't clipped
          Positioned(
            left: -36,
            top: -116,
            child: Image.asset(
              'assets/images/tooth-whitening.png',
              width: 220.w,
              height: 380.h,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200.w,
                  height: 200.h,
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
          ),
          Row(
            children: [
              // Main Content Area
              Expanded(
                child: Column(
                  children: [
                    // Top Bar (Header)
                    _buildTopBar(),

                    // Table with two columns
                    Padding(
                      padding:
                          EdgeInsets.only(top: 0, right: 16.w, left: 16.w),
                      child: _buildPatientsTable(),
                    ),
                  ],
                ),
              ),

              // Right Sidebar Navigation (FARAH Logo)
              _buildRightSidebarNavigation(),
            ],
          ),
        ],
      ),
    );
  }

  // --- Widgets Components ---

  /// معالجة كود الباركود القادم من جهاز قارئ خارجي (نفس منطق الموبايل)
  Future<void> _handleDesktopQrScan(String code) async {
    try {
      _qrScanController.clear();

      // جلب بيانات المريض والأطباء المرتبطين به
      final result =
          await _patientService.getPatientByQrCodeWithDoctors(code);

      if (result == null || result['patient'] == null) {
        Get.snackbar(
          'تنبيه',
          'المريض غير موجود',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.error,
          colorText: AppColors.white,
        );
        return;
      }

      final patient = result['patient'] as PatientModel;
      final doctors = (result['doctors'] as List<DoctorModel>? ?? []);

      // الطبيب في نسخة الديسكتوب دائماً "DoctorHomeScreen"
      final userId = _authController.currentUser.value?.id;

      // التحقق إن كان هذا المريض تابعاً للطبيب الحالي
      final isMyPatient = userId != null &&
          (doctors.any((d) => d.id == userId) ||
              patient.doctorIds.contains(userId));

      if (isMyPatient) {
        // فتح ملف المريض مباشرة (نفس مبدأ _navigateToPatientDetails)
        _patientController.selectPatient(patient);
        _showAppointments.value = false;
      } else {
        // إظهار رسالة بأن المريض محوّل لطبيب آخر (سلوك مبسط مشابه للموبايل)
        final assignedDoctor = doctors.isNotEmpty ? doctors.first : null;
        final doctorName = assignedDoctor?.name ?? 'طبيب آخر';

        Get.snackbar(
          'تنبيه',
          'هذا المريض مرتبط بالطبيب: $doctorName',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.primary,
          colorText: AppColors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء البحث عن المريض: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    }
  }

  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.only(left: 0, right: 40.w, top: 0, bottom: 10.h),
      child: Column(
        children: [
          // First Row: Center Title only
          Row(
            children: [
              SizedBox(width: 200.w), // Space for logo
              const Spacer(),

              // Center Title
              Transform.translate(
                offset: Offset(0, 10.h),
                child: Text(
                  'الصفحة الرئيسية',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),

          // Second Row: Profile, Doctor Name, Search Bar, Icons - starts from right, 10px from title, 20px from right edge
          Padding(
            padding: EdgeInsets.only(top: 4.h, right: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // QR Scan input (external barcode scanner) + Action Icons
                SizedBox(
                  width: 130.w,
                  child: TextField(
                    controller: _qrScanController,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ضع المؤشر هنا ثم امسح الباركود',
                      hintStyle: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textHint,
                      ),
                      prefixIcon: Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.primary,
                        size: 18.sp,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 6.h,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(
                          color: const Color(0xB3649FCC),
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(
                          color: const Color(0xB3649FCC),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _handleDesktopQrScan(value.trim());
                      }
                    },
                  ),
                ),
                SizedBox(width: 15.w),
                // Action Icons (ستظهر في أقصى اليسار في الترتيب العربي) - using images without container
                GestureDetector(
                  onTap: () {
                    // Show add patient dialog
                    _showAddPatientDialog(context);
                  },
                  child: Image.asset(
                    'assets/images/add.png',
                    width: 30.w,
                    height: 30.h,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.person_add_outlined,
                        color: Colors.grey[600],
                        size: 24.sp,
                      );
                    },
                  ),
                ),
                SizedBox(width: 15.w),
                GestureDetector(
                  onTap: () {
                    // Clear selected patient and show appointments table
                    _patientController.selectPatient(null);
                    // إعادة تحميل مواعيد جميع المرضى
                    _appointmentController.loadDoctorAppointments();
                    _showAppointments.value = true;
                  },
                  child: Image.asset(
                    'assets/images/date.png',
                    width: 36.w,
                    height: 36.h,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.grey[600],
                        size: 24.sp,
                      );
                    },
                  ),
                ),
                SizedBox(width: 30.w),
                // Search Bar
                Container(
                  width: 650.w,
                  height: 35.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: const Color(0xB3649FCC), // 70% opacity of 649FCC
                      width: 2,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مريض....',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14.sp,
                      ),
                      // Icon from the right (Arabic layout)
                      suffixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[400],
                        size: 20.sp,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    cursorColor: AppColors.primary,
                  ),
                ),
                SizedBox(width: 30.w),
                // Doctor Name
                Obx(() {
                  final user = _authController.currentUser.value;
                  final userName = user?.name ?? 'مهند المالكي';
                  return Text(
                    'د. $userName',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  );
                }),
                SizedBox(width: 12.w),
                // Profile Image (ستظهر في أقصى اليمين)
                Obx(() {
                  final user = _authController.currentUser.value;
                  final imageUrl = user?.imageUrl;
                  final validImageUrl = ImageUtils.convertToValidUrl(
                    imageUrl,
                  );

                  return GestureDetector(
                    onTap: () {
                      _showDoctorProfileDialog(context);
                    },
                    child: Container(
                      width: 70.w,
                      height: 70.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF649FCC),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
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
                                            user?.name ?? 'مهند المالكي';
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
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsTable() {
    return Container(
      width: 1230.w,
      height: 640.h,
      decoration: BoxDecoration(
        // Make background transparent so elements behind are visible,
        // while keeping only the stroke (border).
        color: Colors.transparent,
        border: Border.all(
          color: const Color(0xFF649FCC),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        children: [
          // Column 2: Patient File (on the left)
          Expanded(
            child: Column(
              children: [
                // Header Row (title changes based on current view)
                Obx(() {
                  final isAppointmentsView = _showAppointments.value;
                  return Container(
                    width: double.infinity,
                    height: 50.h,
                    decoration: BoxDecoration(
                      // No fill, only bottom stroke and corner radius
                      color: Colors.transparent,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                      ),
                      border: const Border(
                        bottom: BorderSide(
                          color: Color(0xFF649FCC),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isAppointmentsView ? 'ســـــجل المواعيـــــد' : 'ملـــــف الـــــمريض',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }),
                // Main Content: patient file or appointments table
                Expanded(
                  child: Obx(() {
                    if (_showAppointments.value) {
                      // Show appointments history/table in place of patient file
                      return ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20.r),
                        ),
                        child: _buildAppointmentsTable(),
                      );
                    }

                    final selectedPatient =
                        _patientController.selectedPatient.value;
                    if (selectedPatient != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20.r),
                        ),
                        child: _buildPatientFile(selectedPatient),
                      );
                    } else {
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4FEFF),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20.r),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'اختر مريضاً لعرض ملفه',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }
                  }),
                ),
              ],
            ),
          ),
          // Column 1: All Patients (on the right)
          Container(
            width: 450.w,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: const Color(0xFF649FCC),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Header Row
                Container(
                  width: double.infinity,
                  height: 50.h,
                  decoration: BoxDecoration(
                    // No fill, only bottom stroke and corner radius
                    color: Colors.transparent,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20.r),
                    ),
                    border: const Border(
                      bottom: BorderSide(
                        color: Color(0xFF649FCC),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'جميـــــع المرضـــــى',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                // Patients List
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(20.r),
                    ),
                    child: _buildPatientsListContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsListContent() {
    return Container(
      color: const Color(0xFFF4FEFF),
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
        
        // ترتيب المرضى من الأحدث إلى الأقدم حسب الـ id
        filteredPatients.sort((a, b) => b.id.compareTo(a.id));

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
    );
  }

  Widget _buildWelcomeState() {
    return Container(
      color: const Color(0xFFF4FEFF),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Tooth image with sparkles - starts from top
          Stack(
            alignment: Alignment.topCenter,
            children: [
              // Sparkle icons around the tooth
              Positioned(
                top: 20.h,
                left: 50.w,
                child: Icon(
                  Icons.star,
                  color: Colors.yellow[700],
                  size: 30.sp,
                ),
              ),
              Positioned(
                top: 70.h,
                right: 80.w,
                child: Icon(
                  Icons.star,
                  color: Colors.yellow[700],
                  size: 25.sp,
                ),
              ),
              Positioned(
                top: 420.h,
                left: 70.w,
                child: Icon(
                  Icons.star,
                  color: Colors.yellow[700],
                  size: 28.sp,
                ),
              ),
              // Main tooth image
              Padding(
                padding: EdgeInsets.only(top: 0),
                child: Image.asset(
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
              ),
            ],
          ),
        ],
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
         
          // Tabs
          Container(
            height: 37.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF4FEFF),
              borderRadius: BorderRadius.circular(10.r),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x29649FCC), // 16% opacity of #649FCC
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _appointmentsTabController,
              padding: EdgeInsets.zero,
              indicator: BoxDecoration(
                color: AppColors.primary.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10.r),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: const [
            BoxShadow(
              color: Color(0x29649FCC), // 16% من 649FCC
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ترتيب الأعمدة من اليسار لليمين مع نفس المسافات مثل الصفوف
                  SizedBox(
                    width: 100.w,
                    child: const SizedBox.shrink(), // عمود الزر بدون عنوان
                  ),
                  SizedBox(width: 60.w),
                  SizedBox(
                    width: 140.w,
                    child: Text(
                      'رقم الهاتف',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF76C6D1),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 60.w),
                  SizedBox(
                    width: 140.w,
                    child: Text(
                      'الموعد',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF76C6D1),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 60.w),
                  Expanded(
                    child: Text(
                      'اسم المريض',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF76C6D1),
                      ),
                      textAlign: TextAlign.right,
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
                      horizontal: 32.w,
                      vertical: 10.h,
                    ),
                    margin: EdgeInsets.symmetric(vertical: 4.h), // مسافة 8 بين الصفوف (4 أعلى + 4 أسفل)
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // العمود الرابع: زر عرض
                        SizedBox(
                          width: 100.w,
                          height: 30.h,
                          child: ElevatedButton(
                            onPressed: () {
                              if (patient != null) {
                                _patientController.selectPatient(patient);
                                _showAppointments.value = false;
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF76C6D1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'عرض',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 60.w),
                        // رقم الهاتف
                        SizedBox(
                          width: 140.w,
                          child: Text(
                            patientPhone,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0x99212F34),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 60.w),
                        // الموعد
                        SizedBox(
                          width: 140.w,
                          child: Text(
                            appointmentText,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: isLate
                                  ? Colors.red
                                  : const Color(0x99212F34),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 60.w),
                        // اسم المريض (على اليمين)
                        Expanded(
                          child: Text(
                            patientName,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF649FCC),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  'جميـــــع المرضـــــى',
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
              
              // ترتيب المرضى من الأحدث إلى الأقدم حسب الـ id
              filteredPatients.sort((a, b) => b.id.compareTo(a.id));

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
          _showAppointments.value = false;
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
                              style: GoogleFonts.cairo(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF505558),
                              ),
                            ),
                            TextSpan(
                              text: patient.name,
                              style: GoogleFonts.cairo(
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
                          // QR Code (on the left)
                          Row(
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
                                  width: 120.w,
                                  height: 120.w,
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: QrImageView(
                                    data: patient.id,
                                    version: QrVersions.auto,
                                    size: 104.w,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
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
                                    borderRadius: BorderRadius.circular(8.r),
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
                          Spacer(),
                          // Patient Details (Text only) - same height as image
                          Container(
                            height: 145.h,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Name at the top
                                Text(
                                  'الاسم : ${patient.name}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF649FCC),
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'العمر : ${patient.age} سنة',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF505558),
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'الجنس: ${patient.gender == 'male'
                                      ? 'ذكر'
                                      : patient.gender == 'female'
                                      ? 'أنثى'
                                      : patient.gender}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF505558),
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'رقم الهاتف : ${patient.phoneNumber}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF505558),
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'المدينة : ${patient.city}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF505558),
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Last item at the bottom
                                Text(
                                  'نوع العلاج : ${patient.treatmentHistory != null && patient.treatmentHistory!.isNotEmpty ? patient.treatmentHistory!.last : 'لا يوجد'}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF505558),
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 20.w),
                          // Patient Image (on the right - at the start from the right)
                          Padding(
                            padding: EdgeInsets.only(right: 4.w, top: 4.h, bottom: 4.h),
                            child: Container(
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
                        height: 40.h,
                        child: Container(
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4FEFF),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: const Color(0xB3649FCC), // 70% of #649FCC
                              borderRadius: BorderRadius.circular(10.r),
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
                              Tab(text: 'معرض الصور'),
                              Tab(text: 'المواعيد'),
                              Tab(text: 'السجلات'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: Stack(
                children: [
                  // Tab Content
                  TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGalleryTab(patient), // معرض الصور (index 0)
                      _buildAppointmentsTab(patient), // المواعيد (index 1)
                      _buildRecordsTab(patient), // السجلات (index 2)
                    ],
                  ),

                  // Add Record Button (Floating button)
                  Obx(() {
                    final selectedPatient =
                        _patientController.selectedPatient.value;
                    if (selectedPatient == null) {
                      return const SizedBox.shrink();
                    }

                    final tabIndex = _currentTabIndex.value;
                    return Positioned(
                      bottom: 24.h,
                      left: 240.w,
                      right: 240.w,
                      child: ElevatedButton(
                        onPressed: () {
                          _onButtonPressed(tabIndex, selectedPatient.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.9),
                          shadowColor: AppColors.primary.withOpacity(0.4),
                          elevation: 8,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32.w,
                            vertical: 12.h,
                          ),
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
          padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 6.h,),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return Container(
                margin: EdgeInsets.only(bottom: 6.h),
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
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
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                            final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);
                            return GestureDetector(
                              onTap: () {
                                if (validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl)) {
                                  _showImageFullScreenDialog(context, validImageUrl);
                                }
                              },
                              child: Container(
                                width: 60.w,
                                height: 68.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl)
                                      ? CachedNetworkImage(
                                          imageUrl: validImageUrl,
                                          fit: BoxFit.cover,
                                          progressIndicatorBuilder: (context, url, progress) => Container(
                                            color: AppColors.divider,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: progress.progress,
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                                      : Image.network(
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

      final now = DateTime.now();

      return Container(
        color: const Color(0xFFF4FEFF),
        child: ListView.builder(
          // المسافة بين شريط التبويب وأول كارت موعد = 10
          padding: EdgeInsets.only(
            top: 10.h,
            left: 24.w,
            right: 24.w,
            bottom: 24.h,
          ),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            final appointmentStatus = appointment.status.toLowerCase();

            // تحديد إذا كان الموعد قادم أم سابق بناءً على الحالة
            final isUpcoming =
                appointmentStatus == 'scheduled' &&
                (appointment.date.isAfter(now) ||
                    appointment.date.isAfter(now.subtract(Duration(hours: 1))));

            // تحديد حالة Checkbox بناءً على status
            final bool isCompleted = appointmentStatus == 'completed';
            final bool isCancelled =
                appointmentStatus == 'cancelled' ||
                appointmentStatus == 'canceled' ||
                appointmentStatus == 'no_show';
            final bool isPending =
                appointmentStatus == 'scheduled' ||
                appointmentStatus == 'pending';

            // Format date in Arabic
            String formattedDate = '';
            try {
              final dayName = DateFormat('EEEE', 'ar').format(appointment.date);
              final dateStr = DateFormat(
                'yyyy-MM-dd',
                'ar',
              ).format(appointment.date);
              formattedDate = 'يوم $dayName المصادف $dateStr';
            } catch (e) {
              formattedDate = DateFormat(
                'yyyy-MM-dd',
                'ar',
              ).format(appointment.date);
            }

            // Format time
            String formattedTime = '';
            try {
              final timeParts = appointment.time.split(':');
              if (timeParts.length >= 2) {
                final hour = int.parse(timeParts[0]);
                final minute = timeParts[1];
                final period = hour >= 12 ? 'مساءاً' : 'صباحاً';
                final displayHour = hour > 12
                    ? hour - 12
                    : (hour == 0 ? 12 : hour);
                formattedTime = '$displayHour:$minute $period';
              } else {
                formattedTime = appointment.time;
              }
            } catch (e) {
              formattedTime = appointment.time;
            }

            return Container(
              margin: EdgeInsets.only(bottom: 16.h),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isCompleted
                      ? Colors.green // أخضر للمكتمل
                      : (isCancelled
                            ? Colors.red // أحمر للملغي
                            : Colors.orange), // برتقالي لقيد الانتظار
                  width: isPending || isCompleted || isCancelled ? 2 : 1,
                ),
              ),
              // محتوى كرت الموعد (محاذى لليمين: النصوص من اليمين، الأيقونات/الأزرار من اليسار)
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // العنوان على اليمين
                      Expanded(
                        child: Text(
                          isPending && isUpcoming
                              ? 'موعد مريضك "${patient.name}" القادم هو'
                              : 'موعد مريضك "${patient.name}" السابق هو',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Checkbox ملاصق للنص من اليسار
                      Container(
                        width: 24.w,
                        height: 24.w,
                        margin: EdgeInsets.only(top: 2.h, left: 8.w),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isCompleted
                                ? AppColors.primary
                                : (isCancelled
                                      ? Colors.red
                                      : AppColors.divider),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4.r),
                          color: isCompleted
                              ? AppColors.primary
                              : (isCancelled
                                    ? Colors.red
                                    : Colors.transparent),
                        ),
                        child: isCompleted
                            ? Icon(
                                Icons.check,
                                color: AppColors.white,
                                size: 14.sp,
                              )
                            : (isCancelled
                                  ? Icon(
                                      Icons.close,
                                      color: AppColors.white,
                                      size: 14.sp,
                                    )
                                  : null),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Date + Time (يمين) مع الحالة (يسار)
                      Row(
                        children: [
                          // الحالة في اليسار
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.withOpacity(0.1)
                                  : (isCancelled
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.orange.withOpacity(
                                            0.1,
                                          )), // برتقالي لقيد الانتظار
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: isCompleted
                                    ? Colors.green
                                    : (isCancelled
                                          ? Colors.red
                                          : Colors.orange), // برتقالي لقيد الانتظار
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isCompleted
                                  ? 'مكتمل'
                                  : (isCancelled
                                        ? (appointmentStatus == 'no_show'
                                              ? 'لم يحضر'
                                              : 'ملغي')
                                        : 'قيد الانتظار'),
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: isCompleted
                                    ? Colors.green
                                    : (isCancelled
                                          ? Colors.red
                                          : Colors.orange), // برتقالي لقيد الانتظار
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          // التاريخ + الوقت من اليمين في نفس الصف
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Flexible(
                                  child: Text(
                                    '$formattedDate  في تمام الساعة $formattedTime',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: const Color.fromARGB(
                                        255,
                                        54,
                                        147,
                                        190,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Icon(
                                  Icons.calendar_today,
                                  size: 14.sp,
                                  color: const Color.fromARGB(
                                    255,
                                    54,
                                    147,
                                    190,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),

                      // Notes (if exists) with Change Status button besideها من اليسار
                      if (appointment.notes != null &&
                          appointment.notes!.isNotEmpty) ...[
                        SizedBox(height: 12.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // زر تغيير الحالة (يسار)
                            Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: TextButton.icon(
                                onPressed: () {
                                  _showChangeStatusDialog(
                                    context,
                                    appointment,
                                    patient.id,
                                  );
                                },
                                icon: Icon(
                                  Icons.edit,
                                  size: 16.sp,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  'تغيير الحالة',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  backgroundColor: AppColors.primary
                                      .withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      8.r,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(width: 8.w),

                            // Container للملاحظة (يمين)
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: AppColors.divider.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ملاحظة :',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      appointment.notes!,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // إذا لم تكن هناك ملاحظة، نعرض زر تغيير الحالة فقط
                        SizedBox(height: 12.h),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              _showChangeStatusDialog(
                                context,
                                appointment,
                                patient.id,
                              );
                            },
                            icon: Icon(
                              Icons.edit,
                              size: 16.sp,
                              color: AppColors.primary,
                            ),
                            label: Text(
                              'تغيير الحالة',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              backgroundColor: AppColors.primary.withOpacity(
                                0.1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Images (if exists)
                      Builder(
                        builder: (context) {
                          final imagesToShow =
                              appointment.imagePaths.isNotEmpty
                              ? appointment.imagePaths
                              : (appointment.imagePath != null &&
                                        appointment.imagePath!.isNotEmpty
                                    ? [appointment.imagePath!]
                                    : []);

                          if (imagesToShow.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            children: [
                              SizedBox(height: 12.h),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'صور :',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                  SizedBox(height: 8.h),
                                  SizedBox(
                                    height: 60.h,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      reverse: true,
                                      itemCount: imagesToShow.length,
                                      separatorBuilder: (context, index) =>
                                          SizedBox(width: 8.w),
                                      itemBuilder: (context, index) {
                                        final imageUrl =
                                            ImageUtils.convertToValidUrl(
                                              imagesToShow[index],
                                            );
                                        return GestureDetector(
                                          onTap: () {
                                            if (imageUrl != null &&
                                                ImageUtils.isValidImageUrl(imageUrl)) {
                                              _showImageFullScreenDialog(context, imageUrl);
                                            }
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8.r),
                                            child:
                                                imageUrl != null &&
                                                    ImageUtils.isValidImageUrl(
                                                      imageUrl,
                                                    )
                                                ? CachedNetworkImage(
                                                    imageUrl: imageUrl,
                                                    width: 60.w,
                                                    height: 60.h,
                                                    fit: BoxFit.cover,
                                                    progressIndicatorBuilder:
                                                        (
                                                          context,
                                                          url,
                                                          progress,
                                                        ) => Container(
                                                          width: 60.w,
                                                          height: 60.h,
                                                          color: AppColors
                                                              .divider,
                                                          child: Center(
                                                            child: CircularProgressIndicator(
                                                              value: progress
                                                                  .progress,
                                                              strokeWidth: 2,
                                                              valueColor:
                                                                  AlwaysStoppedAnimation<
                                                                      Color
                                                                    >(
                                                                      AppColors
                                                                          .primary,
                                                                    ),
                                                            ),
                                                          ),
                                                        ),
                                                    errorWidget:
                                                        (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => Container(
                                                          width: 60.w,
                                                          height: 60.h,
                                                          color: AppColors
                                                              .divider,
                                                          child: Icon(
                                                            Icons
                                                                .broken_image,
                                                            size: 24.sp,
                                                            color: AppColors
                                                                .textHint,
                                                          ),
                                                        ),
                                                  )
                                                : Container(
                                                    width: 60.w,
                                                    height: 60.h,
                                                    color: AppColors.divider,
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      size: 24.sp,
                                                      color:
                                                          AppColors.textHint,
                                                    ),
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
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
      // Only consider stages for this patient (controller may hold stages for multiple patients)
      final patientStages = implantStageController.stagesForPatient(patient.id);
      
      // Show loading only if no stages exist yet (initial load)
      if (implantStageController.isLoading.value && patientStages.isEmpty) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

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
                      fontSize: 14.sp,
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
                if (stage.isCompleted) {
                  // إلغاء الإكمال
                  success = await implantStageController.uncompleteStage(
                    patientId,
                    stage.stageName,
                  );
                } else {
                  // إكمال المرحلة
                  success = await implantStageController.completeStage(
                    patientId,
                    stage.stageName,
                  );
                }

                if (success) {
                  // لا نعرض Snackbar للنجاح، التحديث المتفائل حدث بالفعل في الواجهة
                } else {
                  final errorMsg =
                      implantStageController.errorMessage.value.isNotEmpty
                      ? implantStageController.errorMessage.value
                      : 'فشل تحديث حالة المرحلة';
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
                width: 24.w,
                height: 24.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stage.isCompleted
                      ? AppColors.primary
                      : AppColors.white,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: stage.isCompleted
                    ? Icon(Icons.check, color: AppColors.white, size: 16.sp)
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
      width: 110.w,
      decoration: BoxDecoration(
        color: const Color(0xFF649FCC),
      ),
      child: Column(
        children: [
          SizedBox(height: 50.h),
          // Logo Section
          Image.asset(
            'assets/images/logo.png',
            width: 140.w,
            height: 140.h,
            fit: BoxFit.contain,
          ),

          

          // Vertical Text
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: Center(
                child: Text(
                  'مركز فرح التخصصي لطب الاسنان',
                  style: TextStyle(
                    fontSize: 26.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 25.h),

          // Bottom Icons
          Column(
            children: [
              // Tooth Logo at bottom
              Image.asset(
                'assets/images/happy 2.png',
                width: 80.w,
                height: 80.h,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.medical_services_outlined,
                    color: Colors.white,
                    size: 30.sp,
                  );
                },
              ),
              
             
            ],
          ),

          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  String _getButtonText(int tabIndex) {
    switch (tabIndex) {
      case 0: // معرض الصور (Gallery)
        return 'اضافة صورة';
      case 1: // المواعيد (Appointments)
        return 'حجز موعد';
      case 2: // السجلات (Records)
        return 'اضافة سجل';
      default:
        return 'اضافة سجل';
    }
  }

  void _onButtonPressed(int tabIndex, String patientId) {
    switch (tabIndex) {
      case 0: // معرض الصور (Gallery)
        _showAddImageDialog(context, patientId);
        break;
      case 1: // المواعيد (Appointments)
        _showBookAppointmentDialog(context, patientId);
        break;
      case 2: // السجلات (Records)
        _showAddRecordDialog(context, patientId);
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
                width: 360.w,
                height: 400.h,
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
                                  // لا نعيد تحميل السجلات هنا، الكونترولر أضاف السجل متفائلاً
                                } catch (e) {
                                  // الخطأ يُعرض من داخل الكونترولر
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
                width: 365.w,
                height: 460.h,
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
                                          // المعرض تم تحديثه متفائلاً في الكونترولر، لا حاجة لإعادة تحميل
                                        } else {
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
                width: 400.w,
                height: 600.h,
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
                              // لا نعيد تحميل المواعيد هنا، الكونترولر يضيف الموعد متفائلاً
                            } catch (e) {
                              print(
                                '❌ [DoctorHomeScreen] Error adding appointment: $e',
                              );
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
                        onTap: () => Navigator.of(dialogContext).pop(),
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
    final screenSize = MediaQuery.of(context).size;
    final maxDialogWidth = screenSize.width * 0.6;
    final maxDialogHeight = screenSize.height * 0.75;
    final maxImageWidth = maxDialogWidth - 48.w;
    final maxImageHeight = maxDialogHeight - 180.h;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24.w),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxDialogWidth,
              maxHeight: maxDialogHeight,
            ),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
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
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
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
                SizedBox(height: 16.h),

                // Image
                Flexible(
                  child: Center(
                    child: imageUrl != null && ImageUtils.isValidImageUrl(imageUrl)
                        ? GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              _showImageFullScreenDialog(context, imageUrl);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                                width: maxImageWidth,
                                height: maxImageHeight,
                                progressIndicatorBuilder: (context, url, progress) =>
                                    Container(
                                      width: maxImageWidth,
                                      height: maxImageHeight,
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
                                  width: maxImageWidth,
                                  height: maxImageHeight,
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
                        : Container(
                            width: maxImageWidth,
                            height: maxImageHeight,
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
                  ),
                ),
                SizedBox(height: 12.h),

                // Date
                if (galleryImage.createdAt != null &&
                    galleryImage.createdAt.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            galleryImage.createdAt,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Note
                if (galleryImage.note != null &&
                    galleryImage.note!.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الشرح:',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          width: double.infinity,
                          constraints: BoxConstraints(maxHeight: 100.h),
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppColors.divider.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              galleryImage.note!,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textPrimary,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
                    onTap: () => Navigator.of(dialogContext).pop(),
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
            width: 360.w,
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

  void _showAddPatientDialog(BuildContext context) {
    final DoctorService _doctorService = DoctorService();
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _phoneController = TextEditingController();
    final TextEditingController _ageController = TextEditingController();
    final ImagePicker _imagePicker = ImagePicker();
    
    // State variables
    String? selectedGender;
    String? selectedCity;
    bool _isLoading = false;
    Uint8List? _selectedPatientImageBytes;
    String? _selectedPatientImageName;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            final List<String> cities = [
              'بغداد',
              'البصرة',
              'النجف الاشرف',
              'كربلاء',
              'الموصل',
              'أربيل',
              'السليمانية',
              'ديالى',
              'الديوانية',
              'المثنى',
              'كركوك',
              'واسط',
              'ميسان',
              'الأنبار',
              'ذي قار',
              'بابل',
              'دهوك',
              'صلاح الدين',
            ];

            bool _isPhoneValid(String phone) {
              final cleaned = phone.trim();
              return RegExp(r'^07\d{9}$').hasMatch(cleaned);
            }

            void _showCityPicker() {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                ),
                isScrollControlled: true,
                builder: (context) {
                  final maxHeight = MediaQuery.of(context).size.height * 0.6;
                  return Container(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: cities.length,
                            itemBuilder: (context, index) {
                              final city = cities[index];
                              return ListTile(
                                title: Text(
                                  city,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                onTap: () {
                                  setDialogState(() {
                                    selectedCity = city;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            Future<void> _pickPatientImage(ImageSource source) async {
              try {
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    allowMultiple: false,
                  );
                  
                  if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
                    final file = File(result.files.first.path!);
                    final bytes = await file.readAsBytes();
                    final fileName = result.files.first.name.isNotEmpty
                        ? result.files.first.name
                        : 'patient_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    setDialogState(() {
                      _selectedPatientImageBytes = bytes;
                      _selectedPatientImageName = fileName;
                    });
                  }
                } else {
                  final XFile? picked = await _imagePicker.pickImage(
                    source: source,
                    imageQuality: 85,
                  );
                  if (picked == null) return;
                  final bytes = await picked.readAsBytes();
                  final fileName = picked.name.isNotEmpty
                      ? picked.name
                      : 'patient_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  setDialogState(() {
                    _selectedPatientImageBytes = bytes;
                    _selectedPatientImageName = fileName;
                  });
                }
              } catch (e) {
                Get.snackbar(
                  'خطأ',
                  'فشل اختيار الصورة: ${e.toString()}',
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 3),
                );
              }
            }

            void _showPatientImagePicker() {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                ),
                builder: (context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 12.h),
                        Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                          ListTile(
                            leading: Icon(Icons.photo_library, color: AppColors.primary),
                            title: Text('اختيار صورة', textAlign: TextAlign.right),
                            onTap: () async {
                              Navigator.pop(context);
                              await _pickPatientImage(ImageSource.gallery);
                            },
                          )
                        else ...[
                          ListTile(
                            leading: Icon(Icons.photo_library, color: AppColors.primary),
                            title: Text('اختيار من المعرض', textAlign: TextAlign.right),
                            onTap: () async {
                              Navigator.pop(context);
                              await _pickPatientImage(ImageSource.gallery);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.photo_camera, color: AppColors.primary),
                            title: Text('التقاط صورة', textAlign: TextAlign.right),
                            onTap: () async {
                              Navigator.pop(context);
                              await _pickPatientImage(ImageSource.camera);
                            },
                          ),
                        ],
                        if (_selectedPatientImageBytes != null)
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: Colors.red),
                            title: const Text('إزالة الصورة', textAlign: TextAlign.right),
                            onTap: () {
                              Navigator.pop(context);
                              setDialogState(() {
                                _selectedPatientImageBytes = null;
                                _selectedPatientImageName = null;
                              });
                            },
                          ),
                        SizedBox(height: 8.h),
                      ],
                    ),
                  );
                },
              );
            }

            Future<void> _handleAddPatient() async {
              final trimmedPhone = _phoneController.text.trim();

              if (_nameController.text.isEmpty ||
                  trimmedPhone.isEmpty ||
                  selectedGender == null ||
                  selectedCity == null ||
                  _ageController.text.isEmpty) {
                Get.snackbar(
                  'خطأ',
                  'يرجى ملء جميع الحقول',
                  snackPosition: SnackPosition.TOP,
                );
                return;
              }

              final age = int.tryParse(_ageController.text);
              if (age == null || age < 1 || age > 120) {
                Get.snackbar(
                  'خطأ',
                  'يرجى إدخال عمر صحيح',
                  snackPosition: SnackPosition.TOP,
                );
                return;
              }

              if (!_isPhoneValid(trimmedPhone)) {
                Get.snackbar(
                  'خطأ',
                  'رقم الهاتف يجب أن يكون 11 رقماً ويبدأ بـ 07',
                  snackPosition: SnackPosition.TOP,
                );
                return;
              }

              setDialogState(() {
                _isLoading = true;
              });

              try {
                // إضافة المريض
                var createdPatient = await runWithOperationDialog(
                  context: dialogContext,
                  message: 'جارٍ الإضافة',
                  action: () async {
                    return await _doctorService.addPatient(
                      name: _nameController.text.trim(),
                      phoneNumber: trimmedPhone,
                      gender: selectedGender!,
                      age: age,
                      city: selectedCity!,
                    );
                  },
                );

                if (_selectedPatientImageBytes != null) {
                  try {
                    await runWithOperationDialog(
                      context: dialogContext,
                      message: 'جارٍ الرفع',
                      action: () async {
                        await _doctorService.uploadPatientImage(
                          patientId: createdPatient.id,
                          imageBytes: _selectedPatientImageBytes!,
                          fileName: _selectedPatientImageName ??
                              'patient_${DateTime.now().millisecondsSinceEpoch}.jpg',
                        );
                        return createdPatient;
                      },
                    );
                  } catch (e) {
                    if (e is ApiException) {
                      Get.snackbar(
                        'تنبيه',
                        'تم إنشاء المريض لكن فشل رفع الصورة: ${e.message}',
                        snackPosition: SnackPosition.TOP,
                      );
                    } else {
                      Get.snackbar(
                        'تنبيه',
                        'تم إنشاء المريض لكن فشل رفع الصورة',
                        snackPosition: SnackPosition.TOP,
                      );
                    }
                  }
                }

                // إغلاق الـ dialog أولاً
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                
                // إضافة المريض مباشرة إلى قائمة المرضى وتعيينه كمحدد (تحديث حي)
                _patientController.addPatient(createdPatient);

                // عرض رسالة النجاح بعد الإضافة الحية
                Get.snackbar(
                  'نجح',
                  'تم إضافة المريض بنجاح',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: AppColors.success,
                  colorText: AppColors.white,
                );
              } on ApiException catch (e) {
                if (dialogContext.mounted) {
                  Get.snackbar(
                    'خطأ',
                    e.message,
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: AppColors.error,
                    colorText: AppColors.white,
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Get.snackbar(
                    'خطأ',
                    'فشل إضافة المريض',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: AppColors.error,
                    colorText: AppColors.white,
                  );
                }
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    _isLoading = false;
                  });
                }
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 400.w,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button and title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'اضافة مريض',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
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
                SizedBox(height: 24.h),
                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Patient image picker
                            GestureDetector(
                              onTap: _showPatientImagePicker,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 60.r,
                                    backgroundColor: AppColors.primaryLight,
                                    backgroundImage: _selectedPatientImageBytes != null
                                        ? MemoryImage(_selectedPatientImageBytes!)
                                        : null,
                                    child: _selectedPatientImageBytes == null
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person,
                                                size: 52.sp,
                                                color: AppColors.primary,
                                              ),
                                              SizedBox(height: 4.h),
                                              Text(
                                                'إضافة صورة المريض',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 4.h,
                                    right: 4.w,
                                    child: Container(
                                      width: 34.w,
                                      height: 34.w,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        color: AppColors.white,
                                        size: 18.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24.h),
                            CustomTextField(
                              labelText: AppStrings.name,
                              hintText: AppStrings.enterYourName,
                              controller: _nameController,
                            ),
                            SizedBox(height: 24.h),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.gender,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                GenderSelector(
                                  selectedGender: selectedGender,
                                  onGenderChanged: (gender) {
                                    setDialogState(() {
                                      selectedGender = gender;
                                    });
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 24.h),
                            CustomTextField(
                              labelText: AppStrings.phoneNumber,
                              hintText: '0000 000 0000',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: 24.h),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    labelText: AppStrings.city,
                                    hintText: AppStrings.selectCity,
                                    readOnly: true,
                                    onTap: _showCityPicker,
                                    controller: TextEditingController(
                                      text: selectedCity ?? '',
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: CustomTextField(
                                    labelText: AppStrings.age,
                                    hintText: AppStrings.selectCity,
                                    controller: _ageController,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                    ),
                    // Add button
                    Container(
                      width: double.infinity,
                      height: 50.h,
                      decoration: BoxDecoration(
                        color: _isLoading
                            ? AppColors.textHint
                            : AppColors.secondary,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _handleAddPatient,
                          borderRadius: BorderRadius.circular(16.r),
                          child: Center(
                            child: _isLoading
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    AppStrings.addButton,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  ),
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
      },
    ).then((_) {
      _nameController.dispose();
      _phoneController.dispose();
      _ageController.dispose();
    });
  }

  void _showDoctorProfileDialog(BuildContext context) {
    final user = _authController.currentUser.value;
    final imageUrl = user?.imageUrl;
    final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400.w,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x29649FCC),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: title + close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الملف الشخصي',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 20.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                // Profile image
                CircleAvatar(
                  radius: 48.r,
                  backgroundColor: AppColors.primaryLight,
                  child: validImageUrl != null &&
                          ImageUtils.isValidImageUrl(validImageUrl)
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: validImageUrl,
                            fit: BoxFit.cover,
                            width: 96.w,
                            height: 96.w,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (context, url) =>
                                Container(color: AppColors.primaryLight),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              size: 40.sp,
                              color: AppColors.white,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 40.sp,
                          color: AppColors.white,
                        ),
                ),
                SizedBox(height: 24.h),
                // Info fields
                _buildProfileInfoRow('الاسم', user?.name ?? ''),
                SizedBox(height: 12.h),
                _buildProfileInfoRow('رقم الهاتف', user?.phoneNumber ?? ''),
                SizedBox(height: 24.h),
                // Edit button
                SizedBox(
                  width: double.infinity,
                  height: 45.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showEditDoctorProfileDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      'تعديل الملف الشخصي',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // Working hours button
                SizedBox(
                  width: double.infinity,
                  height: 45.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showWorkingHoursDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'أوقات العمل',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // Logout button
                SizedBox(
                  width: double.infinity,
                  height: 45.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _authController.logout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.exit_to_app,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          AppStrings.logout,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
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

  Widget _buildProfileInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.divider,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditDoctorProfileDialog(BuildContext context) {
    final AuthService _authService = AuthService();
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _phoneController = TextEditingController();
    
    // Load current data
    final user = _authController.currentUser.value;
    _nameController.text = user?.name ?? '';
    _phoneController.text = user?.phoneNumber ?? '';
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool _isLoading = false;
            
            Future<void> _saveChanges() async {
              if (_nameController.text.isEmpty) {
                Get.snackbar(
                  'خطأ',
                  'يرجى إدخال الاسم',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: AppColors.error,
                  colorText: AppColors.white,
                );
                return;
              }

              if (_phoneController.text.isEmpty) {
                Get.snackbar(
                  'خطأ',
                  'يرجى إدخال رقم الهاتف',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: AppColors.error,
                  colorText: AppColors.white,
                );
                return;
              }

              setDialogState(() {
                _isLoading = true;
              });

              try {
                await _authService.updateProfile(
                  name: _nameController.text,
                  phone: _phoneController.text,
                );

                await _authController.checkLoggedInUser(navigate: false);

                // Close dialog first
                Navigator.of(dialogContext).pop();
                
                // Show success message after closing
                Future.delayed(const Duration(milliseconds: 100), () {
                  Get.snackbar(
                    'نجح',
                    'تم حفظ التغييرات بنجاح',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: AppColors.success,
                    colorText: AppColors.white,
                  );
                });
              } catch (e) {
                // Don't close dialog on error, just show error message
                setDialogState(() {
                  _isLoading = false;
                });
                Get.snackbar(
                  'خطأ',
                  'فشل حفظ التغييرات: ${e.toString()}',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: AppColors.error,
                  colorText: AppColors.white,
                );
              }
            }
            
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 400.w,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x29649FCC),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'تعديل الملف الشخصي',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(dialogContext).pop(),
                            child: Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 20.sp,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      // Name field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.name,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          CustomTextField(
                            controller: _nameController,
                            hintText: 'أدخل الاسم',
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      // Phone field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.phoneNumber,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          CustomTextField(
                            controller: _phoneController,
                            hintText: 'أدخل رقم الهاتف',
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 45.h,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'حفظ التغييرات',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
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
      _nameController.dispose();
      _phoneController.dispose();
    });
  }

  void _showWorkingHoursDialog(BuildContext context) {
    final WorkingHoursController controller = Get.put(WorkingHoursController());
    
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

    Future<void> _selectTime(
      BuildContext context,
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
        context: context,
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
        Get.snackbar(
          'تم الحفظ',
          result['message'] ?? 'تم حفظ أوقات العمل بنجاح',
          backgroundColor: AppColors.primary,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      } else {
        Get.snackbar(
          'فشل الحفظ',
          result['message'] ?? 'تعذر حفظ أوقات العمل',
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
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
                foregroundColor: AppColors.error,
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
            snackPosition: SnackPosition.TOP,
          );
        } else {
          Get.snackbar(
            'فشل الحذف',
            result['message'] ?? 'تعذر حذف أوقات العمل',
            backgroundColor: AppColors.error,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
          );
        }
      }
    }

    Widget _buildTimeRow(
      BuildContext context,
      int dayIndex, {
      required String label,
      required String value,
      required bool isStart,
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
              onTap: () => _selectTime(context, dayIndex, value, isStart: isStart),
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

    Widget _buildDayCard(int dayIndex) {
      return Obx(() {
        final day = controller.workingHours[dayIndex];
        final isWorking = day['isWorking'] as bool;
        final isExpanded = controller.expandedDays[dayIndex] ?? false;

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
            child: ExpansionTile(
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
                        context,
                        dayIndex,
                        label: 'من',
                        value: day['startTime'],
                        isStart: true,
                      ),
                      SizedBox(height: 12.h),
                      _buildTimeRow(
                        context,
                        dayIndex,
                        label: 'إلى',
                        value: day['endTime'],
                        isStart: false,
                      ),
                      SizedBox(height: 12.h),
                      _buildSlotDurationRow(dayIndex, day['slotDuration']),
                      SizedBox(height: 12.h),
                      _buildApplyToAllDaysButton(dayIndex),
                    ]
                  : [],
            ),
          ),
        );
      });
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500.w,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x29649FCC),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إدارة أوقات العمل',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 20.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // Info card
                Container(
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
                ),
                SizedBox(height: 16.h),
                // Days list
                Flexible(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        children: List.generate(7, (index) => _buildDayCard(index)),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 16.h),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _onDeleteAll,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error),
                          foregroundColor: AppColors.error,
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
                            color: AppColors.error,
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
                width: 360.w,
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
                            onTap: () => Navigator.of(dialogContext).pop(),
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

  void _showChangeStatusDialog(
    BuildContext context,
    AppointmentModel appointment,
    String patientId,
  ) {
    final statusOptions = [
      {'value': 'scheduled', 'label': 'قيد الانتظار', 'icon': Icons.schedule},
      {'value': 'completed', 'label': 'مكتمل', 'icon': Icons.check_circle},
      {'value': 'cancelled', 'label': 'ملغي', 'icon': Icons.cancel},
      {'value': 'no_show', 'label': 'لم يحضر', 'icon': Icons.person_off},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تغيير حالة الموعد',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: statusOptions.map((option) {
            final isSelected =
                appointment.status.toLowerCase() ==
                option['value'].toString().toLowerCase();
            return ListTile(
              leading: Icon(
                option['icon'] as IconData,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              title: Text(
                option['label'] as String,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: AppColors.primary, size: 20.sp)
                  : null,
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await _appointmentController.updateAppointmentStatus(
                    patientId,
                    appointment.id,
                    option['value'] as String,
                  );
                  // إعادة تحميل المواعيد
                  await _appointmentController.loadPatientAppointmentsById(
                    patientId,
                  );
                } catch (e) {
                  // الخطأ معالج في Controller
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
