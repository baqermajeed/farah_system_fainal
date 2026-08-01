import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';

class CustomTextField extends StatefulWidget {
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
  final Color? focusColor;

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
    this.focusColor,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscureText = widget.obscureText;
    }
  }

  bool get _hasError => widget.errorText != null;

  Color get _focusColor => widget.focusColor ?? AppColors.primary;

  Widget? _buildSuffixIcon() {
    if (_hasError && widget.showErrorIcon) {
      return Icon(
        Icons.error_outline_rounded,
        color: AppColors.error,
        size: 22.sp,
      );
    }
    if (widget.obscureText && widget.suffixIcon == null) {
      return IconButton(
        icon: Icon(
          _obscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: AppColors.textSecondary,
          size: 22.sp,
        ),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      );
    }
    return widget.suffixIcon;
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16.r);
    final normalBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: Color(0xFFDCE8EF), width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: _focusColor, width: 2),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.error, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: _hasError ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: (_hasError ? AppColors.error : const Color(0xFF64748B))
                    .withValues(alpha: _hasError ? 0.14 : 0.07),
                blurRadius: _hasError ? 10 : 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            obscureText: _obscureText,
            validator: widget.validator,
            onChanged: widget.onChanged,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            maxLines: widget.maxLines,
            textAlign: widget.textAlign,
            textDirection: TextDirection.rtl,
            focusNode: widget.focusNode,
            maxLength: widget.maxLength,
            style: TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintTextDirection: TextDirection.rtl,
              hintStyle: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textHint,
              ),
              filled: true,
              fillColor: _hasError
                  ? AppColors.error.withValues(alpha: 0.04)
                  : AppColors.white,
              prefixIcon: widget.prefixIcon,
              prefixIconConstraints: BoxConstraints(minWidth: 48.w),
              suffixIcon: _buildSuffixIcon(),
              errorText: _hasError
                  ? (widget.errorText!.isEmpty ? ' ' : widget.errorText)
                  : null,
              errorStyle: widget.errorText != null && widget.errorText!.isEmpty
                  ? const TextStyle(height: 0, fontSize: 0)
                  : TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
                    ),
              counterText: widget.maxLength != null ? '' : null,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              enabledBorder: _hasError ? errorBorder : normalBorder,
              focusedBorder: _hasError ? errorBorder : focusedBorder,
              border: _hasError ? errorBorder : normalBorder,
              errorBorder: errorBorder,
              focusedErrorBorder: errorBorder,
            ),
          ),
        ),
        if (_hasError && widget.errorText!.isNotEmpty) ...[
          SizedBox(height: 6.h),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14.sp,
                color: AppColors.error,
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  widget.errorText!,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.error,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
