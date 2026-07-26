import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';

/// صورة ملف شخصي محسّنة للكاش — بدون إبطال الكاش عند كل فتح شاشة.
class ProfileCachedImage extends StatelessWidget {
  const ProfileCachedImage({
    super.key,
    required this.imageUrl,
    required this.size,
    this.cacheVersion = 0,
    this.fit = BoxFit.cover,
    this.circular = true,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String? imageUrl;
  final double size;
  final int cacheVersion;
  final BoxFit fit;
  final bool circular;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  static int decodeSize(double size) =>
      (size * 2).round().clamp(120, 320);

  static String? baseUrl(String? imageUrl) {
    final valid = ImageUtils.convertToValidUrl(imageUrl);
    if (valid == null || !ImageUtils.isValidImageUrl(valid)) return null;
    return valid;
  }

  static String? displayUrl(String? imageUrl, {int cacheVersion = 0}) {
    final valid = baseUrl(imageUrl);
    if (valid == null) return null;
    if (cacheVersion <= 0) return valid;
    final separator = valid.contains('?') ? '&' : '?';
    return '$valid${separator}v=$cacheVersion';
  }

  static Future<void> prefetch(
    BuildContext context,
    String? imageUrl, {
    double size = 104,
    int cacheVersion = 0,
  }) {
    final url = displayUrl(imageUrl, cacheVersion: cacheVersion);
    final key = baseUrl(imageUrl);
    if (url == null || key == null) return Future.value();

    final decode = decodeSize(size);
    return precacheImage(
      CachedNetworkImageProvider(
        url,
        cacheKey: key,
        maxWidth: decode,
        maxHeight: decode,
      ),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = baseUrl(imageUrl);
    final url = displayUrl(imageUrl, cacheVersion: cacheVersion);
    final decode = decodeSize(size);

    if (url == null || key == null) {
      return _wrapClip(
        child: ColoredBox(
          color: const Color(0xFFE8ECF0),
          child: errorWidget ?? placeholder ?? const SizedBox.shrink(),
        ),
      );
    }

    final image = CachedNetworkImage(
      imageUrl: url,
      cacheKey: key,
      width: size,
      height: size,
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      memCacheWidth: decode,
      memCacheHeight: decode,
      maxWidthDiskCache: decode,
      maxHeightDiskCache: decode,
      placeholder: (_, __) => _wrapClip(
        child: placeholder ?? const SizedBox.shrink(),
      ),
      errorWidget: (_, __, ___) => _wrapClip(
        child: errorWidget ?? placeholder ?? const SizedBox.shrink(),
      ),
    );

    return _wrapClip(child: image);
  }

  Widget _wrapClip({required Widget child}) {
    if (circular) {
      return ClipOval(
        child: SizedBox(width: size, height: size, child: child),
      );
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}
