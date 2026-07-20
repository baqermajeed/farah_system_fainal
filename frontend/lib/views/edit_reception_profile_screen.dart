import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/widgets/custom_button.dart';
import 'package:farah_sys_final/core/widgets/custom_text_field.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/edit_reception_profile_controller.dart';

/// شاشة تعديل الملف الشخصي لموظف الاستقبال — GetView؛ المنطق في EditReceptionProfileController.
class EditReceptionProfileScreen extends GetView<EditReceptionProfileController> {
  const EditReceptionProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            children: [
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  // Back button always on the LEFT
                  const BackButtonWidget(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'تعديل الملف الشخصي',
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
              SizedBox(height: 32.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 8.h),
                  CustomTextField(
                    controller: controller.nameController,
                    hintText: 'أدخل الاسم',
                    textAlign: TextAlign.right,
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    AppStrings.phoneNumber,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 8.h),
                  CustomTextField(
                    controller: controller.phoneController,
                    hintText: 'أدخل رقم الهاتف',
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              SizedBox(height: 48.h),
              Obx(
                () => CustomButton(
                  text: 'حفظ التغييرات',
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.saveChanges,
                  width: double.infinity,
                  isLoading: controller.isLoading.value,
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
