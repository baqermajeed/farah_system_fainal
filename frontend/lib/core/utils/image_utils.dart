import '../network/api_constants.dart';

class ImageUtils {
  /// Check if image URL is valid and can be loaded by Flutter
  /// Rejects invalid schemes like 'r2-disabled://' or 'file://'
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    
    // Only allow http:// and https:// schemes
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Convert r2-disabled:// path to a valid HTTP URL
  /// Example: r2-disabled://patients/123/image.jpg -> http://baseUrl/media/patients/123/image.jpg
  static String? convertToValidUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    // If already a valid URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Convert r2-disabled:// to HTTP URL
    if (imagePath.startsWith('r2-disabled://')) {
      // Remove the r2-disabled:// prefix
      final path = imagePath.replaceFirst('r2-disabled://', '');
      // Construct full URL (assuming backend serves media from /media endpoint)
      return '${ApiConstants.baseUrl}/media/$path';
    }

    // If it's a relative path, assume it's under /media
    if (!imagePath.startsWith('/')) {
      return '${ApiConstants.baseUrl}/media/$imagePath';
    }

    return '${ApiConstants.baseUrl}$imagePath';
  }
}
