import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/models/doctor_model.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';

class SelectDoctorScreen extends StatefulWidget {
  final String patientId;
  final List<String> currentDoctorIds; // الأطباء المرتبطين حالياً

  const SelectDoctorScreen({
    super.key,
    required this.patientId,
    this.currentDoctorIds = const [],
  });

  @override
  State<SelectDoctorScreen> createState() => _SelectDoctorScreenState();
}

class _SelectDoctorScreenState extends State<SelectDoctorScreen> {
  final PatientService _patientService = PatientService();
  List<DoctorModel> _doctors = [];
  Set<String> _selectedDoctorIds = {};
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDoctorIds = Set<String>.from(widget.currentDoctorIds);
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doctors = await _patientService.getAllDoctors();
      setState(() {
        _doctors = doctors;
      });
    } catch (e) {
      Get.snackbar(
        'خطأ',
        e is ApiException ? e.message : 'فشل جلب قائمة الأطباء',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      await _patientService.assignPatientToDoctors(
        widget.patientId,
        _selectedDoctorIds.toList(),
      );

      // Show success dialog
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
                Navigator.of(context).pop(); // Close dialog
                await Future.delayed(const Duration(milliseconds: 100));
                Get.back(
                  result: true,
                ); // Return to previous screen with success result
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
    } catch (e) {
      // Show error dialog
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
            e is ApiException ? e.message : 'فشل ربط المريض بالأطباء',
            style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFF),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: const Color(0xFFF4FEFF),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  // Back button always on the LEFT
                  const BackButtonWidget(),
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
                  // Empty space on the RIGHT to keep title centered
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
                                    ? AppColors.primary.withValues(alpha: 0.1)
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
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
                      onTap: () => Get.back(),
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
