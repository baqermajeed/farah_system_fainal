import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';
import 'dart:io' show Platform, File;
import 'package:intl/intl.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';
import 'package:frontend_desktop/core/widgets/custom_text_field.dart';
import 'package:frontend_desktop/core/widgets/gender_selector.dart';
import 'package:frontend_desktop/core/widgets/visit_type_selector.dart';
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
import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/models/appointment_model.dart';
import 'package:frontend_desktop/models/implant_stage_model.dart';
import 'package:frontend_desktop/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend_desktop/models/doctor_model.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/auth_service.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:frontend_desktop/main.dart' show availableCamerasList;
// دالة مساعدة لقراءة الصورة في isolate منفصل
Future<Uint8List> _readImageBytes(String imagePath) async {
  final file = File(imagePath);
  return await file.readAsBytes();
}

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

class ReceptionHomeScreen extends StatefulWidget {
  const ReceptionHomeScreen({super.key});

  @override
  State<ReceptionHomeScreen> createState() => _ReceptionHomeScreenState();
}

class _ReceptionHomeScreenState extends State<ReceptionHomeScreen>
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
  final PatientService _patientService = PatientService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _qrScanController = TextEditingController();
  final GlobalKey _qrPrintKey = GlobalKey();
  late TabController _tabController; // For patient file tabs
  late TabController _appointmentsTabController; // For appointments tabs
  final RxInt _currentTabIndex = 0.obs;
  final RxBool _showAppointments =
      false.obs; // Track if appointments should be shown
  
  // ⭐ ScrollController للـ Pagination
  final ScrollController _patientsScrollController = ScrollController();
  
  // For receptionist: patient doctors
  final RxList<DoctorModel> _patientDoctors = <DoctorModel>[].obs;
  final RxBool _isLoadingDoctors = false.obs;
  String? _currentPatientIdForDoctors; // Track which patient's doctors are loaded

  // Appointments filtering (custom tab: date range from / to)
  DateTime? _appointmentsRangeStart;
  DateTime? _appointmentsRangeEnd;

  Future<void> _refreshData() async {
    // ⭐ استخدام loadPatients مع pagination بدلاً من loadPatientsSmart
    await _patientController.loadPatients(isInitial: false, isRefresh: true);
    await _appointmentController.loadDoctorAppointments(
      isInitial: false,
      isRefresh: true,
    );

    final selected = _patientController.selectedPatient.value;
    if (selected != null) {
      await Future.wait([
        _medicalRecordController.loadPatientRecords(selected.id),
        _galleryController.loadGallery(selected.id),
        _appointmentController.loadPatientAppointmentsById(selected.id),
      ]);

      if (selected.treatmentHistory != null &&
          selected.treatmentHistory!.isNotEmpty &&
          selected.treatmentHistory!.last == 'زراعة') {
        final implantStageController = Get.put(ImplantStageController());
        await implantStageController.loadStages(selected.id);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _appointmentsTabController = TabController(length: 4, vsync: this);
    // Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _currentTabIndex.value = _tabController.index;
      }
    });

    // ⭐ إضافة listener للتمرير لتحميل المزيد من المرضى
    _patientsScrollController.addListener(_onPatientsScroll);
    
    // ⭐ إضافة listener للبحث - بنفس طريقة eversheen
    _searchController.addListener(_onSearchChanged);
    
    // Load patients and appointments on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ⭐ استخدام loadPatients مع pagination (25 مريض في كل مرة)
      _patientController.loadPatients(isInitial: true, isRefresh: false);
      _appointmentController.loadDoctorAppointments(isInitial: true, isRefresh: false);
    });

    // Listen to patient selection changes
    ever(_patientController.selectedPatient, (patient) {
      if (patient != null) {
        // التحقق من نوع المستخدم
        final currentUser = _authController.currentUser.value;
        final userType = currentUser?.userType.toLowerCase();
        
        if (userType == 'receptionist') {
          // موظف الاستقبال:
          // - تحميل أطباء المريض للقسم الجانبي
          // - تحميل صور المعرض الخاصة به لهذا المريض
          if (_currentPatientIdForDoctors != patient.id) {
            _patientDoctors.clear();
            _currentPatientIdForDoctors = patient.id;
            _loadPatientDoctors(patient.id);
          }
          _galleryController.loadGallery(patient.id);
          return;
        }
        
        // للطبيب أو أدوار أخرى: تحميل السجلات والمعرض والمواعيد
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
    // ⭐ تنظيف ScrollController
    _patientsScrollController.removeListener(_onPatientsScroll);
    _patientsScrollController.dispose();
    // ⭐ تنظيف search listener
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    _appointmentsTabController.dispose();
    _qrScanController.dispose();
    super.dispose();
  }
  
  // ⭐ دالة للتحقق من الوصول لنهاية القائمة وتحميل المزيد
  void _onPatientsScroll() {
    if (_patientsScrollController.position.pixels >= 
        _patientsScrollController.position.maxScrollExtent - 200) {
      // عندما نصل لـ 200 بكسل قبل النهاية، نحمل المزيد
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        // إذا كان هناك بحث، نحمل المزيد من نتائج البحث
        if (_patientController.hasMoreSearchResults.value && 
            !_patientController.isLoadingMoreSearch.value) {
          _patientController.loadMoreSearchResults();
        }
      } else {
        // إذا لم يكن هناك بحث، نحمل المزيد من القائمة العادية
        if (_patientController.hasMorePatients.value && 
            !_patientController.isLoadingMorePatients.value) {
          _patientController.loadMorePatients();
        }
      }
    }
  }
  
  // ⭐ دالة للبحث - بنفس طريقة eversheen
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      // البحث من API
      _patientController.searchPatients(searchQuery: query);
    } else {
      // مسح البحث والعودة للقائمة العادية
      _patientController.clearSearch();
    }
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

  /// تحويل كود الباركود إذا تم مسحه ولوحة المفاتيح باللغة العربية
  String _normalizeQrCode(String code) {
    // خريطة تحويل الحروف العربية المقابلة للحروف الإنجليزية في لوحة المفاتيح القياسية
    final Map<String, String> arabicToEnglish = {
      'ض': 'q', 'ص': 'w', 'ث': 'e', 'ق': 'r', 'ف': 't', 'غ': 'y', 'ع': 'u', 'ه': 'i', 'خ': 'o', 'ح': 'p',
      'ش': 'a', 'س': 's', 'ي': 'd', 'ب': 'f', 'ل': 'g', 'ا': 'h', 'ت': 'j', 'ن': 'k', 'م': 'l',
      'ئ': 'z', 'ء': 'x', 'ؤ': 'c', 'ر': 'v', 'لا': 'b', 'ى': 'n', 'ة': 'm',
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };

    String normalized = '';
    // التعامل مع "لا" كحالة خاصة لأنها حرفين في لغة البرمجة ولكن حرف واحد في لوحة المفاتيح
    String tempCode = code.replaceAll('لا', 'b');

    for (int i = 0; i < tempCode.length; i++) {
      String char = tempCode[i];
      normalized += arabicToEnglish[char] ?? char;
    }
    return normalized;
  }

  /// معالجة كود الباركود القادم من جهاز قارئ خارجي (نفس منطق الموبايل للموظف)
  Future<void> _handleDesktopQrScan(String code) async {
    try {
      _qrScanController.clear();

      // تحويل الكود إذا كان مكتوباً بالعربي بالخطأ بسبب لغة لوحة المفاتيح
      final normalizedCode = _normalizeQrCode(code.trim());
      print('🔍 [QR Scan] Original: $code -> Normalized: $normalizedCode');

      final result =
          await _patientService.getPatientByQrCodeWithDoctors(normalizedCode);

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

      // ⭐ التحقق إذا كان المريض موجود في القائمة
      final index = _patientController.patients.indexWhere((p) => p.id == patient.id);
      
      if (index != -1) {
        // ⭐ إذا كان موجود، نحدثه
        _patientController.patients[index] = patient;
        print('✅ [QR Scan] Patient updated in list: ${patient.name}');
      } else {
        // ⭐ إذا لم يكن موجود، نضيفه للقائمة
        _patientController.addPatient(patient);
        print('✅ [QR Scan] Patient added to list: ${patient.name}');
      }

      // في شاشة الاستقبال: نختار المريض مباشرة ونحدّث واجهة الأطباء
      _patientController.selectPatient(patient);
      _showAppointments.value = false;

      // تحميل أطباء المريض للقسم الجانبي
      await _loadPatientDoctors(patient.id);
      
      // ⭐ تحميل بيانات المريض الكاملة
      final currentUser = _authController.currentUser.value;
      final userType = currentUser?.userType.toLowerCase();
      
      if (userType == 'receptionist') {
        await _galleryController.loadGallery(patient.id);
      } else {
        await Future.wait([
          _medicalRecordController.loadPatientRecords(patient.id),
          _galleryController.loadGallery(patient.id),
          _appointmentController.loadPatientAppointmentsById(patient.id),
        ]);
        
        if (patient.treatmentHistory != null &&
            patient.treatmentHistory!.isNotEmpty &&
            patient.treatmentHistory!.last == 'زراعة') {
          final implantStageController = Get.put(ImplantStageController());
          await implantStageController.loadStages(patient.id);
        }
      }
      
      print('✅ [QR Scan] Patient data loaded successfully');
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

  Future<void> _printPatientQrCode() async {
    try {
      final boundary = _qrPrintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        Get.snackbar(
          'تنبيه',
          'تعذر الوصول إلى صورة الباركود للطباعة',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.error,
          colorText: AppColors.white,
        );
        return;
      }

      // التقاط صورة الـ QR بجودة عالية لتناسب الطباعة على الليبل
      final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        Get.snackbar(
          'تنبيه',
          'تعذر تجهيز صورة الباركود للطباعة',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.error,
          colorText: AppColors.white,
        );
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(pngBytes);

      // صفحة الطباعة بحجم الليبل: 6 سم × 4 سم (العرض × الارتفاع) بدون هوامش
      final labelFormat = PdfPageFormat(
        6 * PdfPageFormat.cm, // العرض
        4 * PdfPageFormat.cm, // الارتفاع
        marginAll: 0, // بدون هوامش - يبدأ من 0
      );

      pdf.addPage(
        pw.Page(
          pageFormat: labelFormat,
          build: (pw.Context context) {
            // استخدام المساحة الكاملة للصفحة بدون خصم هوامش
            final minAvailable = labelFormat.height < labelFormat.width
                ? labelFormat.height
                : labelFormat.width;

            // حجم الـ QR (حوالي 70% من أصغر بُعد) لضمان عدم القص
            final qrSize = minAvailable * 0.7;

            // نضع الباركود في منتصف الارتفاع، مع محاذاة يمين
            // ثم نزيحه قليلاً جداً لليسار داخل صفحة الـ PDF ليبتعد عن حافة القص
            return pw.Transform.translate(
              offset: PdfPoint(-0.1* PdfPageFormat.cm, 0),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.SizedBox(
                  width: qrSize,
                  height: qrSize,
                  child: pw.Image(
                    pdfImage,
                    width: qrSize,
                    height: qrSize,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء طباعة الباركود',
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
                  'استقبال',
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

          // Second Row: Profile, Receptionist Name, Search Bar, Icons - starts from right, 10px from title, 20px from right edge
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
                // Receptionist Name
                Obx(() {
                  final user = _authController.currentUser.value;
                  final userName = user?.name ?? 'موظف استقبال';
                  return Text(
                    userName,
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
                      _showReceptionProfileDialog(context);
                    },
                    child: CircleAvatar(
                      radius: 30.r,
                      backgroundColor: AppColors.primaryLight,
                      child: validImageUrl != null &&
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
                                  final name = user?.name ?? 'موظف استقبال';
                                  return Container(
                                    color: AppColors.primaryLight,
                                    child: Text(
                                      name.isNotEmpty ? name[0] : 'م',
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
                                  : 'م',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.bold,
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
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: Obx(() {
          final query = _searchController.text.trim();
          final isSearching = _patientController.isSearching.value;
          final isLoading = _patientController.isLoading.value;
          final isLoadingMore = query.isNotEmpty 
              ? _patientController.isLoadingMoreSearch.value
              : _patientController.isLoadingMorePatients.value;
          final hasMore = query.isNotEmpty
              ? _patientController.hasMoreSearchResults.value
              : _patientController.hasMorePatients.value;
          
          // ⭐ استخدام نتائج البحث إذا كان هناك بحث، وإلا استخدام القائمة العادية
          final patientsList = query.isNotEmpty
              ? _patientController.searchResults.toList()
              : _patientController.patients.toList();

          // ترتيب المرضى من الأحدث إلى الأقدم حسب الـ id
          patientsList.sort((a, b) => b.id.compareTo(a.id));

          if (isSearching || (isLoading && query.isEmpty)) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          if (patientsList.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 260.h,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 60.sp, color: Colors.grey),
                        SizedBox(height: 16.h),
                        Text(
                          query.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا يوجد مرضى',
                          style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                        ),
                        if (query.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Text(
                            'جرب البحث بكلمات مختلفة',
                            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            controller: _patientsScrollController, // ⭐ إضافة ScrollController
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(20.w),
            itemCount: patientsList.length + (hasMore ? 1 : 0), // ⭐ إضافة 1 لعرض loading indicator
            itemBuilder: (context, index) {
              // ⭐ إذا وصلنا للنهاية ونعرض loading indicator
              if (index == patientsList.length) {
                return Container(
                  padding: EdgeInsets.all(20.w),
                  child: Center(
                    child: isLoadingMore
                        ? CircularProgressIndicator()
                        : SizedBox.shrink(),
                  ),
                );
              }
              
              final patient = patientsList[index];
              return _buildPatientCard(patient: patient);
            },
          );
        }),
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
                Tab(text: 'تصفية مخصصة'),
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
                _buildAppointmentsTableContent('تصفية مخصصة'),
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

      // تحديد المواعيد حسب نوع الفلتر
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
          filteredAppointments =
              _appointmentController.getThisMonthAppointments();
          emptyMessage = 'لا توجد مواعيد هذا الشهر';
          break;
        case 'تصفية مخصصة':
          if (_appointmentsRangeStart != null &&
              _appointmentsRangeEnd != null) {
            final start = _appointmentsRangeStart!;
            final end = _appointmentsRangeEnd!;
            filteredAppointments = _appointmentController.appointments
                .where((apt) =>
                    !apt.date.isBefore(
                        DateTime(start.year, start.month, start.day)) &&
                    !apt.date.isAfter(
                        DateTime(end.year, end.month, end.day)))
                .toList();
            emptyMessage = 'لا توجد مواعيد في هذه الفترة';
          } else {
            filteredAppointments = [];
            emptyMessage = 'اختر تاريخاً (من / إلى) لعرض المواعيد';
          }
          break;
      }

      // ترتيب المواعيد حسب التاريخ
      filteredAppointments.sort((a, b) => a.date.compareTo(b.date));

      final bool showCustomFilterControls = filter == 'تصفية مخصصة';

      Widget buildEmptyState() {
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

      final tableContent = filteredAppointments.isEmpty
          ? buildEmptyState()
          : Container(
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

      // في تبويب التصفية المخصصة نضيف أدوات اختيار الشهر أو الفترة فوق الجدول
      if (showCustomFilterControls) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: [
                  // زر واحد لاختيار الفترة (من / إلى)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      // اختيار تاريخ البداية
                      final start = await showDatePicker(
                        context: context,
                        initialDate: _appointmentsRangeStart ?? now,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 5),
                      );
                      if (start == null) return;

                      // اختيار تاريخ النهاية
                      final end = await showDatePicker(
                        context: context,
                        initialDate: _appointmentsRangeEnd ?? start,
                        firstDate: DateTime(start.year, start.month, start.day),
                        lastDate: DateTime(start.year + 5),
                      );
                      if (end == null) return;

                      setState(() {
                        _appointmentsRangeStart = start;
                        _appointmentsRangeEnd = end;
                      });
                    },
                    icon: Icon(
                      Icons.date_range,
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      (_appointmentsRangeStart == null ||
                              _appointmentsRangeEnd == null)
                          ? 'من / إلى'
                          : '${DateFormat('yyyy/MM/dd', 'ar').format(_appointmentsRangeStart!)}  →  ${DateFormat('yyyy/MM/dd', 'ar').format(_appointmentsRangeEnd!)}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(child: tableContent),
          ],
        );
      }

      return tableContent;
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
        onTap: () async {
          // جلب بيانات المريض المحدثة من الـ API عند فتح ملفه
          try {
            final result = await _patientService.getPatientByQrCodeWithDoctors(patient.qrCodeData ?? '');
            if (result != null && result['patient'] != null) {
              final updatedPatient = result['patient'] as PatientModel;
              // تحديث المريض في القائمة
              final index = _patientController.patients.indexWhere((p) => p.id == updatedPatient.id);
              if (index != -1) {
                _patientController.patients[index] = updatedPatient;
              }
              _patientController.selectPatient(updatedPatient);
            } else {
              _patientController.selectPatient(patient);
            }
          } catch (e) {
            // في حالة الخطأ، نستخدم المريض من القائمة
            _patientController.selectPatient(patient);
          }
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
                          style: GoogleFonts.cairo(
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
    // التحقق من نوع المستخدم
    final userType = _authController.currentUser.value?.userType;
    final isReceptionist = userType != null && userType.toLowerCase() == 'receptionist';

    return Container(
      color: const Color(0xFFF4FEFF),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Patient Information Card
                  Container(
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
                        // QR Code + add-image button (left side)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            if (isReceptionist) ...[
                              SizedBox(height: 3.h),
                              Padding(
                                padding: EdgeInsets.only(left: 10.w),
                                child: SizedBox(
                                  width: 120.w,
                                  height: 32.h,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _showAddImageDialog(context, patient.id);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.add_a_photo_outlined,
                                      color: Colors.white,
                                      size: 16.sp,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'إضافة صورة',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        // Patient Details (Text only) - same height as image
                        Container(
                          height: 145.h,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Name at the top
                              Text(
                                'الاسم : ${patient.name}${(patient.visitType != null && patient.visitType!.trim().isNotEmpty) ? ' (${patient.visitType})' : ''}',
                                style: GoogleFonts.cairo(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF649FCC),
                                ),
                                textAlign: TextAlign.right,
                                maxLines: 2,
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
                              // نوع المريض - أسفل نوع العلاج
                              Text(
                                'نوع المريض : ${(patient.visitType != null && patient.visitType!.trim().isNotEmpty) ? patient.visitType : 'لا يوجد'}',
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

                  // معرض صور الموظف + الأطباء المعالجون (خاص بموظف الاستقبال)
                  if (isReceptionist) ...[
                    SizedBox(height: 1.h),
                    _buildReceptionGallerySection(patient),
                    SizedBox(height: 24.h),
                    _buildDoctorsSection(patient),
                  ],
                ],
              ),
            ),
          ),

          // Transfer Button (only for receptionist)
          if (isReceptionist)
            Padding(
              padding: EdgeInsets.all(24.w),
              child: Container(
                width: double.infinity,
                height: 56.h,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: ElevatedButton(
                  onPressed: () {
                      _showSelectDoctorDialog(context, patient);
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
                      color: Colors.white,
                    ),
                  ),
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
                            final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);
                            return GestureDetector(
                              onTap: () {
                                if (validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl)) {
                                  _showImageFullScreenDialog(context, validImageUrl);
                                }
                              },
                              child: Container(
                              width: 60.w,
                              height: 70.h,
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

    // Ensure patient appointments are loaded at least once (prevents "disappearing"
    // when the global appointments list is replaced by doctor/reception appointments).
    _appointmentController.ensurePatientAppointmentsLoadedById(patient.id);

    return Obx(() {
      if (_appointmentController.isLoading.value) {
        return Container(
          color: const Color(0xFFF4FEFF),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      final cached = _appointmentController.getCachedPatientAppointments(
        patient.id,
      );
      final appointments = cached.isNotEmpty
          ? List<AppointmentModel>.from(cached)
          : _appointmentController.appointments
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

                if (!success) {
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
    // Use the same date/time dialog used in normal appointment booking (Step 1),
    // but without notes/images.
    DateTime? selectedDate = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    String? selectedTime = _convertTo12Hour(
      '${currentDate.hour.toString().padLeft(2, '0')}:${currentDate.minute.toString().padLeft(2, '0')}',
    );

    // Resolve doctorId from patient
    final patient = _patientController.getPatientById(patientId);
    final doctorIds = patient?.doctorIds ?? [];
    final doctorId = doctorIds.isNotEmpty ? doctorIds.first : null;

    final workingHoursController = Get.put(WorkingHoursController());
    if (doctorId != null) {
      workingHoursController.loadWorkingHours(doctorId: doctorId);
    }

    List<String> availableSlots = [];
    bool isLoadingSlots = false;
    bool didInitSlots = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Initial slots load for current stage date
            if (!didInitSlots && selectedDate != null && doctorId != null) {
              didInitSlots = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  setDialogState(() {
                    isLoadingSlots = true;
                  });
                  final date = selectedDate!;
                  final dateStr =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  final userType =
                      (_authController.currentUser.value?.userType ?? '')
                          .toLowerCase();
                  final isReceptionOrAdmin =
                      userType == 'receptionist' || userType == 'admin';
                  final slots = isReceptionOrAdmin
                      ? await _workingHoursService.getAvailableSlotsForReception(
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
                } catch (_) {
                  setDialogState(() {
                    availableSlots = [];
                    isLoadingSlots = false;
                  });
                }
              });
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  maxWidth: 400.w,
                ),
                width: 400.w,
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
                      selectedTime = null;
                      isLoadingSlots = true;
                    });

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
                                .getAvailableSlotsForReception(doctorId, dateStr)
                            : await _workingHoursService.getAvailableSlots(
                                doctorId,
                                dateStr,
                              );
                        setDialogState(() {
                          availableSlots = slots;
                          isLoadingSlots = false;
                        });
                      } catch (e) {
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
                    if (selectedDate == null || selectedTime == null) {
                      Get.snackbar(
                        'تنبيه',
                        'يرجى اختيار التاريخ والوقت',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.orange,
                        colorText: AppColors.white,
                      );
                      return;
                    }

                    final implantStageController = Get.put(ImplantStageController());
                    final time24 = _convertFrom12HourTo24(selectedTime!);
                    final success = await implantStageController.updateStageDate(
                      patientId,
                      stageName,
                      selectedDate!,
                      time24,
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
                        implantStageController.errorMessage.value.isNotEmpty
                            ? implantStageController.errorMessage.value
                            : 'فشل تحديث تاريخ المرحلة',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: AppColors.white,
                      );
                    }
                  },
                  () => Navigator.of(context).pop(),
                  setDialogState,
                  primaryButtonText: 'حفظ',
                  hintText: 'لطفا قم بادخال الوقت والتاريخ لتعديل موعد المرحلة',
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

  /// معرض صور الموظف في ملف المريض (يظهر لموظف الاستقبال فقط فوق الأطباء المعالجون)
  Widget _buildReceptionGallerySection(PatientModel patient) {
    return Obx(() {
      if (_galleryController.isLoading.value) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      final images = _galleryController.galleryImages;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'صور المريض (المضافة من قبلك)',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(height: 12.h),
            if (images.isEmpty)
              Text(
                'لا توجد صور مضافة بعد',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.right,
              )
            else
              SizedBox(
                height: 110.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => SizedBox(width: 8.w),
                  itemBuilder: (context, index) {
                    final img = images[index];
                    final imageUrl = ImageUtils.convertToValidUrl(img.imagePath);
                    return GestureDetector(
                      onTap: () {
                        _showGalleryImageDialog(context, img);
                      },
                      child: Container(
                        width: 100.w,
                        height: 100.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.r),
                          child: imageUrl != null &&
                                  ImageUtils.isValidImageUrl(imageUrl)
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppColors.divider,
                                    child: Center(
                                      child: CircularProgressIndicator(
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
                                      size: 26.sp,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppColors.divider,
                                  child: Icon(
                                    Icons.broken_image,
                                    color: AppColors.textHint,
                                    size: 26.sp,
                                  ),
                                ),
                        ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Make the sidebar robust on smaller screens by sizing relative to
        // available height and scaling content down when needed.
        final sidebarWidth =
            (110.w).clamp(72.0, 130.0); // keep reasonable bounds
        final h = constraints.maxHeight;

        final topPad = (h * 0.06).clamp(12.0, 50.0);
        final bottomPad = (h * 0.08).clamp(16.0, 100.0);
        final logoSize = (h * 0.18).clamp(64.0, 120.0);
        final bottomIconSize = (h * 0.12).clamp(44.0, 80.0);
        final gapAfterLogo = (h * 0.02).clamp(8.0, 16.0);
        final gapBeforeBottom = (h * 0.03).clamp(10.0, 25.0);

        return Container(
          width: sidebarWidth,
          color: const Color(0xFF649FCC),
          child: Column(
            children: [
              SizedBox(height: topPad),

              // Logo Section (scales down if height is tight)
              SizedBox(
                height: logoSize,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              SizedBox(height: gapAfterLogo),

              // Vertical Text (force single line + scale down to avoid wrapping)
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'مركز فرح التخصصي لطب الاسنان',
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: gapBeforeBottom),

              // Bottom Icon (scales down)
              SizedBox(
                height: bottomIconSize,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(
                      'assets/images/happy 2.png',
                      width: bottomIconSize,
                      height: bottomIconSize,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.medical_services_outlined,
                          color: Colors.white,
                          size: 30.sp,
                        );
                      },
                    ),
                  ),
                ),
              ),

              SizedBox(height: bottomPad),
            ],
          ),
        );
      },
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
                                  // لا نعيد تحميل السجلات هنا حتى لا يحدث فلاش، الكونترولر حدّث القائمة متفائلاً
                                } catch (e) {
                                  // الخطأ يظهر من داخل الكونترولر
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
                            final time24 = _convertFrom12HourTo24(selectedTime!);
                            final timeParts = time24.split(':');
                            final hour = int.parse(timeParts[0]);
                            final minute =
                                timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

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
                              // لا نعيد تحميل المواعيد هنا حتى لا يحدث فلاش، الكونترولر يضيف الموعد متفائلاً
                            } catch (e) {
                              print(
                                '❌ [ReceptionHomeScreen] Error adding appointment: $e',
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

  /// Convert 12-hour time format with ص/م (e.g. "2:30 م") to 24-hour "HH:mm"
  String _convertFrom12HourTo24(String time12) {
    try {
      final isPM = time12.contains(' م');
      final cleaned = time12.replaceAll(' م', '').replaceAll(' ص', '').trim();
      final parts = cleaned.split(':');
      var hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (_) {
      // Fallback: return as-is (server-side will reject invalid format)
      return time12;
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
    {
      String primaryButtonText = 'حجز',
      String hintText = 'لطفا قم بادخال الوقت والتاريخ لتسجيل موعد المريض',
    }
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
                        hintText,
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
                        primaryButtonText,
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
            width: 365.w,
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
                  child: RepaintBoundary(
                    key: _qrPrintKey,
                    child: QrImageView(
                      data: patientId,
                      version: QrVersions.auto,
                      size: 250.w,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _printPatientQrCode(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    icon: Icon(
                      Icons.print,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                    label: Text(
                      'طباعة الباركود',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
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

  // Load patient doctors (for receptionist)
  Future<void> _loadPatientDoctors(String patientId) async {
    // تجنب تحميل مكرر إذا كان التحميل جارياً بالفعل لنفس المريض
    if (_isLoadingDoctors.value && _currentPatientIdForDoctors == patientId) {
      return;
    }
    
    // إذا كان المريض مختلفاً، قم بإعادة التعيين
    if (_currentPatientIdForDoctors != patientId) {
      _patientDoctors.clear();
      _currentPatientIdForDoctors = patientId;
    }
    
    _isLoadingDoctors.value = true;
    try {
      print('👨‍⚕️ [ReceptionHomeScreen] Loading doctors for patient: $patientId');
      final doctors = await _patientService.getPatientDoctors(patientId);
      print('👨‍⚕️ [ReceptionHomeScreen] Loaded ${doctors.length} doctors for patient $patientId');
      for (var doctor in doctors) {
        print('  - Doctor: ${doctor.name} (ID: ${doctor.id})');
      }
      
      // تأكد من أن هذه الأطباء للمريض الحالي فقط
      if (_currentPatientIdForDoctors == patientId) {
        _patientDoctors.value = doctors;
      }
    } catch (e) {
      print('❌ [ReceptionHomeScreen] Error loading doctors for patient $patientId: $e');
      // Error handling - can show snackbar if needed
      if (_currentPatientIdForDoctors == patientId) {
        _patientDoctors.clear();
      }
    } finally {
      if (_currentPatientIdForDoctors == patientId) {
        _isLoadingDoctors.value = false;
      }
    }
  }

  Widget _buildDoctorsSection(PatientModel patient) {
    return Obx(() {
      // Ensure doctors are loaded for the current patient
      if (_currentPatientIdForDoctors != patient.id) {
        // Different patient - clear and reload
        _patientDoctors.clear();
        _currentPatientIdForDoctors = patient.id;
        if (!_isLoadingDoctors.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadPatientDoctors(patient.id);
          });
        }
      }

      if (_isLoadingDoctors.value) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        // Doctor info column (on the left in RTL)
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
                        SizedBox(width: 12.w),
                        // Doctor Image on the right (in RTL) - last element
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

  Widget _buildDoctorImage(DoctorModel doctor, String doctorInitials) {
    // Check if imageUrl is valid and convert to valid URL
    final imageUrl = doctor.imageUrl;
    final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);

    if (validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl)) {
      return CachedNetworkImage(
        imageUrl: validImageUrl,
        fit: BoxFit.cover,
        width: 80.w,
        height: 80.w,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            _buildDefaultDoctorImage(doctorInitials),
      );
    } else {
      return _buildDefaultDoctorImage(doctorInitials);
    }
  }

  Widget _buildDefaultDoctorImage(String doctorInitials) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
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
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showSelectDoctorDialog(BuildContext context, PatientModel patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _SelectDoctorDialog(
          patient: patient,
          patientService: _patientService,
          onSaved: () async {
            // إعادة تحميل أطباء المريض للقسم الجانبي فقط
            await _loadPatientDoctors(patient.id);

            // تحديث doctorIds للمريض الحالي في الواجهة بدون إعادة تحميل كاملة
            final newDoctorIds = _patientDoctors.map((d) => d.id).toList();
            _patientController.updatePatientDoctorIds(
              patient.id,
              newDoctorIds,
            );
          },
        );
      },
    );
  }

  void _showAddPatientDialog(BuildContext context) {
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _phoneController = TextEditingController();
    final TextEditingController _ageController = TextEditingController();
    final ImagePicker _imagePicker = ImagePicker();

    // State variables
    String? selectedGender;
    String? selectedVisitType = AppStrings.newPatient;
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

            // دالة لقراءة الصورة وفتح حوار قص بنسبة 1:1 ثم حفظها
            Future<void> _readAndSaveImage(
              String imagePath,
              String fileName,
              StateSetter setDialogState,
              BuildContext context,
            ) async {
              try {
                // قراءة الصورة بشكل async
                print('📖 [Camera] Starting to read image...');
                final originalBytes = await _readImageBytes(imagePath).timeout(
                  const Duration(seconds: 20),
                  onTimeout: () {
                    print('⏱️ [Camera] Timeout reading image');
                    throw TimeoutException('Timeout reading image');
                  },
                );
                print(
                    '✅ [Camera] Image read successfully, size: ${originalBytes.length} bytes');

                if (!context.mounted) return;

                // فتح حوار قص الصورة بنسبة 1:1 ليتحكم به المستخدم
                final Uint8List? croppedBytes =
                    await showDialog<Uint8List?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => _ImageCropDialog(
                    imageBytes: originalBytes,
                    title: 'قص الصورة',
                    confirmText: 'اعتماد',
                    cancelText: 'إلغاء',
                  ),
                );

                // إذا ألغى المستخدم القص، لا نقوم بحفظ الصورة
                if (croppedBytes == null) {
                  print('ℹ️ [Camera] User cancelled image cropping');
                  return;
                }

                // حفظ الصورة المقتصة في الحالة
                if (context.mounted) {
                  setDialogState(() {
                    _selectedPatientImageBytes = croppedBytes;
                    _selectedPatientImageName = fileName;
                  });
                  print('✅ [Camera] Cropped image saved to dialog state');
                }
              } catch (e, stackTrace) {
                print('❌ [Camera] Error reading or cropping image: $e');
                print('❌ [Camera] Stack trace: $stackTrace');
                
                if (context.mounted) {
                  Get.snackbar(
                    'خطأ',
                    'فشل معالجة الصورة: ${e.toString()}',
                    snackPosition: SnackPosition.TOP,
                    duration: const Duration(seconds: 3),
                  );
                }
              }
            }

            // دالة لالتقاط الصورة من الكاميرا على Windows/Linux/MacOS
            Future<void> _captureImageFromCamera(StateSetter setDialogState) async {
              try {
                // محاولة استخدام camera package
                List<CameraDescription> cameras;
                try {
                  if (availableCamerasList == null) {
                    cameras = await availableCameras();
                    availableCamerasList = cameras;
                    print('✅ [Camera] Found ${cameras.length} camera(s)');
                  } else {
                    cameras = availableCamerasList!;
                  }
                } catch (e) {
                  print('❌ [Camera] availableCameras() failed: $e');
                  String errorMsg = 'فشل الوصول إلى الكاميرا';
                  
                  // تحديد السبب الدقيق
                  if (e.toString().contains('MissingPluginException')) {
                    errorMsg = 'مكتبة الكاميرا غير مثبتة بشكل صحيح.\nيرجى إعادة بناء التطبيق.';
                  } else if (e.toString().contains('PlatformException')) {
                    errorMsg = 'خطأ في النظام.\nتأكد من أن الكاميرا متصلة ومفعلة.';
                  } else if (e.toString().contains('CameraException')) {
                    errorMsg = 'خطأ في الكاميرا.\nتأكد من الصلاحيات وإعدادات Windows.';
                  }
                  
                  Get.snackbar(
                    'خطأ',
                    '$errorMsg\n\nالسبب: ${e.toString().split(':').first}\n\nيرجى اختيار صورة من الملفات.',
                    snackPosition: SnackPosition.TOP,
                    duration: const Duration(seconds: 6),
                  );
                  return;
                }
                
                if (cameras.isEmpty) {
                  Get.snackbar(
                    'تنبيه',
                    'لا توجد كاميرا متاحة على هذا النظام.\n\nالتحقق من:\n1. الكاميرا متصلة\n2. الصلاحيات مفعلة في Windows\n3. برامج التشغيل محدثة\n\nيرجى اختيار صورة من الملفات.',
                    snackPosition: SnackPosition.TOP,
                    duration: const Duration(seconds: 6),
                  );
                  return;
                }

                // استخدام أول كاميرا متاحة
                final camera = cameras.first;
                final controller = CameraController(
                  camera,
                  ResolutionPreset.medium, // استخدام جودة متوسطة لتقليل حجم الصورة
                );

                await controller.initialize();

                // عرض شاشة الكاميرا
                if (!context.mounted) return;
                final XFile? image = await Navigator.of(context).push<XFile>(
                  MaterialPageRoute(
                    builder: (context) => _CameraCaptureScreen(
                      controller: controller,
                    ),
                  ),
                );

                await controller.dispose();

                if (image != null) {
                  // حفظ مسار الصورة أولاً بدلاً من قراءتها مباشرة
                  final imagePath = image.path;
                  final fileName = 'patient_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  
                  print('📸 [Camera] Image captured: $imagePath');
                  
                  // تأخير قراءة الصورة قليلاً لتجنب تعارض مع Navigator.pop
                  Future.microtask(() {
                    _readAndSaveImage(imagePath, fileName, setDialogState, context);
                  });
                }
              } catch (e) {
                String errorMessage = 'فشل التقاط الصورة';
                if (e.toString().contains('MissingPluginException') || 
                    e.toString().contains('availableCameras') ||
                    e.toString().contains('CameraException')) {
                  errorMessage = 'الكاميرا غير مدعومة على هذا النظام.\nيرجى:\n1. إعادة تشغيل التطبيق\n2. أو اختيار صورة من الملفات';
                } else {
                  errorMessage = 'فشل التقاط الصورة: ${e.toString()}';
                }
                Get.snackbar(
                  'خطأ',
                  errorMessage,
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 5),
                );
              }
            }

            Future<void> _pickPatientImage(ImageSource source) async {
              try {
                // على Windows/Linux/MacOS: إذا كان المصدر gallery، استخدم FilePicker
                if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) && 
                    source == ImageSource.gallery) {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    allowMultiple: false,
                  );

                  if (result != null &&
                      result.files.isNotEmpty &&
                      result.files.first.path != null) {
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
                } 
                // على Windows/Linux/MacOS: إذا كان المصدر camera، استخدم camera package مباشرة
                else if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) && 
                         source == ImageSource.camera) {
                  await _captureImageFromCamera(setDialogState);
                } 
                // على الموبايل: استخدام image_picker
                else {
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
                String errorMessage = 'فشل اختيار الصورة';
                if (e.toString().contains('cameraDelegate') || 
                    e.toString().contains('ImageSource.camera')) {
                  errorMessage = 'الكاميرا غير متاحة على هذا النظام. يرجى اختيار صورة من الملفات.';
                } else {
                  errorMessage = 'فشل اختيار الصورة: ${e.toString()}';
                }
                Get.snackbar(
                  'خطأ',
                  errorMessage,
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
                        // خيار اختيار صورة من الملفات
                        ListTile(
                          leading: Icon(Icons.photo_library,
                              color: AppColors.primary),
                          title: Text(
                            Platform.isWindows || Platform.isLinux || Platform.isMacOS
                                ? 'اختيار صورة'
                                : 'اختيار من المعرض',
                            textAlign: TextAlign.right,
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            await _pickPatientImage(ImageSource.gallery);
                          },
                        ),
                        // خيار التقاط صورة من الكاميرا (متاح على جميع المنصات)
                        ListTile(
                          leading: Icon(Icons.photo_camera,
                              color: AppColors.primary),
                          title: Text('التقاط صورة',
                              textAlign: TextAlign.right),
                          onTap: () async {
                            Navigator.pop(context);
                            await _pickPatientImage(ImageSource.camera);
                          },
                        ),
                        if (_selectedPatientImageBytes != null)
                          ListTile(
                            leading: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            title: const Text('إزالة الصورة',
                                textAlign: TextAlign.right),
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
              bool didCloseDialog = false;
              final trimmedPhone = _phoneController.text.trim();

              if (_nameController.text.isEmpty ||
                  trimmedPhone.isEmpty ||
                  selectedGender == null ||
                  selectedVisitType == null ||
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
                    return await _patientService.createPatientForReception(
                      name: _nameController.text.trim(),
                      phoneNumber: trimmedPhone,
                      gender: selectedGender!,
                      visitType: selectedVisitType,
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
                        final updated = await _patientService.uploadPatientImageForReception(
                          patientId: createdPatient.id,
                          imageBytes: _selectedPatientImageBytes!,
                          fileName: _selectedPatientImageName ??
                              'patient_${DateTime.now().millisecondsSinceEpoch}.jpg',
                        );
                        if (updated != null) {
                          createdPatient = updated;
                        }
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
                  didCloseDialog = true;
                  Navigator.of(dialogContext).pop();
                }

                // استخدام microtask للتأكد من أن إغلاق الـ dialog تم بالكامل
                await Future.microtask(() {});

                // إضافة المريض مباشرة إلى قائمة المرضى وتعيينه كمحدد
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
                // إذا أغلقنا الـ dialog بنجاح، لا نعمل setState بعد الإغلاق
                if (!didCloseDialog && dialogContext.mounted) {
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
                                    backgroundImage: _selectedPatientImageBytes !=
                                            null
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.visitType,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                VisitTypeSelector(
                                  selectedVisitType: selectedVisitType,
                                  onVisitTypeChanged: (v) {
                                    setDialogState(() {
                                      selectedVisitType = v;
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
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
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

  void _showReceptionProfileDialog(BuildContext context) {
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
                // Name
                Text(
                  user?.name ?? 'موظف استقبال',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                // Phone
                if (user?.phoneNumber != null &&
                    user!.phoneNumber.trim().isNotEmpty)
                  Text(
                    user.phoneNumber,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                SizedBox(height: 24.h),
                // Buttons: edit profile + logout
                SizedBox(
                  width: double.infinity,
                  height: 45.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showEditReceptionProfileDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'تعديل الملف الشخصي',
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
                          'تسجيل الخروج',
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

  void _showEditReceptionProfileDialog(BuildContext context) {
    final AuthService _authService = AuthService();
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _phoneController = TextEditingController();

    final user = _authController.currentUser.value;
    _nameController.text = user?.name ?? '';
    _phoneController.text = user?.phoneNumber ?? '';

    bool _isLoading = false;
    bool _isUploadingImage = false;
    int _imageTimestamp = DateTime.now().millisecondsSinceEpoch;
    String? _currentImageUrl =
        ImageUtils.convertToValidUrl(user?.imageUrl);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> _pickAndUploadImage() async {
              try {
                File? imageFile;

                if (Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS) {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                  );

                  if (result != null &&
                      result.files.isNotEmpty &&
                      result.files.first.path != null) {
                    imageFile = File(result.files.first.path!);
                  }
                } else {
                  final XFile? image = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );

                  if (image != null) {
                    imageFile = File(image.path);
                  }
                }

                if (imageFile == null) return;

                setDialogState(() {
                  _isUploadingImage = true;
                });

                await _authService.uploadProfileImage(imageFile);
                await _authController.checkLoggedInUser(navigate: false);

                setDialogState(() {
                  _isUploadingImage = false;
                  _imageTimestamp =
                      DateTime.now().millisecondsSinceEpoch;
                  final refreshedUser =
                      _authController.currentUser.value;
                  _currentImageUrl = ImageUtils.convertToValidUrl(
                    refreshedUser?.imageUrl,
                  );
                });

                Get.snackbar(
                  'نجح',
                  'تم تحديث الصورة بنجاح',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: AppColors.success,
                  colorText: AppColors.white,
                );
              } catch (e) {
                setDialogState(() {
                  _isUploadingImage = false;
                });
                Get.snackbar(
                  'خطأ',
                  'فشل تحديث الصورة: ${e.toString()}',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: AppColors.error,
                  colorText: AppColors.white,
                );
              }
            }

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

                Navigator.of(dialogContext).pop();

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
                      Column(
                        children: [
                          // Profile image with change button
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 48.r,
                                backgroundColor: AppColors.primaryLight,
                                child: (_currentImageUrl != null &&
                                        ImageUtils.isValidImageUrl(
                                          _currentImageUrl!,
                                        ))
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              '$_currentImageUrl?t=$_imageTimestamp',
                                          fit: BoxFit.cover,
                                          width: 96.w,
                                          height: 96.w,
                                          fadeInDuration: Duration.zero,
                                          fadeOutDuration: Duration.zero,
                                          placeholder: (context, url) =>
                                              Container(
                                            color: AppColors.primaryLight,
                                          ),
                                          errorWidget:
                                              (context, url, error) =>
                                                  Icon(
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
                              if (!_isUploadingImage)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickAndUploadImage,
                                    child: Container(
                                      padding: EdgeInsets.all(8.w),
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
                                        size: 20.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_isUploadingImage)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(
                                            color: AppColors.white,
                                            strokeWidth: 3,
                                          ),
                                          SizedBox(height: 8.h),
                                          Text(
                                            'جاري تحميل الصورة...',
                                            style: TextStyle(
                                              color: AppColors.white,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 24.h),
                        ],
                      ),
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
}

class _SelectDoctorDialog extends StatefulWidget {
  final PatientModel patient;
  final PatientService patientService;
  final VoidCallback onSaved;

  const _SelectDoctorDialog({
    required this.patient,
    required this.patientService,
    required this.onSaved,
  });

  @override
  State<_SelectDoctorDialog> createState() => _SelectDoctorDialogState();
}

class _SelectDoctorDialogState extends State<_SelectDoctorDialog> {
  List<DoctorModel> _doctors = [];
  Set<String> _selectedDoctorIds = {};
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDoctorIds = Set<String>.from(widget.patient.doctorIds);
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doctors = await widget.patientService.getAllDoctors();
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Get.snackbar(
          'خطأ',
          'فشل جلب قائمة الأطباء',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  void _toggleDoctorSelection(String doctorId) {
    setState(() {
      if (_selectedDoctorIds.contains(doctorId)) {
        _selectedDoctorIds.remove(doctorId);
      } else {
        _selectedDoctorIds.add(doctorId);
      }
    });
  }

  Future<void> _saveSelection() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
              });

              try {
      await widget.patientService.assignPatientToDoctors(
        widget.patient.id,
        _selectedDoctorIds.toList(),
                );

                // Close dialog
      if (mounted) {
        Navigator.of(context).pop();
                  await Future.delayed(const Duration(milliseconds: 100));
                  
        // Call onSaved callback to reload data
        widget.onSaved();
                  
                  Get.snackbar(
                    'نجح',
                    'تم ربط المريض بالأطباء بنجاح',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.primary,
                    colorText: Colors.white,
                  );
                }
              } catch (e) {
      setState(() {
        _isSaving = false;
                });
      if (mounted) {
                Get.snackbar(
                  'خطأ',
                  'فشل ربط المريض بالأطباء',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
      }
              }
            }

  @override
  Widget build(BuildContext context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
        width: 365.w,
        height: 450.h,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4FEFF),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4FEFF),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20.r),
                          topRight: Radius.circular(20.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Close button (on the left in RTL)
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
                          // Title (centered)
                          Expanded(
                            child: Center(
                              child: Text(
                                'اختر الطبيب',
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          // Empty space to balance close button
                          SizedBox(width: 40.w),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.all(24.w),
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                child: _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              )
                    : _doctors.isEmpty
                            ? Center(
                                child: Text(
                                  'لا يوجد أطباء متاحين',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16.w,
                                  mainAxisSpacing: 16.h,
                                  childAspectRatio: 2.5,
                                ),
                        itemCount: _doctors.length,
                                itemBuilder: (context, index) {
                          final doctor = _doctors[index];
                          final isSelected = _selectedDoctorIds.contains(
                                    doctor.id,
                                  );

                                  return GestureDetector(
                            onTap: () => _toggleDoctorSelection(doctor.id),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withOpacity(0.1)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12.r),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.divider,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Radio button icon
                                          Icon(
                                            isSelected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_unchecked,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                            size: 24.sp,
                                          ),
                                          SizedBox(width: 12.w),
                                          // Doctor name
                                          Expanded(
                                            child: Text(
                                              doctor.name ?? 'طبيب',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w500,
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : AppColors.textPrimary,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    // Bottom buttons
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20.r),
                          bottomRight: Radius.circular(20.r),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Back button
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: Text(
                                    'عودة',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          // Add button
                          Expanded(
                            child: GestureDetector(
                      onTap: _isSaving ? null : _saveSelection,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                decoration: BoxDecoration(
                          color: _isSaving
                                      ? AppColors.textHint
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                          child: _isSaving
                                      ? SizedBox(
                                          width: 20.w,
                                          height: 20.h,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppColors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'اضافة',
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
                  ],
                ),
              ),
    );
  }
}

/// حوار قص الصورة بنسبة 1:1 مع تحكم المستخدم في التكبير/التحريك
class _ImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;
  final String confirmText;
  final String cancelText;

  const _ImageCropDialog({
    required this.imageBytes,
    required this.title,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  State<_ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<_ImageCropDialog> {
  final GlobalKey _cropKey = GlobalKey();
  bool _saving = false;

  Future<void> _onConfirm() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.of(context).pop<Uint8List?>(null);
        return;
      }

      final ui.Image image =
          await boundary.toImage(pixelRatio: 2.0); // دقة أعلى للصورة
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        Navigator.of(context).pop<Uint8List?>(null);
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      Navigator.of(context).pop<Uint8List?>(bytes);
    } catch (e) {
      print('❌ [CropDialog] Error capturing cropped image: $e');
      Navigator.of(context).pop<Uint8List?>(null);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      contentPadding: EdgeInsets.all(16.w),
      title: Text(
        widget.title,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 400.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // منطقة القص بنسبة 1:1
            RepaintBoundary(
              key: _cropKey,
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    color: Colors.black,
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Image.memory(
                        widget.imageBytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'اسحب الصورة وحركها داخل الإطار المربع لاختيار الجزء المناسب، ثم اضغط ${widget.confirmText}.',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.sp),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.of(context).pop<Uint8List?>(null);
                },
          child: Text(
            widget.cancelText,
            style: TextStyle(color: Colors.red, fontSize: 14.sp),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: _saving
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.confirmText,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                ),
        ),
      ],
    );
  }
}

// شاشة التقاط الصورة من الكاميرا
class _CameraCaptureScreen extends StatefulWidget {
  final CameraController controller;

  const _CameraCaptureScreen({required this.controller});

  @override
  State<_CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<_CameraCaptureScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Preview الكاميرا
          Positioned.fill(
            child: CameraPreview(widget.controller),
          ),
          // أزرار التحكم
          Positioned(
            bottom: 40.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // زر الإلغاء
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 60.w,
                    height: 60.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30.sp,
                    ),
                  ),
                ),
                // زر التقاط الصورة
                GestureDetector(
                  onTap: () async {
                    try {
                      print('📸 [Camera] Taking picture...');
                      final XFile image = await widget.controller.takePicture();
                      print('✅ [Camera] Picture taken: ${image.path}');
                      
                      if (!context.mounted) {
                        print('⚠️ [Camera] Context not mounted, cannot show confirmation dialog');
                        return;
                      }

                      // عرض حوار تأكيد بعد التقاط الصورة (صح / خطأ)
                      final bool? confirmed = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (dialogContext) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            title: Text(
                              'تأكيد الصورة',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 300.w,
                                  height: 220.h,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Image.file(
                                      File(image.path),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'هل تريد اعتماد هذه الصورة كصورة ملف للمريض؟',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                            actionsAlignment: MainAxisAlignment.spaceBetween,
                            actions: [
                              TextButton(
                                onPressed: () {
                                  // خطأ / إعادة التقاط
                                  Navigator.of(dialogContext).pop(false);
                                },
                                child: Text(
                                  'إعادة الالتقاط',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  // صح / تأكيد
                                  Navigator.of(dialogContext).pop(true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                child: Text(
                                  'اعتماد',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      // إذا اختار المستخدم "اعتماد" نرجع الصورة إلى الشاشة السابقة
                      if (confirmed == true && context.mounted) {
                        Navigator.of(context).pop(image);
                        print('✅ [Camera] Navigator popped with image after confirmation');
                      } else {
                        // في حالة عدم التأكيد، نبقى في شاشة الكاميرا لإعادة الالتقاط
                        print('ℹ️ [Camera] User chose to retake photo');
                      }
                    } catch (e, stackTrace) {
                      print('❌ [Camera] Error taking picture: $e');
                      print('❌ [Camera] Stack trace: $stackTrace');
                      if (context.mounted) {
                        Get.snackbar(
                          'خطأ',
                          'فشل التقاط الصورة: ${e.toString()}',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 4),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      margin: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                // مساحة فارغة للتوازن
                SizedBox(width: 60.w),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
