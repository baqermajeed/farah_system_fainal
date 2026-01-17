class AppConfig {
  static const String _defaultBaseUrl = 'https://sys-api.farahdent.com';

  static String get apiBaseUrl {
    final baseUrlOverride =
        String.fromEnvironment('API_BASE_URL', defaultValue: '').trim();
    if (baseUrlOverride.isNotEmpty) {
      return baseUrlOverride;
    }

    final hostOverride =
        String.fromEnvironment('API_HOST', defaultValue: '').trim();
    if (hostOverride.isNotEmpty) {
      if (hostOverride.startsWith('http://') ||
          hostOverride.startsWith('https://')) {
        return hostOverride;
      }
      return 'https://$hostOverride';
    }

    return _defaultBaseUrl;
  }
}