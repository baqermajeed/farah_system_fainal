import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/gallery_controller.dart';
import 'package:farah_sys_final/controllers/working_hours_controller.dart';
import 'package:farah_sys_final/controllers/medical_record_controller.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/implant_stage_controller.dart';
import 'package:farah_sys_final/models/implant_stage_model.dart';
import 'package:farah_sys_final/models/medical_record_model.dart';
import 'package:farah_sys_final/services/working_hours_service.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/chat_service.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/models/doctor_model.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:farah_sys_final/widgets/portrait_network_image.dart';

// Shared shadow used in patient UI cards.
const List<BoxShadow> kPatientFileShadow = [
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 12,
    offset: Offset(0, 6),
  ),
];

class PatientDetailsScreen extends StatefulWidget {
  const PatientDetailsScreen({super.key});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

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

class _PatientDetailsScreenState extends State<PatientDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final PatientController _patientController = Get.find<PatientController>();
  final AppointmentController _appointmentController =
      Get.find<AppointmentController>();
  final AuthController _authController = Get.find<AuthController>();
  final PatientService _patientService = PatientService();
  final ChatService _chatService = ChatService();
  late final GalleryController _galleryController;
  late final MedicalRecordController _medicalRecordController;
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  final ImagePicker _imagePicker = ImagePicker();
  String? patientId;
  AppointmentModel? _selectedAppointmentArg;
  String? _selectedAppointmentId;
  final Map<String, GlobalKey> _appointmentItemKeys = {};
  bool _didAutoScrollToSelected = false;
  bool _didAutoScrollToSelectedImplantStage = false;
  final Map<String, GlobalKey> _implantStageItemKeys = {};

  // Unread messages count
  final RxInt _unreadCount = 0.obs;

  // State for doctors
  final RxList<DoctorModel> _patientDoctors = <DoctorModel>[].obs;
  final RxBool _isLoadingDoctors = false.obs;

  // Selection mode state
  Set<String> selectedAppointmentIds = {};
  bool isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    // Get patientId (and optional selected appointment) from arguments
    final args = Get.arguments as Map<String, dynamic>?;
    patientId = args?['patientId'];
    final dynamic passedAppointment = args?['appointment'];
    if (passedAppointment is AppointmentModel) {
      _selectedAppointmentArg = passedAppointment;
    }
    final dynamic passedAppointmentId = args?['appointmentId'];
    _selectedAppointmentId =
        _selectedAppointmentArg?.id ?? passedAppointmentId?.toString();

