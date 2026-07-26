class DoctorStatsBreakdownItem {
  const DoctorStatsBreakdownItem({
    required this.key,
    required this.label,
    required this.count,
    required this.percent,
  });

  final String key;
  final String label;
  final int count;
  final int percent;

  factory DoctorStatsBreakdownItem.fromJson(Map<String, dynamic> json) {
    return DoctorStatsBreakdownItem(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      count: _asInt(json['count']),
      percent: _asInt(json['percent']),
    );
  }
}

class DoctorStatsWeekDay {
  const DoctorStatsWeekDay({
    required this.date,
    required this.dayLabel,
    required this.count,
    required this.isToday,
  });

  final String date;
  final String dayLabel;
  final int count;
  final bool isToday;

  factory DoctorStatsWeekDay.fromJson(Map<String, dynamic> json) {
    return DoctorStatsWeekDay(
      date: json['date']?.toString() ?? '',
      dayLabel: json['day_label']?.toString() ?? '',
      count: _asInt(json['count']),
      isToday: json['is_today'] == true,
    );
  }
}

class DoctorStatsTreatmentItem {
  const DoctorStatsTreatmentItem({
    required this.type,
    required this.count,
    required this.percent,
  });

  final String type;
  final int count;
  final int percent;

  factory DoctorStatsTreatmentItem.fromJson(Map<String, dynamic> json) {
    return DoctorStatsTreatmentItem(
      type: json['type']?.toString() ?? '',
      count: _asInt(json['count']),
      percent: _asInt(json['percent']),
    );
  }
}

class DoctorStatsAgeBucket {
  const DoctorStatsAgeBucket({
    required this.label,
    required this.count,
    required this.percent,
  });

  final String label;
  final int count;
  final int percent;

  factory DoctorStatsAgeBucket.fromJson(Map<String, dynamic> json) {
    return DoctorStatsAgeBucket(
      label: json['label']?.toString() ?? '',
      count: _asInt(json['count']),
      percent: _asInt(json['percent']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
