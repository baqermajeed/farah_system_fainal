import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../core/constants/app_colors.dart';
import '../core/network/api_exception.dart';
import '../models/doctor_model.dart';
import '../services/patient_service.dart';

/// Controller لشاشة اختيار الأطباء لربطهم بمريض.
class SelectDoctorController extends GetxController {
  final PatientService _patientService = PatientService();

  String patientId = '';
  List<String> currentDoctorIds = [];

  final RxList<DoctorModel> doctors = <DoctorModel>[].obs;
  final RxSet<String> selectedDoctorIds = <String>{}.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    patientId = args?['patientId'] ?? '';
    currentDoctorIds =
        (args?['currentDoctorIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    selectedDoctorIds.addAll(currentDoctorIds);
    loadDoctors();
  }

  Future<void> loadDoctors() async {
    isLoading.value = true;

    try {
      final loadedDoctors = await _patientService.getAllDoctors();
      doctors.assignAll(loadedDoctors);
    } catch (e) {
      Get.snackbar(
        'خطأ',
        e is ApiException ? e.message : 'فشل جلب قائمة الأطباء',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void toggleDoctorSelection(String doctorId) {
    if (selectedDoctorIds.contains(doctorId)) {
      selectedDoctorIds.remove(doctorId);
    } else {
      selectedDoctorIds.add(doctorId);
    }
  }

  Future<void> saveSelection() async {
    if (isSaving.value) return;

    isSaving.value = true;

    try {
      await _patientService.assignPatientToDoctors(
        patientId,
        selectedDoctorIds.toList(),
      );

      await _showSuccessDialog();
    } catch (e) {
      await _showErrorDialog(
        e is ApiException ? e.message : 'فشل ربط المريض بالأطباء',
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _showSuccessDialog() {
    return Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 24.sp),
            SizedBox(width: 12.w),
            Text(
              'نجح',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'تم ربط المريض بالأطباء بنجاح',
          style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Get.back(); // إغلاق الـ dialog
              await Future.delayed(const Duration(milliseconds: 100));
              Get.back(result: true); // العودة إلى الشاشة السابقة بنتيجة النجاح
            },
            child: Text(
              'حسناً',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String message) {
    return Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.error, color: AppColors.error, size: 24.sp),
            SizedBox(width: 12.w),
            Text(
              'فشل',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'حسناً',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
