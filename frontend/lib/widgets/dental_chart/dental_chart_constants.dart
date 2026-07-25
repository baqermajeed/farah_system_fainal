import 'package:flutter/material.dart';

class DentalChartConstants {
  DentalChartConstants._();

  static const List<String> upperTeethFdi = [
    '18', '17', '16', '15', '14', '13', '12', '11',
    '21', '22', '23', '24', '25', '26', '27', '28',
  ];

  static const List<String> lowerTeethFdi = [
    '48', '47', '46', '45', '44', '43', '42', '41',
    '31', '32', '33', '34', '35', '36', '37', '38',
  ];

  static const List<String> dentalStatuses = [
    'زراعة',
    'قلع',
    'مفقود',
    'تاج',
    'حشوة',
    'جسر',
    'قص لثة',
    'فينير',
    'ابتسامة',
    'تسوس',
  ];

  static const String smileStatus = 'ابتسامة';

  static const List<String> smileJawSubs = ['فك علوي', 'فك سفلي'];

  static const Map<String, List<String>> dentalSubStatuses = {
    'حشوة': [
      'حشوة تجميلية',
      'حشوة جذر',
      'حشوة معدنية',
      'حشوة مختبرية',
    ],
    'تاج': ['زركون', 'سيراميك', 'اي ماكس'],
    'ابتسامة': ['فك علوي', 'فك سفلي'],
  };

  static Color statusColor(String status) {
    switch (status) {
      case 'زراعة':
        return const Color(0xFF12B2D7);
      case 'قلع':
        return const Color(0xFFC0392B);
      case 'مفقود':
        return const Color(0xFF636B75);
      case 'تاج':
        return const Color(0xFF4CA7FF);
      case 'حشوة':
        return const Color(0xFFE6B91F);
      case 'جسر':
        return const Color(0xFF1CB7D8);
      case 'قص لثة':
        return const Color(0xFFE25555);
      case 'فينير':
        return const Color(0xFF9A7CF2);
      case 'ابتسامة':
        return const Color(0xFFC9B896);
      case 'تسوس':
        return const Color(0xFF3A3F46);
      default:
        return const Color(0xFF8C95A3);
    }
  }

  static String statusToken(String status, [String? subStatus]) {
    if (subStatus == null || subStatus.isEmpty) return status;
    return '$status::$subStatus';
  }

  static bool hasStatus(Set<String> statuses, String status) {
    if (statuses.contains(status)) return true;
    final prefix = '$status::';
    return statuses.any((entry) => entry.startsWith(prefix));
  }

  static void removeStatusWithSubs(Set<String> statuses, String status) {
    statuses.remove(status);
    final prefix = '$status::';
    statuses.removeWhere((entry) => entry.startsWith(prefix));
  }

  static bool isSmileStatus(String token) {
    return token == smileStatus || token.startsWith('$smileStatus::');
  }

  static List<String> teethForSmileJawSub(String jawSub) {
    return jawSub == 'فك علوي' ? upperTeethFdi : lowerTeethFdi;
  }

  static void applySmileJawToChart({
    required Map<String, Set<String>> chart,
    required String jawSub,
    required String currentToothNo,
    required Set<String> nonSmileStatuses,
  }) {
    for (final tooth in teethForSmileJawSub(jawSub)) {
      final existing = Set<String>.from(chart[tooth] ?? {});
      final preserved = existing.where((s) => !isSmileStatus(s)).toSet();
      removeStatusWithSubs(existing, smileStatus);
      existing
        ..add(smileStatus)
        ..add(statusToken(smileStatus, jawSub))
        ..addAll(preserved);
      if (tooth == currentToothNo) {
        existing.removeWhere((s) => !isSmileStatus(s));
        existing.addAll(nonSmileStatuses);
      }
      chart[tooth] = existing;
    }
  }

  static void removeSmileJawFromChart(
    Map<String, Set<String>> chart,
    String jawSub,
  ) {
    for (final tooth in teethForSmileJawSub(jawSub)) {
      final existing = Set<String>.from(chart[tooth] ?? {});
      removeStatusWithSubs(existing, smileStatus);
      if (existing.isEmpty) {
        chart.remove(tooth);
      } else {
        chart[tooth] = existing;
      }
    }
  }

  static void saveToothStatuses({
    required Map<String, Set<String>> chart,
    required String toothNo,
    required Set<String> previous,
    required Set<String> selected,
  }) {
    final hasSmile = hasStatus(selected, smileStatus);
    final nonSmile = selected.where((s) => !isSmileStatus(s)).toSet();

    for (final jawSub in smileJawSubs) {
      final token = statusToken(smileStatus, jawSub);
      final nowSelected = hasSmile && selected.contains(token);
      final wasSelected = previous.contains(token);

      if (nowSelected) {
        applySmileJawToChart(
          chart: chart,
          jawSub: jawSub,
          currentToothNo: toothNo,
          nonSmileStatuses: nonSmile,
        );
      } else if (wasSelected) {
        removeSmileJawFromChart(chart, jawSub);
      }
    }

    final anyJawSmileSelected = hasSmile &&
        smileJawSubs.any(
          (j) => selected.contains(statusToken(smileStatus, j)),
        );

    if (!anyJawSmileSelected) {
      if (selected.isEmpty) {
        chart.remove(toothNo);
      } else {
        chart[toothNo] = Set<String>.from(selected);
      }
    }
  }

  static String toothKindFromNumber(String toothNo) {
    final n = int.tryParse(toothNo);
    if (n == null) return 'molar';
    final unit = n % 10;
    if (unit == 1 || unit == 2) return 'incisor';
    if (unit == 3) return 'canine';
    if (unit == 4 || unit == 5) return 'premolar';
    return 'molar';
  }

  static double toothWidth(String kind, double Function(double) w) {
    switch (kind) {
      case 'incisor':
        return w(30);
      case 'canine':
        return w(32);
      case 'premolar':
        return w(35);
      case 'molar':
      default:
        return w(38);
    }
  }
}
