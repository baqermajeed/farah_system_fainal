class DoctorStat {
  final String doctorId;
  final String userId;
  final String? name;
  final String? phone;
  final String? imageUrl;
  final int totalPatients;
  final int totalAppointments;
  final int completedAppointments;
  final int treatmentNotes;

  DoctorStat({
    required this.doctorId,
    required this.userId,
    required this.totalPatients,
    required this.totalAppointments,
    required this.completedAppointments,
    required this.treatmentNotes,
    this.name,
    this.phone,
    this.imageUrl,
  });

  factory DoctorStat.fromJson(Map<String, dynamic> json) {
    return DoctorStat(
      doctorId: (json['doctor_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      totalPatients: _asInt(json['total_patients']),
      totalAppointments: _asInt(json['total_appointments']),
      completedAppointments: _asInt(json['completed_appointments']),
      treatmentNotes: _asInt(json['treatment_notes']),
    );
  }
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}


