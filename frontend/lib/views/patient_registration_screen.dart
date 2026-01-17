import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/widgets/custom_text_field.dart';
import 'package:farah_sys_final/core/widgets/gender_selector.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';

class PatientRegistrationScreen extends StatefulWidget {
  final String phoneNumber;

  const PatientRegistrationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<PatientRegistrationScreen> createState() => _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? selectedGender;
  String? selectedCity;

  final List<String> cities = [
    'بغداد',
    'البصرة',
    'النجف الاشرف',
    'كربلاء',
    'الموصل',
    'أربيل',
    'السليمانية',
  ];

  @override
  void dispose() {
    _nameController.dispose();
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
                    // Logo
                    Image.asset(
                      'assets/images/logo.png',
                      width: 140.w,
                      height: 140.h,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 140.w,
                          height: 140.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryLight.withValues(alpha: 0.3),
                          ),
                          child: Icon(
                            Icons.local_hospital,
                            size: 70.sp,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16.h),
                    // Title
                    Text(
                      'إنشاء حساب',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'يرجى إكمال البيانات التالية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textHint,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    CustomTextField(
                      labelText: AppStrings.name,
                      hintText: AppStrings.enterYourName,
                      controller: _nameController,
                    ),
                    SizedBox(height: 36.h),
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
                    SizedBox(height: 36.h),
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
                    SizedBox(height: 75.h),
                    // Register button
                    Obx(
                      () => Container(
                        width: double.infinity,
                        height: 50.h,
                        decoration: BoxDecoration(
                          color: _authController.isLoading.value
                              ? AppColors.textHint
                              : AppColors.secondary,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _authController.isLoading.value
                                ? null
                                : () async {
                                    if (_nameController.text.isEmpty ||
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

                                    // تحويل الجنس من 'ذكر'/'أنثى' إلى 'male'/'female'
                                    String? genderValue;
                                    if (selectedGender == AppStrings.male) {
                                      genderValue = 'male';
                                    } else if (selectedGender == AppStrings.female) {
                                      genderValue = 'female';
                                    }

                                    // إنشاء الحساب
                                    await _authController.createPatientAccount(
                                      phoneNumber: widget.phoneNumber,
                                      name: _nameController.text.trim(),
                                      gender: genderValue,
                                      age: age,
                                      city: selectedCity!,
                                    );
                                  },
                            borderRadius: BorderRadius.circular(16.r),
                            child: Center(
                              child: _authController.isLoading.value
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
                                      'إنشاء حساب',
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
                      ),
                    ),
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
      builder: (context) {
        return Container(
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
              ...cities.map((city) {
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
              }),
            ],
          ),
        );
      },
    );
  }
}

