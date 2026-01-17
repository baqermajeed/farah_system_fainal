import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/widgets/custom_text_field.dart';
import 'package:farah_sys_final/core/widgets/gender_selector.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/utils/operation_dialog.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final PatientController _patientController = Get.find<PatientController>();
  final PatientService _patientService = PatientService();
  final DoctorService _doctorService = DoctorService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? selectedGender;
  String? selectedCity;
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _selectedPatientImageBytes;
  String? _selectedPatientImageName;

  bool _isPhoneValid(String phone) {
    final cleaned = phone.trim();
    return RegExp(r'^07\d{9}$').hasMatch(cleaned);
  }

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

  @override
  void initState() {
    super.initState();
    // التحقق من تسجيل الدخول عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = _authController.currentUser.value;
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
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content with padding
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    SizedBox(height: 56.h),
                    SizedBox(height: 12.h),
                    // Patient image picker (for new patient)
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
                    SizedBox(height: 16.h),
                    // Title
                    Text(
                      'اضافة مريض',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
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
                            setState(() {
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
                            onTap: () => _showCityPicker(),
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
                    // Add button (without icon)
                    Obx(() {
                      final isLoading = _authController.isLoading.value || _isLoading;
                      
                      return Container(
                        width: double.infinity,
                        height: 50.h,
                        decoration: BoxDecoration(
                          color: isLoading
                              ? AppColors.textHint
                              : AppColors.secondary,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isLoading
                                ? null
                                : () async {
                                    // التحقق من تسجيل الدخول
                                    final currentUser = _authController.currentUser.value;
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

                                    final age = int.tryParse(
                                      _ageController.text,
                                    );
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
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      try {
                                        var createdPatient = await runWithOperationDialog(
                                          context: context,
                                          message: 'جارٍ الإضافة',
                                          action: () async {
                                            return await _patientService.createPatientForReception(
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
                                            createdPatient = await runWithOperationDialog(
                                              context: context,
                                              message: 'جارٍ الرفع',
                                              action: () async {
                                                await _patientService.uploadPatientImageForReception(
                                                  patientId: createdPatient.id,
                                                  imageBytes: _selectedPatientImageBytes!,
                                                  fileName: _selectedPatientImageName ??
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

                                        await _patientController.loadPatients();
                                        if (mounted) {
                                          await showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16.r),
                                              ),
                                              title: Row(
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: AppColors.success,
                                                    size: 24.sp,
                                                  ),
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
                                                style: TextStyle(
                                                  fontSize: 16.sp,
                                                  color: AppColors.textSecondary,
                                                ),
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
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      }
                                    } else {
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      try {
                                        var createdPatient = await runWithOperationDialog(
                                          context: context,
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
                                            createdPatient = await runWithOperationDialog(
                                              context: context,
                                              message: 'جارٍ الرفع',
                                              action: () async {
                                                return await _doctorService.uploadPatientImage(
                                                  patientId: createdPatient.id,
                                                  imageBytes: _selectedPatientImageBytes!,
                                                  fileName: _selectedPatientImageName ??
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

                                        if (!mounted) return;
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
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      }
                                    }
                                  },
                            borderRadius: BorderRadius.circular(16.r),
                            child: Center(
                              child: isLoading
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
                                        fontFamily: 'Expo Arabic',
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
            // Back button positioned at top left without padding
            Positioned(top: 16.h, left: 16, child: BackButtonWidget()),
          ],
        ),
      ),
    );
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
                        setState(() {
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
              if (_selectedPatientImageBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('إزالة الصورة', textAlign: TextAlign.right),
                  onTap: () {
                    Navigator.pop(context);
                    if (!mounted) return;
                    setState(() {
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

  Future<void> _pickPatientImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
      );
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
      
      if (!mounted) return;
      setState(() {
        _selectedPatientImageBytes = bytes;
        _selectedPatientImageName = fileName;
      });
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل اختيار الصورة: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
      );
    }
  }
}
