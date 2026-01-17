import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/image_utils.dart';

/// Reusable avatar widget that keeps remote images cropped (BoxFit.cover)
/// and prevents any stretching even when loaded into rectangular boxes.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.width = 60.0,
    this.height = 60.0,
    this.size,
    this.cornerRadius = 12.0,
    this.shape = BoxShape.rectangle,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
    this.backgroundColor = Colors.white,
    this.placeholderIcon = Icons.person,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double cornerRadius;
  final BoxShape shape;
  final Color borderColor;
  final double borderWidth;
  final Color backgroundColor;
  final IconData placeholderIcon;
  final double? size;

  double get _size => size ?? max(width, height);

  Widget _buildPlaceholder() {
    final iconSize = min(width, height) * 0.45;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(cornerRadius),
        shape: shape,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Icon(
        placeholderIcon,
        color: AppColors.white,
        size: iconSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validUrl = ImageUtils.convertToValidUrl(imageUrl);
    final hasImage = validUrl != null && ImageUtils.isValidImageUrl(validUrl);

    final child = hasImage
        ? CachedNetworkImage(
            imageUrl: validUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            memCacheWidth: (max(width, height) * 2).round(),
            memCacheHeight: (max(width, height) * 2).round(),
            placeholder: (context, url) => _buildPlaceholder(),
            errorWidget: (context, url, error) => _buildPlaceholder(),
          )
        : _buildPlaceholder();

    return Container(
      width: _size,
      height: _size,
      decoration: shape == BoxShape.circle
          ? BoxDecoration(
              shape: shape,
              border: Border.all(color: borderColor, width: borderWidth),
              color: backgroundColor,
            )
          : BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(cornerRadius),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
      clipBehavior: Clip.hardEdge,
      child: shape == BoxShape.circle
          ? ClipOval(child: child)
          : ClipRRect(
              borderRadius: BorderRadius.circular(cornerRadius),
              child: child,
            ),
    );
  }
}

