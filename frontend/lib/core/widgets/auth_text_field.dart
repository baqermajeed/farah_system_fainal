import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';

/// حقل إدخال كبسولي لصفحات المصادقة — نفس سلوك Art-Inspiration.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.hint,
    this.controller,
    this.icon = Icons.person_outline,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.errorText,
    this.showErrorBorder = false,
    this.focusColor = const Color(0xFF032252),
  });

  final String hint;
  final TextEditingController? controller;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final String? errorText;
  final bool showErrorBorder;
  final Color focusColor;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  bool get _hasError =>
      widget.showErrorBorder ||
      (widget.errorText != null && widget.errorText!.isNotEmpty);

  TextStyle _fieldStyle({Color? color}) {
    return TextStyle(
      fontFamily: AppFonts.family,
      fontSize: 15.sp,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.textSecondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = 28.r;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final errorSide = BorderSide(color: AppColors.error, width: 1.2);
    final focusedErrorSide = BorderSide(color: AppColors.error, width: 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          textDirection: TextDirection.rtl,
          cursorColor: widget.focusColor,
          style: _fieldStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintTextDirection: TextDirection.rtl,
            hintStyle: _fieldStyle(),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 18.h,
            ),
            prefixIcon: Icon(
              widget.icon,
              color: AppColors.textSecondary,
              size: 22.sp,
            ),
            suffixIcon: widget.suffix ??
                (widget.obscureText
                    ? IconButton(
                        onPressed: () =>
                            setState(() => _obscured = !_obscured),
                        icon: Icon(
                          _obscured
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                          size: 22.sp,
                        ),
                      )
                    : null),
            enabledBorder: fieldBorder.copyWith(
              borderSide: _hasError
                  ? errorSide
                  : const BorderSide(color: AppColors.dotGrid, width: 1.2),
            ),
            focusedBorder: fieldBorder.copyWith(
              borderSide: _hasError
                  ? focusedErrorSide
                  : BorderSide(color: widget.focusColor, width: 1.5),
            ),
            errorBorder: fieldBorder.copyWith(borderSide: errorSide),
            focusedErrorBorder:
                fieldBorder.copyWith(borderSide: focusedErrorSide),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),
        if (_hasError &&
            widget.errorText != null &&
            widget.errorText!.isNotEmpty)
          _AuthFieldErrorHint(message: widget.errorText!),
      ],
    );
  }
}

class _AuthFieldErrorHint extends StatelessWidget {
  const _AuthFieldErrorHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, right: 10.w, left: 10.w),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 16.w,
            height: 16.w,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppColors.white,
              size: 11.sp,
            ),
          ),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              message.startsWith('!') ? message : '! $message',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
