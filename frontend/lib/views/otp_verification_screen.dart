import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/otp_verification_controller.dart';

class _OtpAssets {
  static const back = 'assets/icon/backblack.png';
}

/// شاشة OTP — GetView؛ المنطق في OtpVerificationController.
class OtpVerificationScreen extends GetView<OtpVerificationController> {
  const OtpVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        children: [
                          SizedBox(height: 56.h),
                          SizedBox(height: 12.h),
                          Image.asset(
                            'assets/images/logo.png',
                            width: 120.w,
                            height: 120.h,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 120.w,
                                height: 120.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.local_hospital,
                                  size: 60.sp,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 24.h),
                          Obx(
                            () => Text(
                              c.formatTime(c.remainingSeconds.value),
                              style: TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: 48.sp,
                                fontWeight: FontWeight.bold,
                                color: OtpVerificationController.otpNumberColor,
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'يرجى إدخال رمز التحقق الذي أرسلناه إلى هاتفك الخاص',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              fontSize: 16.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 32.h),
                          Obx(() {
                            c.otpUiTick.value; // rebuild trigger
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final gap = 8.w;
                                final available = constraints.maxWidth -
                                    gap * (OtpVerificationController.otpLength - 1);
                                final boxSize =
                                    (available / OtpVerificationController.otpLength)
                                        .clamp(44.0, 50.0);

                                final otps = <Widget>[];
                                for (int index = 0;
                                    index < OtpVerificationController.otpLength;
                                    index++) {
                                  if (index > 0) {
                                    otps.add(SizedBox(width: gap));
                                  }
                                  final reversedIndex =
                                      (OtpVerificationController.otpLength - 1) -
                                          index;
                                  final filled = c.otpControllers[reversedIndex]
                                      .text
                                      .isNotEmpty;
                                  otps.add(
                                    SizedBox(
                                      width: boxSize,
                                      height: boxSize,
                                      child: TextField(
                                        controller:
                                            c.otpControllers[reversedIndex],
                                        focusNode:
                                            c.otpFocusNodes[reversedIndex],
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        maxLength: 1,
                                        readOnly: true,
                                        showCursor: false,
                                        enableInteractiveSelection: false,
                                        style: TextStyle(
                                          fontFamily: AppFonts.family,
                                          fontSize: 22.sp,
                                          fontWeight: FontWeight.bold,
                                          color: filled
                                              ? Colors.white
                                              : OtpVerificationController
                                                  .otpNumberColor,
                                        ),
                                        decoration: InputDecoration(
                                          counterText: '',
                                          filled: true,
                                          fillColor: filled
                                              ? OtpVerificationController
                                                  .otpNumberColor
                                              : Colors.transparent,
                                          contentPadding: EdgeInsets.zero,
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                            borderSide: BorderSide(
                                              color: filled
                                                  ? OtpVerificationController
                                                      .otpNumberColor
                                                  : AppColors.primaryLight
                                                      .withValues(alpha: 0.5),
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                            borderSide: BorderSide(
                                              color: filled
                                                  ? OtpVerificationController
                                                      .otpNumberColor
                                                  : AppColors.primaryLight
                                                      .withValues(alpha: 0.5),
                                              width: 2,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                            borderSide: const BorderSide(
                                              color: OtpVerificationController
                                                  .otpNumberColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onChanged: (value) => c.onOtpChanged(
                                          reversedIndex,
                                          value,
                                        ),
                                        onTap: () {
                                          c.otpFocusNodes[reversedIndex]
                                              .requestFocus();
                                        },
                                      ),
                                    ),
                                  );
                                }
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: otps,
                                );
                              },
                            );
                          }),
                          SizedBox(height: 24.h),
                          Obx(
                            () => GestureDetector(
                              onTap: c.remainingSeconds.value == 0
                                  ? c.resendCode
                                  : null,
                              child: Text(
                                'إعادة إرسال الكود',
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  fontSize: 16.sp,
                                  color: c.remainingSeconds.value == 0
                                      ? OtpVerificationController.otpNumberColor
                                      : AppColors.textSecondary
                                          .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        textDirection: TextDirection.rtl,
                        children: ['3', '2', '1']
                            .map((d) => _KeypadButton(number: d, onTap: c.onKeypadPressed))
                            .toList(),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        textDirection: TextDirection.rtl,
                        children: ['6', '5', '4']
                            .map((d) => _KeypadButton(number: d, onTap: c.onKeypadPressed))
                            .toList(),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        textDirection: TextDirection.rtl,
                        children: ['9', '8', '7']
                            .map((d) => _KeypadButton(number: d, onTap: c.onKeypadPressed))
                            .toList(),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        textDirection: TextDirection.rtl,
                        children: [
                          _BackspaceButton(onTap: c.onBackspacePressed),
                          SizedBox(width: 60.w),
                          _KeypadButton(number: '0', onTap: c.onKeypadPressed),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 16.h,
              left: 16,
              child: const BackButtonWidget(assetPath: _OtpAssets.back),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.number, required this.onTap});

  final String number;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(number),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: 60.w,
          height: 60.h,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 28.sp,
                fontWeight: FontWeight.w600,
                color: OtpVerificationController.otpNumberColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  const _BackspaceButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: 60.w,
          height: 60.h,
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              size: 24.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
