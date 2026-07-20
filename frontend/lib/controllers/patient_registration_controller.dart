import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/constants/iraq_governorates.dart';
import 'auth_controller.dart';

/// Controller لشاشة تسجيل حساب المريض.
class PatientRegistrationController extends GetxController {
  final AuthController authController = Get.find<AuthController>();

  final nameController = TextEditingController();
  final ageController = TextEditingController();

  final Rxn<String> selectedGender = Rxn<String>();
  final Rxn<String> selectedCity = Rxn<String>();

  String phoneNumber = '';

  List<String> get cities => IraqGovernorates.arabicNames;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    phoneNumber = args?['phoneNumber'] ?? '';
  }

  Future<void> submit() async {
    if (nameController.text.isEmpty ||
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

    // تحويل الجنس من 'ذكر'/'أنثى' إلى 'male'/'female'
    String? genderValue;
    if (selectedGender.value == AppStrings.male) {
      genderValue = 'male';
    } else if (selectedGender.value == AppStrings.female) {
      genderValue = 'female';
    }

    // إنشاء الحساب
    await authController.createPatientAccount(
      phoneNumber: phoneNumber,
      name: nameController.text.trim(),
      gender: genderValue,
      age: age,
      city: selectedCity.value!,
    );
  }

  void showCityPicker(BuildContext context) {
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
                    selectedCity.value = city;
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

  @override
  void onClose() {
    nameController.dispose();
    ageController.dispose();
    super.onClose();
  }
}
