import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/constants/app_colors.dart';
import '../core/widgets/custom_button.dart';
import '../core/routes/app_routes.dart';
import '../core/utils/image_utils.dart';
import '../models/doctor_model.dart';
import '../models/patient_model.dart';
import '../services/doctor_service.dart';
import '../services/patient_service.dart';
import 'auth_controller.dart';
import 'patient_controller.dart';

/// Controller لشاشة مسح رمز QR.
class QrScannerController extends GetxController {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  final RxBool isScanning = true.obs;

  final PatientService _patientService = PatientService();

  @override
  void onClose() {
    scannerController.dispose();
    super.onClose();
  }

  /// معالجة QR code المكتشف
  void handleBarcode(BarcodeCapture barcodeCapture) {
    if (!isScanning.value) return;

    final barcodes = barcodeCapture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    isScanning.value = false;

    _processScannedCode(code);
  }

  /// معالجة منطق الأعمال بعد مسح QR code
  Future<void> _processScannedCode(String code) async {
    try {
      _showLoadingDialog();

      final result = await _patientService.getPatientByQrCodeWithDoctors(
        code,
      );

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
      final isReceptionist =
          userType != null && userType.toLowerCase() == 'receptionist';

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
    Get.toNamed(AppRoutes.patientDetails, arguments: {'patientId': patient.id});
  }

  /// إعادة تفعيل المسح
  void _resumeScanning() {
    isScanning.value = true;
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
          style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'حسناً',
              style: TextStyle(color: AppColors.primary, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  /// عرض dialog للمريض المحول (للطبيب)
  void _showPatientTransferredDialog(
    PatientModel patient,
    DoctorModel? assignedDoctor,
  ) {
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
              buildPatientImage(patientImageUrl),
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
                buildAssignedDoctorInfo(assignedDoctor, doctorImageUrl),
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
  Widget buildPatientImage(String? imageUrl) {
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
                errorWidget: (context, url, error) =>
                    Icon(Icons.person, size: 50.sp, color: AppColors.white),
                memCacheWidth: 200,
                memCacheHeight: 200,
              )
            : Icon(Icons.person, size: 50.sp, color: AppColors.white),
      ),
    );
  }

  /// بناء معلومات الطبيب المرتبط
  Widget buildAssignedDoctorInfo(DoctorModel doctor, String? imageUrl) {
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
                  : Icon(Icons.person, size: 25.sp, color: AppColors.white),
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
}
