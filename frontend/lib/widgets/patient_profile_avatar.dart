import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:farah_sys_final/core/utils/image_utils.dart';

/// Avatar for patient profile cards — gradient container with a polished
/// placeholder when no photo is available.
class PatientProfileAvatar extends StatelessWidget {
  const PatientProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 56,
  });

  final String? imageUrl;
  final double size;

  static const Color _gradientStart = Color(0xFF162D4A);
  static const Color _gradientEnd = Color(0xFF4A88B8);

  @override
  Widget build(BuildContext context) {
    final validUrl = ImageUtils.convertToValidUrl(imageUrl);
    final hasImage = validUrl != null && ImageUtils.isValidImageUrl(validUrl);
    final dimension = size.w;
    final radius = dimension * 0.26;

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [_gradientStart, _gradientEnd],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _gradientEnd.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: validUrl,
                fit: BoxFit.cover,
                width: dimension,
                height: dimension,
                fadeInDuration: const Duration(milliseconds: 200),
                memCacheWidth: 200,
                memCacheHeight: 200,
                placeholder: (_, __) => _PatientAvatarPlaceholder(size: dimension),
                errorWidget: (_, __, ___) =>
                    _PatientAvatarPlaceholder(size: dimension),
              )
            : _PatientAvatarPlaceholder(size: dimension),
      ),
    );
  }
}

class _PatientAvatarPlaceholder extends StatelessWidget {
  const _PatientAvatarPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final innerSize = size * 0.62;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 0.78,
          height: size * 0.78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: innerSize * 0.52,
          ),
        ),
      ],
    );
  }
}
