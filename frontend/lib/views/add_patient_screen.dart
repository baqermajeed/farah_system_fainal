import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/widgets/custom_text_field.dart';
import 'package:farah_sys_final/core/widgets/gender_selector.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/add_patient_controller.dart';

/// شاشة إضافة مريض — GetView؛ المنطق في AddPatientController.
class AddPatientScreen extends GetView<AddPatientController> {
  const AddPatientScreen({super.key});

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
                      onTap: () => controller.showPatientImagePicker(context),
                      child: Obx(
                        () => Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 60.r,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage:
                                  controller.selectedPatientImageBytes.value !=
                                      null
                                  ? MemoryImage(
                                      controller
                                          .selectedPatientImageBytes
                                          .value!,
                                    )
                                  : null,
                              child:
                                  controller.selectedPatientImageBytes.value ==
                                      null
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
                      controller: controller.nameController,
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
                        Obx(
                          () => GenderSelector(
                            selectedGender: controller.selectedGender.value,
                            onGenderChanged: (gender) {
                              controller.selectedGender.value = gender;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    CustomTextField(
                      labelText: AppStrings.phoneNumber,
                      hintText: '0000 000 0000',
                      controller: controller.phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      children: [
                        Expanded(
                          child: Obx(
                            () => CustomTextField(
                              labelText: AppStrings.city,
                              hintText: AppStrings.selectCity,
                              readOnly: true,
                              onTap: () => controller.showCityPicker(context),
                              controller: TextEditingController(
                                text: controller.selectedCity.value ?? '',
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: CustomTextField(
                            labelText: AppStrings.age,
                            hintText: AppStrings.selectCity,
                            controller: controller.ageController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    // Add button (without icon)
                    Obx(() {
                      final isLoading =
                          controller.authController.isLoading.value ||
                          controller.isLoading.value;

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
                                : () => controller.submit(context),
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
                                        fontFamily: AppFonts.family,
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
}
