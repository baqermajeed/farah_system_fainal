import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/qr_scanner_controller.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

/// شاشة مسح رمز QR — GetView؛ المنطق في QrScannerController.
class QrScannerScreen extends GetView<QrScannerController> {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Scanner View
            MobileScanner(
              controller: controller.scannerController,
              onDetect: controller.handleBarcode,
            ),
            // Overlay
            _buildOverlay(),
            // Header
            _buildHeader(),
            // Scanning area indicator
            _buildScanningArea(),
            // Instructions
            _buildInstructions(),
            // Flashlight toggle
            _buildFlashlightButton(),
          ],
        ),
      ),
    );
  }

  /// بناء overlay
  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.5),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.5),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  /// بناء header
  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            const BackButtonWidget(),
            Expanded(
              child: Center(
                child: Text(
                  'مسح رمز QR',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 48.w),
          ],
        ),
      ),
    );
  }

  /// بناء scanning area indicator
  Widget _buildScanningArea() {
    return Center(
      child: Container(
        width: 250.w,
        height: 250.h,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primary,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Stack(
          children: [
            _buildCornerIndicator(top: true, left: true),
            _buildCornerIndicator(top: true, left: false),
            _buildCornerIndicator(top: false, left: true),
            _buildCornerIndicator(top: false, left: false),
          ],
        ),
      ),
    );
  }

  /// بناء corner indicator
  Widget _buildCornerIndicator({required bool top, required bool left}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 30.w,
        height: 30.h,
        decoration: BoxDecoration(
          border: Border(
            top: top ? BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            bottom: top ? BorderSide.none : BorderSide(color: AppColors.primary, width: 4),
            left: left ? BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            right: left ? BorderSide.none : BorderSide(color: AppColors.primary, width: 4),
          ),
          borderRadius: BorderRadius.only(
            topLeft: (top && left) ? Radius.circular(20.r) : Radius.zero,
            topRight: (top && !left) ? Radius.circular(20.r) : Radius.zero,
            bottomLeft: (!top && left) ? Radius.circular(20.r) : Radius.zero,
            bottomRight: (!top && !left) ? Radius.circular(20.r) : Radius.zero,
          ),
        ),
      ),
    );
  }

  /// بناء instructions card
  Widget _buildInstructions() {
    return Positioned(
      bottom: 100.h,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner,
                color: AppColors.primary,
                size: 32.sp,
              ),
              SizedBox(height: 8.h),
              Text(
                'ضع رمز QR داخل الإطار',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'سيتم مسح الرمز تلقائياً',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء flashlight button
  Widget _buildFlashlightButton() {
    return Positioned(
      bottom: 40.h,
      right: 24.w,
      child: GestureDetector(
        onTap: () => controller.scannerController.toggleTorch(),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.flashlight_on,
            color: AppColors.primary,
            size: 28.sp,
          ),
        ),
      ),
    );
  }
}
