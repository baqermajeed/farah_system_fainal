import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';

class PortraitNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double aspectRatio;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final bool showSkeleton;
  final double? iconSize;
  final List<Color> gradientColors;

  const PortraitNetworkImage({
    super.key,
    this.imageUrl,
    this.aspectRatio = 3 / 4,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.showSkeleton = false,
    this.iconSize,
    this.gradientColors = const [
      AppColors.primary,
      AppColors.secondary,
    ],
  });

  Widget _buildPlaceholder(BuildContext context) {
    final placeholderContent = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          color: AppColors.white,
          size: iconSize ?? 24.sp,
        ),
      ),
    );

    if (showSkeleton) {
      return Skeletonizer(enabled: true, child: placeholderContent);
    }
    return placeholderContent;
  }

  Widget _sizedChild(Widget child) {
    if (width != null && height != null) {
      return SizedBox(width: width, height: height, child: child);
    }

    if (width != null) {
      return SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: child,
        ),
      );
    }

    if (height != null) {
      return SizedBox(
        height: height,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: child,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);
    final child = ClipRRect(
      borderRadius: borderRadius,
      child: validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl)
          ? CachedNetworkImage(
              imageUrl: validImageUrl,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              memCacheWidth: 400,
              memCacheHeight: 400,
              placeholder: (_, __) => _buildPlaceholder(context),
              errorWidget: (_, __, ___) => _buildPlaceholder(context),
            )
          : _buildPlaceholder(context),
    );

    return _sizedChild(child);
  }
}

