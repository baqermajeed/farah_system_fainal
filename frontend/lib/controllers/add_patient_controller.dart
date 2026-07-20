import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/iraq_governorates.dart';
import '../core/network/api_exception.dart';
import '../core/routes/app_routes.dart';
import '../core/utils/operation_dialog.dart';
import 'auth_controller.dart';
import 'patient_controller.dart';
import '../services/doctor_service.dart';
import '../services/patient_service.dart';

/// Controller لشاشة إضافة مريض جديد (من قبل الطبيب أو موظف الاستقبال).
class AddPatientController extends GetxController {
  final AuthController authController = Get.find<AuthController>();
  final PatientController patientController = Get.find<PatientController>();
  final PatientService _patientService = PatientService();
  final DoctorService _doctorService = DoctorService();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final ageController = TextEditingController();

  final Rxn<String> selectedGender = Rxn<String>();
  final Rxn<String> selectedCity = Rxn<String>();
  final RxBool isLoading = false.obs;

  final ImagePicker _imagePicker = ImagePicker();
  final Rxn<Uint8List> selectedPatientImageBytes = Rxn<Uint8List>();
  final Rxn<String> selectedPatientImageName = Rxn<String>();

  List<String> get cities => IraqGovernorates.arabicNames;

  bool isPhoneValid(String phone) {
    final cleaned = phone.trim();
    return RegExp(r'^07\d{9}$').hasMatch(cleaned);
  }

