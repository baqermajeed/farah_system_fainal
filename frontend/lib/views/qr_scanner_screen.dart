import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/custom_button.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/models/doctor_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isScanning = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// معالجة QR code المكتشف
  void _handleBarcode(BarcodeCapture barcodeCapture) {
    if (!_isScanning) return;

    final barcodes = barcodeCapture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isScanning = false;
    });

    _processScannedCode(code);
  }

  /// معالجة منطق الأعمال بعد مسح QR code
  Future<void> _processScannedCode(String code) async {
    try {
      _showLoadingDialog();

      final patientService = PatientService();
      final result = await patientService.getPatientByQrCodeWithDoctors(code);

      _hideLoadingDialog();

      if (result == null || result['patient'] == null) {
        _showErrorDialog('المريض غير موجود');
        _resumeScanning();
        return;
      }

      final patient = result['patient'] as PatientModel;
      final doctors = (result['doctors'] as List<DoctorModel>? ?? []);

      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;
      final isReceptionist = userType != null && userType.toLowerCase() == 'receptionist';

      if (isReceptionist) {
        _navigateToPatientDetails(patient);
      } else {
        final isMyPatient = await _checkPatientAssignment(patient.id);
        if (isMyPatient) {
          _navigateToPatientDetails(patient);
        } else {
          final assignedDoctor = doctors.isNotEmpty ? doctors.first : null;
          _showPatientTransferredDialog(patient, assignedDoctor);
        }
      }
    } catch (e) {
      _hideLoadingDialog();
      _showErrorDialog('حدث خطأ أثناء البحث عن المريض: ${e.toString()}');
      _resumeScanning();
    }
  }

  /// التحقق من ربط المريض بالطبيب الحالي
  Future<bool> _checkPatientAssignment(String patientId) async {
    try {
      final doctorService = DoctorService();
      final patients = await doctorService.getMyPatients(limit: 100);
      return patients.any((p) => p.id == patientId);
    } catch (e) {
      print('❌ Error checking patient assignment: $e');
      return false;
    }
  }

  /// فتح ملف المريض
  void _navigateToPatientDetails(PatientModel patient) {
    final patientController = Get.find<PatientController>();
    patientController.selectPatient(patient);
    Get.back(); // إغلاق شاشة QR scanner
    Get.toNamed(
      AppRoutes.patientDetails,
      arguments: {'patientId': patient.id},
    );
  }

  /// إعادة تفعيل المسح
  void _resumeScanning() {
    if (mounted) {
      setState(() {
        _isScanning = true;
      });
    }
  }

  /// عرض loading dialog
  void _showLoadingDialog() {
    Get.dialog(
      Center(
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16.h),
              Text(
                'جاري البحث عن بيانات المريض...',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// إخفاء loading dialog
  void _hideLoadingDialog() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  /// عرض رسالة خطأ
  void _showErrorDialog(String message) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'خطأ',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.error,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'حسناً',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// عرض dialog للمريض المحول (للطبيب)
  void _showPatientTransferredDialog(PatientModel patient, DoctorModel? assignedDoctor) {
    final patientImageUrl = ImageUtils.convertToValidUrl(patient.imageUrl);
    final doctorImageUrl = assignedDoctor?.imageUrl != null
        ? ImageUtils.convertToValidUrl(assignedDoctor!.imageUrl)
        : null;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Container(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // صورة المريض
              _buildPatientImage(patientImageUrl),
              SizedBox(height: 16.h),
              // اسم المريض
              Text(
                patient.name,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              // معلومات الطبيب المرتبط (إن وجد)
              if (assignedDoctor != null) ...[
                SizedBox(height: 24.h),
                _buildAssignedDoctorInfo(assignedDoctor, doctorImageUrl),
              ],
              SizedBox(height: 24.h),
              // زر الإغلاق
              CustomButton(
                text: 'حسناً',
                onPressed: () {
                  Get.back();
                  _resumeScanning();
                },
                backgroundColor: AppColors.primary,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء صورة المريض
  Widget _buildPatientImage(String? imageUrl) {
    return Container(
      width: 100.w,
      height: 100.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
      ),
      child: ClipOval(
        child: (imageUrl != null && ImageUtils.isValidImageUrl(imageUrl))
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: 100.w,
                height: 100.w,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (context, url) =>
                    Container(color: AppColors.primaryLight),
                errorWidget: (context, url, error) => Icon(
                  Icons.person,
                  size: 50.sp,
                  color: AppColors.white,
                ),
                memCacheWidth: 200,
                memCacheHeight: 200,
              )
            : Icon(
                Icons.person,
                size: 50.sp,
                color: AppColors.white,
              ),
      ),
    );
  }

  /// بناء معلومات الطبيب المرتبط
  Widget _buildAssignedDoctorInfo(DoctorModel doctor, String? imageUrl) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // صورة الطبيب
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight,
            ),
            child: ClipOval(
              child: (imageUrl != null && ImageUtils.isValidImageUrl(imageUrl))
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: 50.w,
                      height: 50.w,
                      placeholder: (context, url) =>
                          Container(color: AppColors.primaryLight),
                      errorWidget: (context, url, error) => Icon(
                        Icons.person,
                        size: 25.sp,
                        color: AppColors.white,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 25.sp,
                      color: AppColors.white,
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          // اسم الطبيب
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الطبيب المرتبط به',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  doctor.name ?? 'غير معروف',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Scanner View
            MobileScanner(
              controller: _controller,
              onDetect: _handleBarcode,
            ),
            // Overlay
            _buildOverlay(),
            // Header
            _buildHeader(),
            // Scanning area indicator
            _buildScanningArea(),
            // Instructions
            _buildInstructions(),
            // Flashlight toggle
            _buildFlashlightButton(),
          ],
        ),
      ),
    );
  }

  /// بناء overlay
  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.5),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.5),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  /// بناء header
  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            const BackButtonWidget(),
            Expanded(
              child: Center(
                child: Text(
                  'مسح رمز QR',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 48.w),
          ],
        ),
      ),
    );
  }

  /// بناء scanning area indicator
  Widget _buildScanningArea() {
    return Center(
      child: Container(
        width: 250.w,
        height: 250.h,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primary,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Stack(
          children: [
            _buildCornerIndicator(top: true, left: true),
            _buildCornerIndicator(top: true, left: false),
            _buildCornerIndicator(top: false, left: true),
            _buildCornerIndicator(top: false, left: false),
          ],
        ),
      ),
    );
  }

  /// بناء corner indicator
  Widget _buildCornerIndicator({required bool top, required bool left}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 30.w,
        height: 30.h,
        decoration: BoxDecoration(
          border: Border(
            top: top ? BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            bottom: top ? BorderSide.none : BorderSide(color: AppColors.primary, width: 4),
            left: left ? BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            right: left ? BorderSide.none : BorderSide(color: AppColors.primary, width: 4),
          ),
          borderRadius: BorderRadius.only(
            topLeft: (top && left) ? Radius.circular(20.r) : Radius.zero,
            topRight: (top && !left) ? Radius.circular(20.r) : Radius.zero,
            bottomLeft: (!top && left) ? Radius.circular(20.r) : Radius.zero,
            bottomRight: (!top && !left) ? Radius.circular(20.r) : Radius.zero,
          ),
        ),
      ),
    );
  }

  /// بناء instructions card
  Widget _buildInstructions() {
    return Positioned(
      bottom: 100.h,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner,
                color: AppColors.primary,
                size: 32.sp,
              ),
              SizedBox(height: 8.h),
              Text(
                'ضع رمز QR داخل الإطار',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'سيتم مسح الرمز تلقائياً',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء flashlight button
  Widget _buildFlashlightButton() {
    return Positioned(
      bottom: 40.h,
      right: 24.w,
      child: GestureDetector(
        onTap: () => _controller.toggleTorch(),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.flashlight_on,
            color: AppColors.primary,
            size: 28.sp,
          ),
        ),
      ),
    );
  }
}
