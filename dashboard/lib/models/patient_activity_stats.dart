class PatientActivityStats {
  final int active;
  final int inactive;
  final String? rangeFrom;
  final String? rangeTo;

  PatientActivityStats({
    required this.active,
    required this.inactive,
    this.rangeFrom,
    this.rangeTo,
  });

  factory PatientActivityStats.fromJson(Map<String, dynamic> json) {
    final range = (json['range'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PatientActivityStats(
      active: _asInt(json['active']),
      inactive: _asInt(json['inactive']),
      rangeFrom: range['from']?.toString(),
      rangeTo: range['to']?.toString(),
    );
  }
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

