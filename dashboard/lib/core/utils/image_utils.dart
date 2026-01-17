import '../config/app_config.dart';

class ImageUtils {
  /// Convert backend returned image paths into a valid URL.
  /// - `http(s)://...` stays as-is
  /// - `/media/...` becomes `${baseUrl}/media/...`
  /// - `r2-disabled://...` becomes `${baseUrl}/media/...`
  static String? convertToValidUrl(String? imageUrl) {
    if (imageUrl == null) return null;
    final v = imageUrl.trim();
    if (v.isEmpty) return null;

    if (v.startsWith('http://') || v.startsWith('https://')) return v;

    if (v.startsWith('r2-disabled://')) {
      final key = v.replaceFirst('r2-disabled://', '');
      return _join(AppConfig.apiBaseUrl, '/media/$key');
    }

    if (v.startsWith('/media/')) {
      return _join(AppConfig.apiBaseUrl, v);
    }

    if (v.startsWith('media/')) {
      return _join(AppConfig.apiBaseUrl, '/$v');
    }

    // Unknown path; return as-is (might still work on web)
    return v;
  }

  static String _join(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }
}


