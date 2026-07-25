class DateTimeUtils {
  DateTimeUtils._();

  /// Parses API datetime strings as UTC and converts them to local time.
  static DateTime? parseApiToLocal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      var timeString = raw.trim();

      if (timeString.contains('+00:00')) {
        timeString = timeString.replaceAll('+00:00', 'Z');
      } else if (timeString.contains('-00:00')) {
        timeString = timeString.replaceAll('-00:00', 'Z');
      } else if (timeString.contains('+') && !timeString.endsWith('Z')) {
        final timezoneIndex = timeString.indexOf('+');
        timeString = '${timeString.substring(0, timezoneIndex)}Z';
      } else if (!timeString.endsWith('Z') &&
          !timeString.contains('+') &&
          !timeString.contains('-', 10)) {
        timeString = '${timeString}Z';
      }

      return DateTime.parse(timeString).toLocal();
    } catch (_) {
      return null;
    }
  }
}
