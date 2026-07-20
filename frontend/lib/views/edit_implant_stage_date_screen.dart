import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/custom_button.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/edit_implant_stage_date_controller.dart';

/// شاشة تعديل تاريخ مرحلة الزراعة — GetView؛ المنطق في EditImplantStageDateController.
class EditImplantStageDateScreen extends GetView<EditImplantStageDateController> {
  const EditImplantStageDateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFF),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: ui.TextDirection.ltr, // keep back button on LEFT always
          child: AppBar(
            backgroundColor: const Color(0xFFF4FEFF),
            elevation: 0,
            leading: const BackButtonWidget(),
            leadingWidth: 56.w,
            title: const Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Text(
                'تعديل تاريخ المرحلة',
              ),
            ),
            titleTextStyle: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.stageName != null) ...[
              Text(
                'المرحلة: ${controller.stageName}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 24.h),
            ],

            // اختيار التاريخ
            Text(
              'اختر التاريخ',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            Obx(
              () => GestureDetector(
                onTap: () => controller.pickDate(context),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.calendar_today, color: AppColors.primary),
                      Text(
                        controller.selectedDate.value != null
                            ? DateFormat(
                                'yyyy-MM-dd',
                                'ar',
                              ).format(controller.selectedDate.value!)
                            : 'اختر التاريخ',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: controller.selectedDate.value != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // اختيار الوقت
            Text(
              'اختر الوقت',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            Obx(
              () => GestureDetector(
                onTap: () => controller.pickTime(context),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.access_time, color: AppColors.primary),
                      Text(
                        controller.selectedTime.value ?? 'اختر الوقت',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: controller.selectedTime.value != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 32.h),

            // زر الحفظ
            Obx(
              () => CustomButton(
                text: 'حفظ التغييرات',
                onPressed:
                    controller.selectedDate.value != null &&
                        controller.selectedTime.value != null
                    ? controller.saveChanges
                    : null,
                backgroundColor: AppColors.primary,
                width: double.infinity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