    // If we came from an appointment tap, open the "المواعيد" tab by default.
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _selectedAppointmentId != null ? 1 : 0,
    );

    // Add listener for immediate tab change updates
    _tabController.addListener(() {
      setState(() {});
    });

    // Initialize GalleryController
    _galleryController = Get.put(GalleryController());
    // Initialize MedicalRecordController
    _medicalRecordController = Get.put(MedicalRecordController());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (patientId != null) {
        final userType = _authController.currentUser.value?.userType;
        final isReceptionist =
            userType != null && userType.toLowerCase() == 'receptionist';

        // For receptionist, ensure patients list is loaded so getPatientById works
        if (isReceptionist) {
          // Check if patient exists in the list, if not, reload patients
          final patient = _patientController.getPatientById(patientId!);
          if (patient == null) {
            await _patientController.loadPatients();
          }
          _loadPatientDoctors(patientId!);
        } else {
          // Only load appointments, gallery, and records for non-receptionists (doctors)
          _appointmentController.loadPatientAppointmentsById(patientId!);
          // Load patient gallery
          _galleryController.loadGallery(patientId!);
          // Load patient records
          _medicalRecordController.loadPatientRecords(patientId!);
          // Load unread count
          _loadUnreadCount();

          // Load implant stages if treatment type is زراعة
          final patient = _patientController.getPatientById(patientId!);
          if (patient != null &&
              patient.treatmentHistory != null &&
              patient.treatmentHistory!.isNotEmpty &&
              patient.treatmentHistory!.first == 'زراعة') {
            final implantStageController = Get.put(ImplantStageController());
            implantStageController.ensureStagesLoaded(patientId!);
          }
        }
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
    final baseTheme = Theme.of(context);
    final cairoTheme = baseTheme.copyWith(
      textTheme: GoogleFonts.cairoTextTheme(baseTheme.textTheme),
      primaryTextTheme: GoogleFonts.cairoTextTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: cairoTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4FEFF),
        floatingActionButton: _tabController.index == 1 &&
                isSelectionMode &&
                selectedAppointmentIds.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => _showDeleteConfirmDialog(context),
                backgroundColor: Colors.red,
                icon: Icon(Icons.delete, color: AppColors.white),
                label: Text(
                  'حذف (${selectedAppointmentIds.length})',
                  style: GoogleFonts.cairo(color: AppColors.white),
                ),
              )
            : null,
        body: SafeArea(
          child: Obx(() {
          final userType = _authController.currentUser.value?.userType;
          final isReceptionist =
              userType != null && userType.toLowerCase() == 'receptionist';

          return Column(
            children: [
              Expanded(
                child: NestedScrollView(
                  headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                    return <Widget>[
                      // Header with light blue background
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
                                    'ملف المريض',
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              // Cancel selection button when in selection mode
                              if (isSelectionMode)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      isSelectionMode = false;
                                      selectedAppointmentIds.clear();
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(8.w),
                                    child: Text(
                                      'إلغاء',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              // Chat icon on the RIGHT (only for doctor, not receptionist)
                              Builder(
                                builder: (context) {
                                  if (isReceptionist) {
                                    return SizedBox(width: 24.sp);
                                  }

                                  return GestureDetector(
                                    onTap: () async {
                                      if (patientId != null) {
                                        await Get.toNamed(
                                          AppRoutes.chat,
                                          arguments: {'patientId': patientId},
                                        );
                                        // Reload unread count when returning from chat
                                        await Future.delayed(
                                          const Duration(milliseconds: 300),
                                        );
                                        _loadUnreadCount();
                                      }
                                    },
                                    child: Obx(() {
                                      final hasUnread = _unreadCount.value > 0;
                                      return Stack(
                                        children: [
                                          Center(
                                            child: Image.asset(
                                              'assets/images/message.png',
                                              width: 35.sp,
                                              height: 35.sp,
                                            fit: BoxFit.contain,
                                            ),
                                          ),
                                          if (hasUnread)
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                width: 10.w,
                                                height: 10.h,
                                                decoration: BoxDecoration(
                                                  color: Colors.pink,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    }),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Patient Information Card
                      SliverToBoxAdapter(
                        child: Obx(() {
                          final patient = patientId != null
                              ? _patientController.getPatientById(patientId!)
                              : null;

                          if (patient == null) {
                            return const SizedBox.shrink();
                          }

                          final userType =
                              _authController.currentUser.value?.userType;
                          final isReceptionist =
                              userType != null &&
                              userType.toLowerCase() == 'receptionist';

                          return Column(
                            children: [
                              Builder(
                                builder: (context) {
                                  final baseTheme = Theme.of(context);
                                  final cairoTheme = baseTheme.copyWith(
                                    textTheme:
                                        GoogleFonts.cairoTextTheme(baseTheme.textTheme),
                                    primaryTextTheme: GoogleFonts.cairoTextTheme(
                                      baseTheme.primaryTextTheme,
                                    ),
                                  );

                                  return Theme(
                                    data: cairoTheme,
                                    child: Container(
                                      height: 156.h,
                                      padding: EdgeInsets.zero,
                                      margin: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 10.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(8.r),
                                        boxShadow: kPatientFileShadow,
                                      ),
                                      child: Row(
                                        children: [
                                          // Patient Image on the right (in RTL) - first element (no margin/padding on right)
                                          PortraitNetworkImage(
                                            imageUrl: patient.imageUrl,
                                            borderRadius:
                                                BorderRadius.circular(8.r),
                                            aspectRatio: 110 / 156,
                                            width: 110.w,
                                            height: 156.h,
                                            showSkeleton: true,
                                          ),
                                          SizedBox(width: 12.w),
                                          // Container that includes Name at top and Row with details + QR code below
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: 0.w,
                                                top: 6.h,
                                                bottom: 6.h,
                                              ),
                                              child: Column(
                                                // crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  // Name at the top
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Text(
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
                                                  ),
                                                  // اجعل المسافة بين الاسم وباقي البيانات مساوية لباقي المسافات
                                                  SizedBox(height: 4.h),

                                                  // Row containing details column and QR code column
                                                  Row(
                                                    children: [
                                                      // Patient Details column
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            Align(
                                                              alignment: Alignment
                                                                  .centerRight,
                                                              child: Text(
                                                                'العمر : ${patient.age} سنة',
                                                                style: GoogleFonts.cairo(
                                                                  fontSize: 12.sp,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: const Color(
                                                                    0xFF505558,
                                                                  ),
                                                                ),
                                                                textAlign: TextAlign
                                                                    .right,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            SizedBox(height: 4.h),
                                                            Align(
                                                              alignment: Alignment
                                                                  .centerRight,
                                                              child: Text(
                                                                'الجنس: ${patient.gender == 'male' ? 'ذكر' : patient.gender == 'female' ? 'أنثى' : patient.gender}',
                                                                style: GoogleFonts.cairo(
                                                                  fontSize: 12.sp,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: const Color(
                                                                    0xFF505558,
                                                                  ),
                                                                ),
                                                                textAlign: TextAlign
                                                                    .right,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            SizedBox(height: 4.h),
                                                            Align(
                                                              alignment: Alignment
                                                                  .centerRight,
                                                              child: Text(
                                                                'رقم الهاتف : ${patient.phoneNumber}',
                                                                style: GoogleFonts.cairo(
                                                                  fontSize: 12.sp,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: const Color(
                                                                    0xFF505558,
                                                                  ),
                                                                ),
                                                                textAlign: TextAlign
                                                                    .right,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            SizedBox(height: 4.h),
                                                            Align(
                                                              alignment: Alignment
                                                                  .centerRight,
                                                              child: Text(
                                                                'المدينة : ${patient.city}',
                                                                style: GoogleFonts.cairo(
                                                                  fontSize: 12.sp,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: const Color(
                                                                    0xFF505558,
                                                                  ),
                                                                ),
                                                                textAlign: TextAlign
                                                                    .right,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            SizedBox(height: 4.h),
                                                            Align(
                                                              alignment: Alignment
                                                                  .centerRight,
                                                              child: Text(
                                                                'نوع العلاج : ${patient.treatmentHistory != null && patient.treatmentHistory!.isNotEmpty ? patient.treatmentHistory!.last : 'لا يوجد'}',
                                                                style: GoogleFonts.cairo(
                                                                  fontSize: 12.sp,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: const Color(
                                                                    0xFF505558,
                                                                  ),
                                                                ),
                                                                textAlign: TextAlign
                                                                    .right,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(width: 0.w),

                                                // QR Code column on the left (in RTL)
                                                Column(
                                                  children: [
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
                                                        padding: EdgeInsets.all(
                                                          0.w,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              AppColors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8.r,
                                                              ),
                                                        ),
                                                        child: QrImageView(
                                                          data: patient.id,
                                                          version:
                                                              QrVersions.auto,
                                                          size: 54.w,
                                                          backgroundColor:
                                                              Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    // Edit treatment type button (only for doctor, not receptionist)
                                                    if (!isReceptionist) ...[
                                                      SizedBox(height: 8.h),
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
                                                            color: AppColors
                                                                .primaryLight,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8.r,
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            Icons.edit,
                                                            color: AppColors
                                                                .primary,
                                                            size: 20.sp,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
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
                                  );
                                },
                              ),

                              // Doctors Section (only for receptionist)
                              if (isReceptionist) ...[
                                SizedBox(height: 24.h),
                                _buildDoctorsSection(patient),
                              ],
                            ],
                          );
                        }),
                      ),

                      // Tabs - Sticky Header (only for non-receptionist)
                      if (!isReceptionist)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverTabBarDelegate(
                            child: Container(
                              height: 48.0,
                              margin: EdgeInsets.symmetric(horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.2),
                                  width: 1,
                                ),
                                boxShadow: kPatientFileShadow,
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicator: BoxDecoration(
                                  color: const Color(0xB3649FCC), // 70% of #649FCC
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 0,
                                  ),
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                labelColor: const Color.fromARGB(255, 255, 255, 255),
                                unselectedLabelColor: const Color(0xFF505558),
                                labelStyle: GoogleFonts.cairo(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                                unselectedLabelStyle: GoogleFonts.cairo(
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
                    ];
                  },
                  body: isReceptionist
                      ? Container(color: const Color(0xFFF4FEFF))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildRecordsTab(),
                            _buildAppointmentsTab(),
                            _buildGalleryTab(),
                          ],
                        ),
                ),
              ),

              // Button at the bottom
              Padding(
                padding: EdgeInsets.all(24.w),
                child: Obx(() {
                  final patient = patientId != null
                      ? _patientController.getPatientById(patientId!)
                      : null;

                  final userTypeForButton =
                      _authController.currentUser.value?.userType;
                  final isReceptionistForButton =
                      userTypeForButton != null &&
                      userTypeForButton.toLowerCase() == 'receptionist';

                  if (isReceptionistForButton) {
                    // For receptionist: show "تحويل" button
                    return Container(
                      width: double.infinity,
                      height: 56.h,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (patient != null) {
                            Get.toNamed(
                              AppRoutes.selectDoctor,
                              arguments: {
                                'patientId': patient.id,
                                'currentDoctorIds': patient.doctorIds,
                              },
                            )?.then((result) async {
                              if (result == true && patientId != null) {
                                // Reload patient doctors
                                await _loadPatientDoctors(patientId!);
                                // Reload patients list in PatientController to update the patient data
                                await _patientController.loadPatients();
                              }
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          'تحويل',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    );
                  } else {
                    // For doctor: show dynamic button based on selected tab
                    final tabIndex = _tabController.index;

                    // التحقق من نوع العلاج - إخفاء زر حجز الموعد إذا كان "زراعة"
                    final isImplantTreatment =
                        patient != null &&
                        patient.treatmentHistory != null &&
                        patient.treatmentHistory!.isNotEmpty &&
                        patient.treatmentHistory!.first == 'زراعة';

                    // إخفاء الزر إذا كان tab المواعيد ونوع العلاج "زراعة"
                    if (tabIndex == 1 && isImplantTreatment) {
                      return SizedBox.shrink();
                    }

                    return Container(
                      width: double.infinity,
                      height: 56.h,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          _onButtonPressed(tabIndex);
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
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    );
                  }
                }),
              ),
            ],
          );
          }),
        ),
      ),
    );
  }

  Widget _buildRecordsTab() {
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
          .where((record) => record.patientId == patientId)
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
              onLongPress: () {
                _showRecordOptionsDialog(context, record);
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 16.h),
                // ✅ المسافة بين الكونتينر ومحتواه
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: kPatientFileShadow,
                  border: Border.all(
                    color: const Color(0xFF649FCC),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // النص (الملاحظات/التشخيص)
                    if (record.notes != null && record.notes!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 2.h), // vertical 2
                        child: Text(
                          record.notes!,
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    // الصور
                    if (record.images != null && record.images!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 2.h), // vertical 2
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 60.w, // image width
                                mainAxisExtent: 70.h, // image height
                                crossAxisSpacing: 8.w,
                                mainAxisSpacing: 8.h,
                              ),
                          itemCount: record.images!.length,
                          itemBuilder: (context, imgIndex) {
                            final imageUrl = ImageUtils.convertToValidUrl(
                              record.images![imgIndex],
                            );
                            return GestureDetector(
                              onTap: () {
                                if (imageUrl != null &&
                                    ImageUtils.isValidImageUrl(imageUrl)) {
                                  _showRecordImageDialog(context, imageUrl);
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child:
                                    imageUrl != null &&
                                        ImageUtils.isValidImageUrl(imageUrl)
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        width: 60.w,
                                        height: 70.h,
                                        progressIndicatorBuilder:
                                            (
                                              context,
                                              url,
                                              progress,
                                            ) => Container(
                                              color: AppColors.divider,
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  value: progress.progress,
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(AppColors.primary),
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
                      ),
                    // التاريخ
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
                          style: GoogleFonts.cairo(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF505558),
                          ),
                          textAlign: TextAlign.right,
                        ),
                        SizedBox(width: 10.w),
                        IconButton(
                          onPressed: () =>
                              _showDeleteRecordConfirmDialog(context, record),
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20.sp,
                          ),
                          tooltip: 'حذف السجل',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
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
  Widget _buildAppointmentsTab() {
    // التحقق من نوع العلاج
    final patient = patientId != null
        ? _patientController.getPatientById(patientId!)
        : null;

    final isImplantTreatment =
        patient != null &&
        patient.treatmentHistory != null &&
        patient.treatmentHistory!.isNotEmpty &&
        patient.treatmentHistory!.first == 'زراعة';

    // إذا كان نوع العلاج زراعة، نعرض المراحل
    if (isImplantTreatment) {
      return _buildImplantStagesView();
    }

    // في وضع العرض، نستخدم Obx فقط عند الحاجة
    final appointments = _appointmentController.appointments
        .where((apt) => apt.patientId == patientId)
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

    return Obx(() {
      final updatedAppointments = _appointmentController.appointments
          .where((apt) => apt.patientId == patientId)
          .toList();

      if (updatedAppointments.isEmpty) {
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
      final patient = patientId != null
          ? _patientController.getPatientById(patientId!)
          : null;

      // Sort appointments: upcoming first, then past
      final sortedAppointments = List<AppointmentModel>.from(
        updatedAppointments,
      );
      sortedAppointments.sort((a, b) {
        // تحديد المواعيد القادمة: فقط المواعيد بحالة scheduled/pending
        final aStatus = a.status.toLowerCase();
        final bStatus = b.status.toLowerCase();
        final aIsUpcoming =
            (aStatus == 'scheduled' || aStatus == 'pending') &&
            (a.date.isAfter(now) ||
                a.date.isAfter(now.subtract(Duration(hours: 1))));
        final bIsUpcoming =
            (bStatus == 'scheduled' || bStatus == 'pending') &&
            (b.date.isAfter(now) ||
                b.date.isAfter(now.subtract(Duration(hours: 1))));
        if (aIsUpcoming != bIsUpcoming) {
          return aIsUpcoming ? -1 : 1; // Upcoming first
        }
        return a.date.compareTo(b.date) *
            (aIsUpcoming
                ? 1
                : -1); // Upcoming: oldest first, Past: newest first
      });

      // Auto-scroll to the tapped appointment card (no new UI).
      if (!_didAutoScrollToSelected && _selectedAppointmentId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final key = _appointmentItemKeys[_selectedAppointmentId!];
          final ctx = key?.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.1,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
            _didAutoScrollToSelected = true;
          }
        });
      }

      return Container(
        color: const Color(0xFFF4FEFF),
        child: ListView.builder(
          padding: EdgeInsets.all(24.w),
          itemCount: sortedAppointments.length,
          itemBuilder: (context, index) {
            final appointment = sortedAppointments[index];
            final appointmentStatus = appointment.status.toLowerCase();

            // تحديد إذا كان الموعد قادم أم سابق بناءً على الحالة
            final isUpcoming =
                appointmentStatus == 'scheduled' &&
                (appointment.date.isAfter(now) ||
                    appointment.date.isAfter(now.subtract(Duration(hours: 1))));

            final isSelected = selectedAppointmentIds.contains(appointment.id);

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

            final itemKey = _appointmentItemKeys.putIfAbsent(
              appointment.id,
              () => GlobalKey(),
            );

            return KeyedSubtree(
              key: itemKey,
              child: GestureDetector(
                onLongPress: () {
                  setState(() {
                    isSelectionMode = true;
                    if (!selectedAppointmentIds.contains(appointment.id)) {
                      selectedAppointmentIds.add(appointment.id);
                    }
                  });
                },
                child: Container(
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSelectionMode && isSelected
                        ? AppColors.primary
                        : (isCompleted
                              ? AppColors
                                    .success // أخضر للمكتمل
                              : (isCancelled
                                    ? AppColors
                                          .error // أحمر للملغي
                                    : AppColors
                                          .warning)), // برتقالي لقيد الانتظار
                    width: isSelectionMode && isSelected
                        ? 2
                        : (isPending || isCompleted || isCancelled ? 2 : 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Checkbox on the left - يعرض الحالة بناءً على status
                        GestureDetector(
                          onTap: isSelectionMode
                              ? () {
                                  setState(() {
                                    if (isSelected) {
                                      selectedAppointmentIds.remove(
                                        appointment.id,
                                      );
                                      if (selectedAppointmentIds.isEmpty) {
                                        isSelectionMode = false;
                                      }
                                    } else {
                                      selectedAppointmentIds.add(
                                        appointment.id,
                                      );
                                    }
                                  });
                                }
                              : null,
                          child: Container(
                            width: 24.w,
                            height: 24.w,
                            margin: EdgeInsets.only(top: 2.h, left: 8.w),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelectionMode && isSelected
                                    ? AppColors.primary
                                    : (isCompleted
                                          ? AppColors.primary
                                          : (isCancelled
                                                ? AppColors.error
                                                : AppColors.divider)),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4.r),
                              color: isSelectionMode && isSelected
                                  ? AppColors.primary
                                  : (isCompleted
                                        ? AppColors.primary
                                        : (isCancelled
                                              ? AppColors.error
                                              : Colors.transparent)),
                            ),
                            child: isSelectionMode && isSelected
                                ? Icon(
                                    Icons.check,
                                    color: AppColors.white,
                                    size: 14.sp,
                                  )
                                : (isCompleted
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
                                            : null)),
                          ),
                        ),
                        // Title
                        Text(
                          isPending && isUpcoming
                              ? 'موعد مريضك "${patient?.name ?? ''}" القادم هو'
                              : 'موعد مريضك "${patient?.name ?? ''}" السابق هو',
                          style: TextStyle(
                          
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    SizedBox(width: 2.w),

                    // Content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(height: 8.h),
                        // Date with Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // التاريخ في أقصى اليمين
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: const Color.fromARGB(255, 54, 147, 190),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                SizedBox(width: 6.w),
                                Icon(
                                  Icons.calendar_today,
                                  size: 14.sp,
                                  color: const Color.fromARGB(255, 54, 147, 190),
                                ),
                              ],
                            ),

                            Spacer(),
                            // Status Badge - في أقصى اليسار
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? AppColors.success.withOpacity(0.1)
                                    : (isCancelled
                                          ? AppColors.error.withOpacity(0.1)
                                          : AppColors.warning.withOpacity(
                                              0.1,
                                            )), // برتقالي لقيد الانتظار
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: isCompleted
                                      ? AppColors.success
                                      : (isCancelled
                                            ? AppColors.error
                                            : AppColors
                                                  .warning), // برتقالي لقيد الانتظار
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
                                      ? AppColors.success
                                      : (isCancelled
                                            ? AppColors.error
                                            : AppColors
                                                  .warning), // برتقالي لقيد الانتظار
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        // Time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: isPending && isUpcoming
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.divider.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'في تمام الساعة $formattedTime',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: isPending && isUpcoming
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Notes (if exists) with Change Status button beside it
                        if (appointment.notes != null &&
                            appointment.notes!.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Container للملاحظة
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

                              if (!isSelectionMode) SizedBox(width: 8.w),

                              // زر تغيير الحالة (للطبيب فقط) - بجانب الكونتينر
                              if (!isSelectionMode)
                                Padding(
                                  padding: EdgeInsets.only(top: 4.h),
                                  child: TextButton.icon(
                                    onPressed: () {
                                      _showChangeStatusDialog(
                                        context,
                                        appointment,
                                        patientId!,
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
                            ],
                          ),
                        ] else if (!isSelectionMode) ...[
                          // إذا لم تكن هناك ملاحظة، نعرض زر تغيير الحالة فقط
                          SizedBox(height: 12.h),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                _showChangeStatusDialog(
                                  context,
                                  appointment,
                                  patientId!,
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
                        // عرض الصور: استخدم imagePaths إذا كانت متوفرة، وإلا استخدم imagePath
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
                                              _showAppointmentImageDialog(
                                                context,
                                                imageUrl ?? imagesToShow[index],
                                              );
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
                ),
              ),
            );
          },
        ),
      );
    });
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

  Widget _buildImplantStagesView() {
    final userType = _authController.currentUser.value?.userType;
    final isDoctor = userType != null && userType.toLowerCase() == 'doctor';

    // الحصول على ImplantStageController (إنشاءه إذا لم يكن موجوداً)
    final implantStageController = Get.put(ImplantStageController());

    // تحميل المراحل إذا لم تكن محملة بعد
    if (patientId != null &&
        !implantStageController.isLoading.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        implantStageController.ensureStagesLoaded(patientId!);
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
      final pid = patientId ?? '';
      final patientStages =
          pid.isEmpty ? <ImplantStageModel>[] : implantStageController.stagesForPatient(pid);

      // Auto-scroll to the tapped implant-stage "appointment" (no new UI).
      if (!_didAutoScrollToSelectedImplantStage &&
          _selectedAppointmentId != null &&
          patientStages.any((s) => s.id == _selectedAppointmentId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _implantStageItemKeys[_selectedAppointmentId!]?.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.1,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
            _didAutoScrollToSelectedImplantStage = true;
          }
        });
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
                if (isDoctor && pid.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await implantStageController.initializeStages(pid);
                        // After initialization, ensure we have fresh data
                        await implantStageController.loadStages(pid);
                      } catch (_) {}
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('تهيئة مراحل الزراعة'),
                  ),
                ],
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
                patientId: patientId ?? '',
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
                  patientId: patientId ?? '',
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

            final stageKey = _implantStageItemKeys.putIfAbsent(
              existingStage.id,
              () => GlobalKey(),
            );

            return KeyedSubtree(
              key: stageKey,
              child: _buildImplantStageItem(
                stage: existingStage,
                isLast: isLast,
                hasNextCompleted: hasNextCompleted,
                isDoctor: isDoctor,
                getDayName: getDayName,
                formatTime: formatTime,
                showAppointmentInfo:
                    existingStage.isCompleted ||
                    isNextToLastCompleted ||
                    (isFirstStage && stageExists),
              ),
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
    required bool isDoctor,
    required String Function(DateTime) getDayName,
    required String Function(DateTime) formatTime,
    required bool showAppointmentInfo,
  }) {
    final dateFormat = DateFormat('d/M/yyyy');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content - قابل للضغط للطبيب فقط لتعديل التاريخ (على اليمين)
        Expanded(
          child: GestureDetector(
            onTap: isDoctor
                ? () {
                    _showEditImplantStageDateDialog(
                      context,
                      patientId!,
                      stage.stageName,
                      stage.scheduledAt,
                    );
                  }
                : null,
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
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : AppColors.textPrimary,
                      decoration: stage.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: stage.isCompleted
                          ? AppColors.primary.withValues(alpha: 0.7)
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
              onTap: isDoctor
                  ? () async {
                      final implantStageController = Get.put(
                        ImplantStageController(),
                      );

                      bool success;
                      if (stage.isCompleted) {
                        // إلغاء الإكمال
                        success = await implantStageController.uncompleteStage(
                          patientId!,
                          stage.stageName,
                        );
                      } else {
                        // إكمال المرحلة
                        success = await implantStageController.completeStage(
                          patientId!,
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
                        
                        // إذا لم يكن الخطأ متعلق بالشبكة، نعرض Snackbar
                        // (إذا كان متعلق بالشبكة، Controller يعرض الدايلوج بالفعل)
                        if (!NetworkUtils.isNetworkError(errorMsg)) {
                          Get.snackbar(
                            'خطأ',
                            errorMsg,
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: AppColors.error,
                            colorText: AppColors.white,
                            duration: Duration(seconds: 4),
                          );
                        }
                      }
                    }
                  : null,
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
                    : AppColors.primary.withValues(alpha: 0.3),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGalleryTab() {
    return Obx(() {
      if (_galleryController.isLoading.value) {
        return Container(
          color: AppColors.white,
          padding: EdgeInsets.all(16.w),
          child: Skeletonizer(
            enabled: true,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.w,
                mainAxisSpacing: 8.h,
                childAspectRatio: 1.0,
              ),
              itemCount: 6, // Show 6 skeleton items
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Container(color: AppColors.divider),
                );
              },
            ),
          ),
        );
      }

      if (_galleryController.galleryImages.isEmpty) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
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
            crossAxisCount: 3,
            crossAxisSpacing: 8.w,
            mainAxisSpacing: 8.h,
            childAspectRatio: 1.0,
          ),
          itemCount: _galleryController.galleryImages.length,
          itemBuilder: (context, index) {
            final image = _galleryController.galleryImages[index];
            return GestureDetector(
              onTap: () {
                _showImageDetailsDialog(context, image);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Builder(
                  builder: (context) {
                    final imageUrl = ImageUtils.convertToValidUrl(
                      image.imagePath,
                    );
                    if (imageUrl != null &&
                        ImageUtils.isValidImageUrl(imageUrl)) {
                      return CachedNetworkImage(
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
                      );
                    } else {
                      return Container(
                        color: AppColors.divider,
                        child: Icon(
                          Icons.broken_image,
                          color: AppColors.textHint,
                          size: 30.sp,
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      );
    });
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

  void _onButtonPressed(int tabIndex) {
    switch (tabIndex) {
      case 0: // السجلات (Records)
        if (patientId != null) {
          _showAddRecordDialog(context);
        }
        break;
      case 1: // المواعيد (Appointments)
        if (patientId != null) {
          _showBookAppointmentDialog(context);
        }
        break;
      case 2: // المعرض (Gallery)
        if (patientId != null) {
          _showAddImageDialog(context);
        }
        break;
    }
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

  void _showBookAppointmentDialog(BuildContext context) {
    int currentStep = 1;
    DateTime? selectedDate;
    String? selectedTime;
    List<File> selectedImages = [];
    final TextEditingController notesController = TextEditingController();

    // Get patient and doctor ID
    final patient = patientId != null
        ? _patientController.getPatientById(patientId!)
        : null;
    final doctorIds = patient?.doctorIds ?? [];
    final doctorId = doctorIds.isNotEmpty ? doctorIds.first : null;

    // Working hours controller
    final workingHoursController = Get.put(WorkingHoursController());

    // Available slots (will be loaded from API)
    List<String> availableSlots = [];
    bool isLoadingSlots = false;

    // Load working hours when dialog opens
    if (doctorId != null) {
      workingHoursController.loadWorkingHours(doctorId: doctorId);
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
                ),
                width: double.infinity,
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
                              final userType =
                                  (_authController.currentUser.value?.userType ??
                                          '')
                                      .toLowerCase();
                              final isReceptionOrAdmin =
                                  userType == 'receptionist' ||
                                      userType == 'admin';
                              final slots = isReceptionOrAdmin
                                  ? await _workingHoursService
                                      .getAvailableSlotsForReception(
                                        doctorId,
                                        dateStr,
                                      )
                                  : await _workingHoursService.getAvailableSlots(
                                      doctorId,
                                      dateStr,
                                    );
                              setDialogState(() {
                                availableSlots = slots;
                                isLoadingSlots = false;
                              });
                            } catch (e) {
                              print(
                                '❌ [PatientDetailsScreen] Error loading available slots: $e',
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
                                patientId: patientId!,
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
                                  .loadPatientAppointmentsById(patientId!);
                            } catch (e) {
                              print(
                                '❌ [PatientDetailsScreen] Error adding appointment: $e',
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
        // If today is Sunday (weekday % 7 == 0), weekStart = now
        // Otherwise, subtract days to get to Sunday
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
                final List<XFile>? images = await _imagePicker.pickMultiImage(
                  imageQuality: 85,
                );

                if (images != null && images.isNotEmpty) {
                  final List<File> newImages = images
                      .map((xfile) => File(xfile.path))
                      .toList();
                  onImagesSelected([...selectedImages, ...newImages]);
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

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('تأكيد الحذف'),
          content: Text(
            'هل أنت متأكد من حذف ${selectedAppointmentIds.length} موعد محدد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteSelectedAppointments();
              },
              child: Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelectedAppointments() async {
    if (patientId == null || selectedAppointmentIds.isEmpty) return;

    final idsToDelete = List<String>.from(selectedAppointmentIds);
    int successCount = 0;
    int failCount = 0;

    for (final appointmentId in idsToDelete) {
      try {
        await _appointmentController.deleteAppointment(
          patientId!,
          appointmentId,
        );
        successCount++;
      } catch (e) {
        failCount++;
        print(
          '❌ [PatientDetailsScreen] Error deleting appointment $appointmentId: $e',
        );
      }
    }

    setState(() {
      selectedAppointmentIds.clear();
      isSelectionMode = false;
    });

    if (failCount == 0) {
      Get.snackbar(
        'نجح',
        'تم حذف $successCount موعد بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primary,
        colorText: AppColors.white,
      );
    } else {
      Get.snackbar(
        'تحذير',
        'تم حذف $successCount موعد، فشل حذف $failCount موعد',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: AppColors.white,
      );
    }
  }

  void _showAddImageDialog(BuildContext context) {
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
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
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
                            final XFile? image = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );

                            if (image != null) {
                              setDialogState(() {
                                selectedImage = File(image.path);
                              });
                            }
                          } catch (e) {
                            print(
                              '❌ [PatientDetailsScreen] Error picking image: $e',
                            );
                            if (context.mounted) {
                              Get.snackbar(
                                'خطأ',
                                'فشل اختيار الصورة. تأكد من إعطاء الأذونات المطلوبة.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: AppColors.white,
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
                                            patientId!,
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
                                            colorText: AppColors.white,
                                          );
                                        } else {
                                          Get.snackbar(
                                            'خطأ',
                                            _galleryController
                                                .errorMessage
                                                .value,
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.red,
                                            colorText: AppColors.white,
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
                                                  AppColors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          'اضافة',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.white,
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
    ).then((_) {
      // Dispose controller after dialog is fully closed
      // Use Future.delayed to ensure the widget tree is fully unmounted
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          noteController.dispose();
        } catch (e) {
          // Controller already disposed or widget tree still using it
        }
      });
    });
  }

  void _showAppointmentImageDialog(BuildContext context, String imageUrl) {
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
                // Save button
                Positioned(
                  top: 40.h,
                  left: 20.w,
                  child: GestureDetector(
                    onTap: () => _saveImage(context, imageUrl),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.download,
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

  void _showImageDetailsDialog(BuildContext context, dynamic galleryImage) {
    // Parse date
    String formattedDate = '';
    try {
      final dateTime = DateTime.parse(galleryImage.createdAt);
      formattedDate = DateFormat('yyyy-MM-dd HH:mm', 'ar').format(dateTime);
    } catch (e) {
      formattedDate = galleryImage.createdAt;
    }

    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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

                    // Image with zoom
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        final imageUrl = ImageUtils.convertToValidUrl(
                          galleryImage.imagePath,
                        );
                        if (imageUrl != null &&
                            ImageUtils.isValidImageUrl(imageUrl)) {
                          _showAppointmentImageDialog(context, imageUrl);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Builder(
                          builder: (context) {
                            final imageUrl = ImageUtils.convertToValidUrl(
                              galleryImage.imagePath,
                            );
                            if (imageUrl != null &&
                                ImageUtils.isValidImageUrl(imageUrl)) {
                              return CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: 300.h,
                                progressIndicatorBuilder:
                                    (context, url, progress) => Container(
                                      width: double.infinity,
                                      height: 300.h,
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
                                errorWidget: (context, url, error) => Container(
                                  width: double.infinity,
                                  height: 300.h,
                                  color: AppColors.divider,
                                  child: Icon(
                                    Icons.broken_image,
                                    color: AppColors.textHint,
                                    size: 50.sp,
                                  ),
                                ),
                              );
                            } else {
                              return Container(
                                width: double.infinity,
                                height: 300.h,
                                color: AppColors.divider,
                                child: Icon(
                                  Icons.broken_image,
                                  color: AppColors.textHint,
                                  size: 50.sp,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Note (if exists)
                    if (galleryImage.note != null &&
                        galleryImage.note!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: AppColors.divider.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
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
                              textAlign: TextAlign.right,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              galleryImage.note!,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Date
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            Icons.calendar_today,
                            size: 18.sp,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Delete button
                    GestureDetector(
                      onTap: isDeleting
                          ? null
                          : () async {
                              // Show confirmation dialog
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('تأكيد الحذف'),
                                  content: Text(
                                    'هل أنت متأكد من حذف هذه الصورة؟',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text('إلغاء'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(
                                        'حذف',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && patientId != null) {
                                setDialogState(() {
                                  isDeleting = true;
                                });

                                final success = await _galleryController
                                    .deleteImage(patientId!, galleryImage.id);

                                if (context.mounted) {
                                  if (success) {
                                    Navigator.of(context).pop(); // Close dialog
                                    Get.snackbar(
                                      'نجح',
                                      'تم حذف الصورة بنجاح',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: AppColors.primary,
                                      colorText: AppColors.white,
                                    );
                                  } else {
                                    setDialogState(() {
                                      isDeleting = false;
                                    });
                                    Get.snackbar(
                                      'خطأ',
                                      _galleryController
                                              .errorMessage
                                              .value
                                              .isNotEmpty
                                          ? _galleryController
                                                .errorMessage
                                                .value
                                          : 'فشل حذف الصورة',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.red,
                                      colorText: AppColors.white,
                                    );
                                  }
                                }
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: isDeleting ? AppColors.divider : Colors.red,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: isDeleting
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: AppColors.white,
                                      size: 20.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'حذف الصورة',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ],
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
    );
  }

  Widget _buildDoctorImage(DoctorModel doctor, String doctorInitials) {
    // Check if imageUrl is valid and convert to valid URL
    final imageUrl = doctor.imageUrl;
    final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);

    if (validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl)) {
      return CachedNetworkImage(
        imageUrl: validImageUrl,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              bottomLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
              bottomRight: Radius.circular(16.r),
            ),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            _buildDefaultDoctorImage(doctorInitials),
        memCacheWidth: 160,
        memCacheHeight: 160,
      );
    } else {
      return _buildDefaultDoctorImage(doctorInitials);
    }
  }

  Widget _buildDefaultDoctorImage(String doctorInitials) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          bottomLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
          bottomRight: Radius.circular(16.r),
        ),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Center(
        child: Text(
          doctorInitials,
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _saveImage(BuildContext context, String imageUrl) async {
    try {
      // إظهار رسالة جاري الحفظ
      Get.rawSnackbar(
        messageText: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'جاري الحفظ...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
        animationDuration: const Duration(milliseconds: 300),
      );

      var response = await Dio().get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      
      await Gal.putImageBytes(
        Uint8List.fromList(response.data),
        name: "farah_app_${DateTime.now().millisecondsSinceEpoch}",
      );

      // إظهار رسالة النجاح
      Get.rawSnackbar(
        messageText: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'تم الحفظ في المعرض',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        animationDuration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      // إظهار رسالة الخطأ
      Get.rawSnackbar(
        messageText: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'فشل الحفظ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        animationDuration: const Duration(milliseconds: 300),
      );
    }
  }

  void _showQrCodeDialog(BuildContext context, String patientId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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

  void _showSuccessDialog(BuildContext context, String message) {
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
                // Success Icon
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 40.sp,
                  ),
                ),
                SizedBox(height: 24.h),
                // Title
                Text(
                  'نجح',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                // Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                // OK Button
                GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        'حسناً',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
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
  }

  void _showEditImplantStageDateDialog(
    BuildContext context,
    String patientId,
    String stageName,
    DateTime currentDate,
  ) {
    DateTime? selectedDate = currentDate;
    String? selectedTime;

    // تحويل الوقت الحالي إلى تنسيق 12 ساعة
    final hour = currentDate.hour;
    final minute = currentDate.minute;
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    selectedTime =
        '$displayHour:${minute.toString().padLeft(2, '0')} ${isPM ? 'م' : 'ص'}';

    // Get patient and doctor ID
    final patient = _patientController.getPatientById(patientId);
    final doctorIds = patient?.doctorIds ?? [];
    final doctorId = doctorIds.isNotEmpty ? doctorIds.first : null;

    // Working hours controller
    final workingHoursController = Get.put(WorkingHoursController());

    // Available slots
    List<String> availableSlots = [];
    bool isLoadingSlots = false;

    // Load working hours when dialog opens
    if (doctorId != null) {
      workingHoursController.loadWorkingHours(doctorId: doctorId);
    }

    final implantStageController = Get.put(ImplantStageController());

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
                ),
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: _buildStep1DateTimeSelection(
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
                        final userType =
                            (_authController.currentUser.value?.userType ?? '')
                                .toLowerCase();
                        final isReceptionOrAdmin =
                            userType == 'receptionist' || userType == 'admin';
                        final slots = isReceptionOrAdmin
                            ? await _workingHoursService
                                .getAvailableSlotsForReception(
                                  doctorId,
                                  dateStr,
                                )
                            : await _workingHoursService.getAvailableSlots(
                                doctorId,
                                dateStr,
                              );
                        setDialogState(() {
                          availableSlots = slots;
                          isLoadingSlots = false;
                        });
                      } catch (e) {
                        print(
                          '❌ [PatientDetailsScreen] Error loading available slots: $e',
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
                  () async {
                    if (selectedDate != null && selectedTime != null) {
                      // Parse time from 12-hour format
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

                      // Update stage date
                      final success = await implantStageController
                          .updateStageDate(
                            patientId,
                            stageName,
                            selectedDate!,
                            '$hour:${minute.toString().padLeft(2, '0')}',
                          );

                      if (success) {
                        Navigator.of(context).pop();
                        // إعادة تحميل المراحل بعد التعديل
                        implantStageController.loadStages(patientId);
                        // إظهار دايلوج النجاح بعد إغلاق الدايلوج الحالي
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (context.mounted) {
                            _showSuccessDialog(
                              context,
                              'تم تحديث تاريخ المرحلة بنجاح',
                            );
                          }
                        });
                      } else {
                        Get.snackbar(
                          'خطأ',
                          implantStageController.errorMessage.value.isNotEmpty
                              ? implantStageController.errorMessage.value
                              : 'فشل تحديث التاريخ',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: AppColors.white,
                        );
                      }
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTreatmentTypeDialog(BuildContext context, dynamic patient) {
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
    List<String>? treatmentHistory;
    if (patient is PatientModel) {
      treatmentHistory = patient.treatmentHistory;
    } else if (patient != null) {
      try {
        final th = patient.treatmentHistory;
        if (th != null && th is List) {
          treatmentHistory = th.map((e) => e.toString()).toList();
        }
      } catch (e) {
        print('⚠️ [PatientDetailsScreen] Error accessing treatmentHistory: $e');
      }
    }

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

    // التحقق من وجود "زراعة" في نوع العلاج الحالي
    bool hasImplant = selectedTreatments.contains('زراعة');
    if (!hasImplant && treatmentHistory != null) {
      for (final t in treatmentHistory) {
        if (t.contains('زراعة')) {
          hasImplant = true;
          break;
        }
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
                padding: EdgeInsets.all(12.w),
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
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h),

                    // Treatment options (2-column grid, RTL)
                    Directionality(
                      textDirection: ui.TextDirection.rtl,
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: treatmentTypes.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16.w,
                          mainAxisSpacing: 12.h,
                          childAspectRatio: 2.9,
                        ),
                        itemBuilder: (context, index) {
                          final treatment = treatmentTypes[index];
                          final isSelected =
                              selectedTreatments.contains(treatment);
                          final isImplantSelected =
                              selectedTreatments.contains('زراعة');
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
                    ),

                    // رسالة توضيحية عند اختيار "زراعة" في selectedTreatments
                    Builder(
                      builder: (context) {
                        // إعادة حساب isImplantSelected للرسالة (من selectedTreatments فقط)
                        final currentIsImplantSelected = selectedTreatments
                            .contains('زراعة');
                        if (currentIsImplantSelected) {
                          return Column(
                            children: [
                              SizedBox(height: 16.h),
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.primary,
                                      size: 20.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        'نوع العلاج "زراعة" لا يمكن اختياره مع أنواع أخرى',
                                        style: TextStyle(
                                          fontSize: 12.sp,
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
                        return SizedBox.shrink();
                      },
                    ),

                    SizedBox(height: 32.h),

                    // Buttons
                    Row(
                      children: [
                        // Back button (left)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
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

                              final patientController =
                                  Get.find<PatientController>();

                              try {
                                // الحصول على معرف المريض بشكل آمن
                                String? actualPatientId;
                                if (patient is PatientModel) {
                                  actualPatientId = patient.id;
                                } else if (patient != null &&
                                    patient.id != null) {
                                  actualPatientId = patient.id.toString();
                                }

                                if (actualPatientId == null) {
                                  Get.snackbar('خطأ', 'معرف المريض غير صحيح');
                                  return;
                                }

                                await patientController.setTreatmentType(
                                  patientId: actualPatientId,
                                  treatmentType: treatmentType,
                                );

                                // تحديث بيانات المريض في الصفحة
                                await patientController.loadPatients();

                                // تحديث بيانات المريض الحالي في الـ controller
                                final updatedPatient = patientController
                                    .getPatientById(actualPatientId);
                                if (updatedPatient != null) {
                                  _patientController.selectedPatient.value =
                                      updatedPatient;
                                }

                                // إذا كان النوع "زراعة"، تحميل المراحل
                                if (treatmentType == 'زراعة' &&
                                    patientId != null) {
                                  final implantStageController = Get.put(
                                    ImplantStageController(),
                                  );
                                  await implantStageController.loadStages(
                                    patientId!,
                                  );
                                }

                                Navigator.of(context).pop();
                                Get.snackbar(
                                  'نجح',
                                  'تم تحديث نوع العلاج بنجاح',
                                );
                                // إعادة بناء الصفحة لتحديث العرض
                                setState(() {});
                              } catch (e) {
                                Get.snackbar(
                                  'خطأ',
                                  'حدث خطأ أثناء تحديث نوع العلاج',
                                );
                              }
                            },
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Center(
                                child: Text(
                                  'اضافة',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
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
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isDisabled
                ? AppColors.divider.withValues(alpha: 0.3)
                : AppColors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Radio circle
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDisabled
                              ? AppColors.divider
                              : AppColors.textSecondary),
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 14.sp, color: AppColors.white)
                    : null,
              ),
              SizedBox(width: 12.w),
              // Treatment text
              Expanded(
                child: Text(
                  treatment,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDisabled
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // عرض صورة السجل
  void _showRecordImageDialog(BuildContext context, String imageUrl) {
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
                // Save button
                Positioned(
                  top: 40.h,
                  left: 20.w,
                  child: GestureDetector(
                    onTap: () => _saveImage(context, imageUrl),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.download,
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

  // عرض خيارات السجل (تعديل/حذف)
  void _showRecordOptionsDialog(
    BuildContext context,
    MedicalRecordModel record,
  ) {
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
                Text(
                  'خيارات السجل',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                // زر التعديل
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showEditRecordDialog(context, record);
                  },
                  icon: Icon(Icons.edit, color: AppColors.primary),
                  label: Text(
                    'تعديل',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // زر الحذف
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDeleteRecordConfirmDialog(context, record);
                  },
                  icon: Icon(Icons.delete, color: Colors.red),
                  label: Text(
                    'حذف',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // زر الإلغاء
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.textSecondary,
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

  // حذف السجل مع تأكيد
  void _showDeleteRecordConfirmDialog(
    BuildContext context,
    MedicalRecordModel record,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'تأكيد الحذف',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'هل أنت متأكد من حذف هذا السجل؟',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (patientId != null) {
                  try {
                    await _medicalRecordController.deleteRecord(
                      patientId: patientId!,
                      recordId: record.id,
                    );
                  } catch (e) {
                    // Error already shown in controller
                  }
                }
              },
              child: Text(
                'حذف',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // إضافة سجل جديد
  void _showAddRecordDialog(BuildContext context) {
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
                            final List<XFile> images = await _imagePicker
                                .pickMultiImage(imageQuality: 85);
                            if (images.isNotEmpty) {
                              setDialogState(() {
                                selectedImages.addAll(
                                  images.map((img) => File(img.path)),
                                );
                              });
                            }
                          } catch (e) {
                            print(
                              '❌ [PatientDetailsScreen] Error picking images: $e',
                            );
                            if (context.mounted) {
                              Get.snackbar(
                                'خطأ',
                                'فشل اختيار الصور. تأكد من إعطاء الأذونات المطلوبة.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: AppColors.white,
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
                                if (patientId != null) {
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
                                      patientId: patientId!,
                                      note: noteText.isEmpty ? null : noteText,
                                      imageFiles: imagesToSend,
                                    );
                                  } catch (e) {
                                    // Error already shown in controller
                                  }
                                } else {
                                  Navigator.of(context).pop();
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
                                  color: AppColors.white,
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

  // تعديل سجل موجود
  void _showEditRecordDialog(BuildContext context, MedicalRecordModel record) {
    List<File> newImages = [];
    List<String> existingImages = record.images ?? [];
    Set<int> deletedImageIndices = {};
    final TextEditingController noteController = TextEditingController(
      text: record.notes ?? '',
    );

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
                    children: [
                      // Title
                      Text(
                        'تعديل سجل',
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
                      // Existing images
                      if (existingImages.isNotEmpty) ...[
                        Text(
                          'الصور الحالية:',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          height: 100.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: existingImages.length,
                            itemBuilder: (context, index) {
                              if (deletedImageIndices.contains(index)) {
                                return SizedBox.shrink();
                              }
                              final imageUrl = ImageUtils.convertToValidUrl(
                                existingImages[index],
                              );
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
                                      child:
                                          imageUrl != null &&
                                              ImageUtils.isValidImageUrl(
                                                imageUrl,
                                              )
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              width: 100.w,
                                              height: 100.h,
                                              progressIndicatorBuilder:
                                                  (
                                                    context,
                                                    url,
                                                    progress,
                                                  ) => Container(
                                                    color: AppColors.divider,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            value: progress
                                                                .progress,
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (
                                                    context,
                                                    url,
                                                    error,
                                                  ) => Container(
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
                                    Positioned(
                                      top: 4.h,
                                      left: 4.w,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            deletedImageIndices.add(index);
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
                        SizedBox(height: 16.h),
                      ],
                      // Add new images button
                      GestureDetector(
                        onTap: () async {
                          try {
                            final List<XFile> images = await _imagePicker
                                .pickMultiImage(imageQuality: 85);
                            if (images.isNotEmpty) {
                              setDialogState(() {
                                newImages.addAll(
                                  images.map((img) => File(img.path)),
                                );
                              });
                            }
                          } catch (e) {
                            print(
                              '❌ [PatientDetailsScreen] Error picking images: $e',
                            );
                            if (context.mounted) {
                              Get.snackbar(
                                'خطأ',
                                'فشل اختيار الصور. تأكد من إعطاء الأذونات المطلوبة.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: AppColors.white,
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
                                'إضافة صور جديدة',
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
                      // New images preview
                      if (newImages.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Container(
                          height: 100.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: newImages.length,
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
                                        newImages[index],
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
                                            newImages.removeAt(index);
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
                                if (patientId != null) {
                                  // حفظ القيم قبل إغلاق الـ dialog
                                  final noteText = noteController.text.trim();
                                  // إذا كان هناك صور جديدة أو تم حذف صور، نرسل الصور الجديدة فقط
                                  // Backend سيستبدل جميع الصور بالصور الجديدة
                                  final imagesToSend =
                                      newImages.isEmpty &&
                                          deletedImageIndices.isEmpty
                                      ? null
                                      : List<File>.from(newImages);

                                  // إغلاق الـ dialog أولاً
                                  Navigator.of(context).pop();

                                  // انتظار قليلاً للتأكد من إغلاق الـ dialog
                                  await Future.delayed(
                                    const Duration(milliseconds: 100),
                                  );

                                  try {
                                    await _medicalRecordController.updateRecord(
                                      patientId: patientId!,
                                      recordId: record.id,
                                      note: noteText.isEmpty ? null : noteText,
                                      imageFiles: imagesToSend,
                                    );
                                  } catch (e) {
                                    // Error already shown in controller
                                  }
                                } else {
                                  Navigator.of(context).pop();
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
                                  color: AppColors.white,
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

  Future<void> _loadUnreadCount() async {
    if (patientId == null) return;
    try {
      final chatList = await _chatService.getChatList();
      final chat = chatList.firstWhere(
        (c) => c['patient_id']?.toString() == patientId,
        orElse: () => <String, dynamic>{},
      );
      final unreadCount = chat['unread_count'] as int? ?? 0;
      _unreadCount.value = unreadCount;
    } catch (e) {
      print('❌ Error loading unread count: $e');
      _unreadCount.value = 0;
    }
  }

  Future<void> _loadPatientDoctors(String patientId) async {
    _isLoadingDoctors.value = true;
    try {
      final doctors = await _patientService.getPatientDoctors(patientId);
      _patientDoctors.value = doctors;
    } catch (e) {
      // Error handling - can show snackbar if needed
      _patientDoctors.clear();
    } finally {
      _isLoadingDoctors.value = false;
    }
  }

  Widget _buildDoctorsSection(PatientModel patient) {
    return Obx(() {
      if (_isLoadingDoctors.value) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'الاطباء المعالجون',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            if (_patientDoctors.isEmpty)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'لم يتم تحويله الى طبيب حتى الان',
                      style: TextStyle(fontSize: 14.sp, color: AppColors.error),
                      textAlign: TextAlign.right,
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.info_outline,
                      color: AppColors.error,
                      size: 20.sp,
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _patientDoctors.length,
                itemBuilder: (context, index) {
                  final doctor = _patientDoctors[index];
                  final doctorName = doctor.name ?? 'طبيب';
                  final doctorInitials = doctorName.isNotEmpty
                      ? doctorName
                            .split(' ')
                            .map((n) => n.isNotEmpty ? n[0] : '')
                            .take(2)
                            .join()
                      : 'ط';

                  return Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.only(
                      left: 0.w,
                      top: 10.w,
                      bottom: 10.w,
                      right: 0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        // Doctor Image on the right (in RTL) - first element
                        Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16.r),
                            child: _buildDoctorImage(doctor, doctorInitials),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Doctor info column
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 0.w,
                              top: 12.w,
                              bottom: 12.w,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Doctor name at the top
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'د. $doctorName',
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                // Specialization
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'الاختصاص : طبيب اسنان',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.right,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      );
    });
  }
}
