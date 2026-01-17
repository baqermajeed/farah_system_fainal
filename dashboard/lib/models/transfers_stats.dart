class TransfersStats {
  final String group; // day/month/year
  final TransfersRange range;
  final String? doctorId;
  final List<PeriodCount> byPeriod;
  final Map<String, int> byDoctor; // doctor_id -> count
  final int totalTransfers;

  TransfersStats({
    required this.group,
    required this.range,
    required this.byPeriod,
    required this.byDoctor,
    required this.totalTransfers,
    this.doctorId,
  });

  factory TransfersStats.fromJson(Map<String, dynamic> json) {
    final byPeriodRaw = (json['by_period'] as List?) ?? const [];
    final byDoctorRaw = (json['by_doctor'] as Map?)?.cast<String, dynamic>() ?? const {};

    return TransfersStats(
      group: (json['group'] ?? 'day').toString(),
      range: TransfersRange.fromJson((json['range'] as Map?)?.cast<String, dynamic>() ?? const {}),
      doctorId: json['doctor_id']?.toString(),
      byPeriod: byPeriodRaw
          .map((e) => PeriodCount.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      byDoctor: byDoctorRaw.map((k, v) => MapEntry(k, _asInt(v))),
      totalTransfers: _asInt(json['total_transfers']),
    );
  }
}

class TransfersRange {
  final String? from;
  final String? to;

  TransfersRange({this.from, this.to});

  factory TransfersRange.fromJson(Map<String, dynamic> json) => TransfersRange(
        from: json['from']?.toString(),
        to: json['to']?.toString(),
      );
}

class PeriodCount {
  final String period;
  final int count;

  PeriodCount({required this.period, required this.count});

  factory PeriodCount.fromJson(Map<String, dynamic> json) => PeriodCount(
        period: (json['period'] ?? '').toString(),
        count: _asInt(json['count']),
      );
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}


