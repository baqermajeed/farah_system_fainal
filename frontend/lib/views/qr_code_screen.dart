import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/custom_button.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

class QrCodeScreen extends StatelessWidget {
  final String patientId;
  final String patientName;
  final String qrCodeData;

  const QrCodeScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.qrCodeData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  const BackButtonWidget(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'رمز QR الخاص بك',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Patient Info Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24.w),
                        margin: EdgeInsets.only(bottom: 32.h),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              AppColors.primary,
                              AppColors.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'الرقم التعريفي',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              patientId,
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Divider(
                              color: AppColors.white.withValues(alpha: 0.3),
                              height: 1,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              patientName,
                              style: TextStyle(
                                fontSize: 18.sp,
                                color: AppColors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // QR Code Container
                      Container(
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.divider,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: qrCodeData.isNotEmpty ? qrCodeData : patientId,
                          version: QrVersions.auto,
                          size: 250.w,
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.textPrimary,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        'يمكن للطبيب مسح هذا الرمز للوصول إلى ملفك الشخصي',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 32.h),
                      CustomButton(
                        text: 'إغلاق',
                        onPressed: () => Get.back(),
                        width: double.infinity,
                        backgroundColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

