class DoctorProfile {
  final DoctorProfileDoctor doctor;
  final DoctorProfileCounts counts;
  final DoctorProfileMessages messages;
  final DoctorProfileAppointments appointments;
  final DoctorProfileTransfers transfers;

  DoctorProfile({
    required this.doctor,
    required this.counts,
    required this.messages,
    required this.appointments,
    required this.transfers,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      doctor: DoctorProfileDoctor.fromJson((json['doctor'] as Map).cast<String, dynamic>()),
      counts: DoctorProfileCounts.fromJson((json['counts'] as Map).cast<String, dynamic>()),
      messages: DoctorProfileMessages.fromJson(
        ((json['messages'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
      appointments: DoctorProfileAppointments.fromJson(
        ((json['appointments'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
      transfers: DoctorProfileTransfers.fromJson((json['transfers'] as Map).cast<String, dynamic>()),
    );
  }
}

class DoctorProfileDoctor {
  final String doctorId;
  final String userId;
  final String? name;
  final String? phone;
  final String? imageUrl;
  final bool isManager;

  DoctorProfileDoctor({
    required this.doctorId,
    required this.userId,
    this.name,
    this.phone,
    this.imageUrl,
    this.isManager = false,
  });

  factory DoctorProfileDoctor.fromJson(Map<String, dynamic> json) => DoctorProfileDoctor(
        doctorId: (json['doctor_id'] ?? '').toString(),
        userId: (json['user_id'] ?? '').toString(),
        name: json['name']?.toString(),
        phone: json['phone']?.toString(),
        imageUrl: json['imageUrl']?.toString(),
        isManager: json['is_manager'] == true || json['isManager'] == true,
      );
}

class DoctorProfileCounts {
  final int totalPatients;
  final int totalAppointments;
  final int todayMessages;

  DoctorProfileCounts({
    required this.totalPatients,
    required this.totalAppointments,
    required this.todayMessages,
  });

  factory DoctorProfileCounts.fromJson(Map<String, dynamic> json) => DoctorProfileCounts(
        totalPatients: _asInt(json['total_patients']),
        totalAppointments: _asInt(json['total_appointments']),
        todayMessages: _asInt(json['today_messages']),
      );
}

class DoctorProfileMessages {
  final int total;
  final int today;
  final int thisMonth;
  final String? rangeFrom;
  final String? rangeTo;
  final int rangeCount;

  DoctorProfileMessages({
    required this.total,
    required this.today,
    required this.thisMonth,
    required this.rangeCount,
    this.rangeFrom,
    this.rangeTo,
  });

  factory DoctorProfileMessages.fromJson(Map<String, dynamic> json) {
    final range = (json['range'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DoctorProfileMessages(
      total: _asInt(json['total']),
      today: _asInt(json['today']),
      thisMonth: _asInt(json['this_month']),
      rangeFrom: range['from']?.toString(),
      rangeTo: range['to']?.toString(),
      rangeCount: _asInt(range['count']),
    );
  }
}

class DoctorProfileAppointments {
  final int today;
  final int thisMonth;
  final String? rangeFrom;
  final String? rangeTo;
  final int rangeCount;

  DoctorProfileAppointments({
    required this.today,
    required this.thisMonth,
    required this.rangeCount,
    this.rangeFrom,
    this.rangeTo,
  });

  factory DoctorProfileAppointments.fromJson(Map<String, dynamic> json) {
    final range = (json['range'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DoctorProfileAppointments(
      today: _asInt(json['today']),
      thisMonth: _asInt(json['this_month']),
      rangeFrom: range['from']?.toString(),
      rangeTo: range['to']?.toString(),
      rangeCount: _asInt(range['count']),
    );
  }
}

class DoctorProfileTransfers {
  final int today;
  final int thisMonth;
  final String? rangeFrom;
  final String? rangeTo;
  final int rangeCount;

  DoctorProfileTransfers({
    required this.today,
    required this.thisMonth,
    required this.rangeCount,
    this.rangeFrom,
    this.rangeTo,
  });

  factory DoctorProfileTransfers.fromJson(Map<String, dynamic> json) {
    final range = (json['range'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DoctorProfileTransfers(
      today: _asInt(json['today']),
      thisMonth: _asInt(json['this_month']),
      rangeFrom: range['from']?.toString(),
      rangeTo: range['to']?.toString(),
      rangeCount: _asInt(range['count']),
    );
  }
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}


