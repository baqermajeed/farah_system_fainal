import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';

class CustomTextField extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final int? maxLines;
  final TextAlign textAlign;
  final FocusNode? focusNode;
  final int? maxLength;
  final String? errorText;
  final bool showErrorIcon;

  const CustomTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.textAlign = TextAlign.right,
    this.focusNode,
    this.maxLength,
    this.errorText,
    this.showErrorIcon = true,
  });

  bool get _hasError => errorText != null;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16.r);
    final errorBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.error, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (labelText != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              labelText!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: _hasError ? AppColors.error : AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 8.h),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          textAlign: textAlign,
          textDirection: TextDirection.rtl,
          focusNode: focusNode,
          maxLength: maxLength,
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 14.sp,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintTextDirection: TextDirection.rtl,
            prefixIcon: prefixIcon,
            suffixIcon: _hasError && showErrorIcon
                ? Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 22.sp,
                  )
                : suffixIcon,
            // سلسلة فارغة = حدود/أيقونة خطأ بدون نص (للرسائل المشتركة تحت حقل آخر)
            errorText: _hasError
                ? (errorText!.isEmpty ? ' ' : errorText)
                : null,
            errorStyle: errorText != null && errorText!.isEmpty
                ? const TextStyle(height: 0, fontSize: 0)
                : TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.error,
                  ),
            counterText: maxLength != null ? '' : null,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            enabledBorder: _hasError ? errorBorder : null,
            focusedBorder: _hasError ? errorBorder : null,
            border: _hasError ? errorBorder : null,
            errorBorder: errorBorder,
            focusedErrorBorder: errorBorder,
          ),
        ),
      ],
    );
  }
}
