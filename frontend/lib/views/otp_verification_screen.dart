import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final AuthController _authController = Get.find<AuthController>();
  static const int _otpLength = 6;
  final List<TextEditingController> _otpControllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(_otpLength, (_) => FocusNode());
  Timer? _timer;
  int _remainingSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel(); // Cancel existing timer if any
    setState(() {
      _remainingSeconds = 60; // Reset to 60 seconds
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          timer.cancel();
          setState(() {}); // Update UI when timer reaches 0
        }
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < _otpControllers.length - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    _verifyOtp();
  }

  void _verifyOtp() {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length == _otpLength) {
      _authController.verifyOtpAndLogin(
        phoneNumber: widget.phoneNumber,
        code: otp,
      );
    }
  }

  void _onKeypadPressed(String value) {
    for (int i = 0; i < _otpControllers.length; i++) {
      if (_otpControllers[i].text.isEmpty) {
        _otpControllers[i].text = value;
        _onOtpChanged(i, value);
        break;
      }
    }
  }

  void _onBackspacePressed() {
    for (int i = _otpControllers.length - 1; i >= 0; i--) {
      if (_otpControllers[i].text.isNotEmpty) {
        _otpControllers[i].clear();
        _otpFocusNodes[i].requestFocus();
        break;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Top section with logo and OTP fields
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        children: [
                          SizedBox(height: 56.h),
                          SizedBox(height: 12.h),
                          // Logo
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
                          // Timer
                          Text(
                            _formatTime(_remainingSeconds),
                            style: TextStyle(
                              fontFamily: 'Expo Arabic',
                              fontSize: 48.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          // Instruction text
                          Text(
                            'يرجى إدخال رمز التحقق الذي أرسلناه إلى هاتفك الخاص',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'Expo Arabic',
                              fontSize: 16.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 32.h),
                          // OTP Input Fields
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Make the 6 boxes responsive to avoid overflow on small devices.
                              final gap = 8.w;
                              final available =
                                  constraints.maxWidth - gap * (_otpLength - 1);
                              final boxSize =
                                  (available / _otpLength).clamp(44.0, 50.0);

                              final otps = <Widget>[];
                              for (int index = 0; index < _otpLength; index++) {
                                if (index > 0) {
                                  otps.add(SizedBox(width: gap));
                                }

                                final reversedIndex =
                                    (_otpLength - 1) - index; // RTL

                                otps.add(
                                  SizedBox(
                                    width: boxSize,
                                    height: boxSize,
                                    child: TextField(
                                      controller: _otpControllers[reversedIndex],
                                      focusNode: _otpFocusNodes[reversedIndex],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: 1,
                                      readOnly: true,
                                      showCursor: false,
                                      enableInteractiveSelection: false,
                                      style: TextStyle(
                                        fontSize: 22.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor:
                                            _otpControllers[reversedIndex]
                                                    .text
                                                    .isNotEmpty
                                                ? AppColors.secondary
                                                : Colors.transparent,
                                        contentPadding: EdgeInsets.zero,
                                        isDense: true,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          borderSide: BorderSide(
                                            color:
                                                _otpControllers[reversedIndex]
                                                        .text
                                                        .isNotEmpty
                                                    ? AppColors.secondary
                                                    : AppColors.primaryLight
                                                        .withValues(alpha: 0.5),
                                            width: 2,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          borderSide: BorderSide(
                                            color:
                                                _otpControllers[reversedIndex]
                                                        .text
                                                        .isNotEmpty
                                                    ? AppColors.secondary
                                                    : AppColors.primaryLight
                                                        .withValues(alpha: 0.5),
                                            width: 2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          borderSide: BorderSide(
                                            color: AppColors.secondary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) =>
                                          _onOtpChanged(reversedIndex, value),
                                      onTap: () {
                                        _otpFocusNodes[reversedIndex]
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
                          ),
                          SizedBox(height: 24.h),
                          // Resend code link
                          GestureDetector(
                            onTap: _remainingSeconds == 0
                                ? () async {
                                    _startTimer(); // Start timer immediately
                                    await _authController.requestOtp(widget.phoneNumber);
                                  }
                                : null,
                            child: Text(
                              'إعادة إرسال الكود',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Expo Arabic',
                                fontSize: 16.sp,
                                color: _remainingSeconds == 0
                                    ? AppColors.secondary
                                    : AppColors.textSecondary.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Numeric Keypad
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                  child: Column(
                    children: [
                      // Row 1: 3, 2, 1 (RTL)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        textDirection: TextDirection.rtl,
                        children: ['3', '2', '1'].map((digit) {
                          return _buildKeypadButton(digit);
                        }).toList(),
                      ),
                      SizedBox(height: 16.h),
                      // Row 2: 6, 5, 4 (RTL)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        textDirection: TextDirection.rtl,
                        children: ['6', '5', '4'].map((digit) {
                          return _buildKeypadButton(digit);
                        }).toList(),
                      ),
                      SizedBox(height: 16.h),
                      // Row 3: 9, 8, 7 (RTL)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        textDirection: TextDirection.rtl,
                        children: ['9', '8', '7'].map((digit) {
                          return _buildKeypadButton(digit);
                        }).toList(),
                      ),
                      SizedBox(height: 16.h),
                      // Row 4: backspace, 0 (RTL)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        textDirection: TextDirection.rtl,
                        children: [
                          _buildBackspaceButton(),
                          SizedBox(width: 60.w),
                          _buildKeypadButton('0'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Back button
            Positioned(top: 16.h, left: 16, child: BackButtonWidget()),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeypadPressed(number),
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
                fontSize: 28.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onBackspacePressed,
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