  @override
  void onReady() {
    super.onReady();
    // التحقق من تسجيل الدخول عند فتح الصفحة
    final currentUser = authController.currentUser.value;
    if (currentUser == null) {
      Get.snackbar(
        'خطأ',
        'يجب تسجيل الدخول أولاً',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
      Get.offAllNamed(AppRoutes.userSelection);
      return;
    }

    // التحقق من أن المستخدم طبيب أو موظف استقبال
    final userType = currentUser.userType.toLowerCase();
    if (userType != 'doctor' && userType != 'receptionist') {
      Get.snackbar(
        'خطأ',
        'غير مصرح لك بالوصول إلى هذه الصفحة',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
      Get.back();
      return;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    ageController.dispose();
    super.onClose();
  }

  void showCityPicker(BuildContext context) {
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
                        selectedCity.value = city;
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

  void showPatientImagePicker(BuildContext context) {
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
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: Text('اختيار من المعرض', textAlign: TextAlign.right),
                onTap: () async {
                  Navigator.pop(context);
                  await pickPatientImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: AppColors.primary),
                title: Text('التقاط صورة', textAlign: TextAlign.right),
                onTap: () async {
                  Navigator.pop(context);
                  await pickPatientImage(ImageSource.camera);
                },
              ),
              if (selectedPatientImageBytes.value != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('إزالة الصورة', textAlign: TextAlign.right),
                  onTap: () {
                    Navigator.pop(context);
                    selectedPatientImageBytes.value = null;
                    selectedPatientImageName.value = null;
                  },
                ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }

  Future<void> pickPatientImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(source: source);
      if (picked == null) return;

      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'تعديل الصورة',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'تعديل الصورة',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return;

      final bytes = await File(croppedFile.path).readAsBytes();
      final fileName = picked.name.isNotEmpty
          ? picked.name
          : 'patient_${DateTime.now().millisecondsSinceEpoch}.jpg';

      selectedPatientImageBytes.value = bytes;
      selectedPatientImageName.value = fileName;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل اختيار الصورة: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  Future<void> submit(BuildContext context) async {
    // التحقق من تسجيل الدخول
    final currentUser = authController.currentUser.value;
    if (currentUser == null) {
      Get.snackbar(
        'خطأ',
        'يجب تسجيل الدخول أولاً',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
      // توجيه المستخدم إلى صفحة تسجيل الدخول
      Get.offAllNamed(AppRoutes.userSelection);
      return;
    }

    final trimmedPhone = phoneController.text.trim();

    if (nameController.text.isEmpty ||
        trimmedPhone.isEmpty ||
        selectedGender.value == null ||
        selectedCity.value == null ||
        ageController.text.isEmpty) {
      Get.snackbar(
        'خطأ',
        'يرجى ملء جميع الحقول',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    final age = int.tryParse(ageController.text);
    if (age == null || age < 1 || age > 120) {
      Get.snackbar(
        'خطأ',
        'يرجى إدخال عمر صحيح',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    if (!isPhoneValid(trimmedPhone)) {
      Get.snackbar(
        'خطأ',
        'رقم الهاتف يجب أن يكون 11 رقماً ويبدأ بـ 07',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    final currentUserType = currentUser.userType.toLowerCase();

    // التحقق من أن المستخدم طبيب أو موظف استقبال
    if (currentUserType != 'doctor' && currentUserType != 'receptionist') {
      Get.snackbar(
        'خطأ',
        'غير مصرح لك بإضافة مرضى',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
      return;
    }

    final isReceptionistAction = currentUserType == 'receptionist';

    if (isReceptionistAction) {
      await _submitAsReceptionist(context, age);
    } else {
      await _submitAsDoctor(context, age);
    }
  }

  Future<void> _submitAsReceptionist(BuildContext context, int age) async {
    isLoading.value = true;
    try {
      var createdPatient = await runWithOperationDialog(
        context: context,
        message: 'جارٍ الإضافة',
        action: () async {
          return await _patientService.createPatientForReception(
            name: nameController.text.trim(),
            phoneNumber: phoneController.text.trim(),
            gender: selectedGender.value!,
            age: age,
            city: selectedCity.value!,
          );
        },
      );

      if (selectedPatientImageBytes.value != null) {
        try {
          createdPatient = await runWithOperationDialog(
            context: context,
            message: 'جارٍ الرفع',
            action: () async {
              await _patientService.uploadPatientImageForReception(
                patientId: createdPatient.id,
                imageBytes: selectedPatientImageBytes.value!,
                fileName:
                    selectedPatientImageName.value ??
                    'patient_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );
              return createdPatient;
            },
          );
        } catch (e) {
          Get.snackbar(
            'تنبيه',
            'تم إنشاء المريض لكن فشل رفع الصورة',
            snackPosition: SnackPosition.TOP,
          );
        }
      }

      await patientController.loadPatients();
      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
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
            'تم إضافة المريض بنجاح',
            style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Future.delayed(const Duration(milliseconds: 100));
                Get.offNamed(
                  AppRoutes.patientDetails,
                  arguments: {'patientId': createdPatient.id},
                );
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
    } on ApiException catch (e) {
      Get.snackbar(
        'خطأ',
        e.message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل إضافة المريض',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _submitAsDoctor(BuildContext context, int age) async {
    isLoading.value = true;
    try {
      var createdPatient = await runWithOperationDialog(
        context: context,
        message: 'جارٍ الإضافة',
        action: () async {
          return await _doctorService.addPatient(
            name: nameController.text.trim(),
            phoneNumber: phoneController.text.trim(),
            gender: selectedGender.value!,
            age: age,
            city: selectedCity.value!,
          );
        },
      );

      if (selectedPatientImageBytes.value != null) {
        try {
          createdPatient = await runWithOperationDialog(
            context: context,
            message: 'جارٍ الرفع',
            action: () async {
              return await _doctorService.uploadPatientImage(
                patientId: createdPatient.id,
                imageBytes: selectedPatientImageBytes.value!,
                fileName:
                    selectedPatientImageName.value ??
                    'patient_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );
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

      if (!context.mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop(true);
      } else {
        Get.offAllNamed(AppRoutes.doctorPatientsList);
      }
    } on ApiException catch (e) {
      Get.snackbar(
        'خطأ',
        e.message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل إضافة المريض',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
