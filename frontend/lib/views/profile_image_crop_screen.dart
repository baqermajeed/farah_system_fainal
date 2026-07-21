import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';

/// شاشة قص صورة الملف الشخصي داخل Flutter (SafeArea مرتّب بدون UCrop).
class ProfileImageCropScreen extends StatefulWidget {
  const ProfileImageCropScreen({
    super.key,
    required this.imagePath,
  });

  final String imagePath;

  /// يفتح الشاشة ويعيد ملف الصورة بعد القص، أو null عند الإلغاء.
  static Future<File?> open(String imagePath) async {
    final result = await Get.to<File?>(
      () => ProfileImageCropScreen(imagePath: imagePath),
      transition: Transition.fadeIn,
      fullscreenDialog: true,
    );
    return result;
  }

  @override
  State<ProfileImageCropScreen> createState() => _ProfileImageCropScreenState();
}

class _ProfileImageCropScreenState extends State<ProfileImageCropScreen> {
  final _cropController = CropController();
  Uint8List? _imageBytes;
  bool _loading = true;
  bool _cropping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الصورة';
      });
    }
  }

  void _onCancel() {
    if (_cropping) return;
    Get.back(result: null);
  }

  void _onConfirm() {
    if (_cropping || _imageBytes == null) return;
    setState(() => _cropping = true);
    _cropController.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        try {
          final dir = await getTemporaryDirectory();
          final out = File(
            '${dir.path}/profile_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await out.writeAsBytes(croppedImage, flush: true);
          if (!mounted) return;
          Get.back(result: out);
        } catch (_) {
          if (!mounted) return;
          setState(() => _cropping = false);
          Get.snackbar('خطأ', 'فشل حفظ الصورة بعد القص');
        }
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() => _cropping = false);
        Get.snackbar('خطأ', 'فشل قص الصورة: $cause');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1720),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildCropArea()),
              _buildBottomHint(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: const BoxDecoration(
        color: AppColors.primary,
      ),
      child: Row(
        children: [
          _TopBarButton(
            icon: Icons.close_rounded,
            tooltip: 'إلغاء',
            onTap: _onCancel,
          ),
          Expanded(
            child: Text(
              'تعديل الصورة',
              textAlign: TextAlign.center,
              style: AppFonts.lamaSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          _TopBarButton(
            icon: Icons.check_rounded,
            tooltip: 'تأكيد',
            onTap: _cropping ? null : _onConfirm,
            busy: _cropping,
          ),
        ],
      ),
    );
  }

  Widget _buildCropArea() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null || _imageBytes == null) {
      return Center(
        child: Text(
          _error ?? 'لا توجد صورة',
          style: AppFonts.lamaSans(color: Colors.white70, fontSize: 14.sp),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: ColoredBox(
          color: Colors.black,
          child: Crop(
            image: _imageBytes!,
            controller: _cropController,
            onCropped: _onCropped,
            aspectRatio: 1,
            withCircleUi: false,
            baseColor: Colors.black,
            maskColor: Colors.black.withValues(alpha: 0.55),
            cornerDotBuilder: (size, _) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            interactive: true,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomHint() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
      child: Column(
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              color: const Color(0xFF1A2430),
            ),
            child: Icon(
              Icons.person_rounded,
              color: AppColors.primaryLight,
              size: 36.sp,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'حرّك الصورة داخل الإطار المربع ثم اضغط ✓',
            textAlign: TextAlign.center,
            style: AppFonts.lamaSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: SizedBox(
            width: 48.w,
            height: 48.h,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 26.sp),
            ),
          ),
        ),
      ),
    );
  }
}
