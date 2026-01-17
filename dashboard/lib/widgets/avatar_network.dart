import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/image_utils.dart';

class AvatarNetwork extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double radius;

  const AvatarNetwork({
    super.key,
    required this.imageUrl,
    this.size = 52,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final url = ImageUtils.convertToValidUrl(imageUrl);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url == null)
          ? const Icon(Icons.person, color: AppColors.primary)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: AppColors.primary),
            ),
    );
  }
}


