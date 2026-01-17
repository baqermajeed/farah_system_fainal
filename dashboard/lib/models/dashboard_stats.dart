class DashboardStats {
  final OverviewStats overview;
  final TodayStats today;
  final ThisMonthStats thisMonth;
  final AppointmentsByStatus appointmentsByStatus;
  final ChatStats chat;
  final NotificationsStats notifications;

  DashboardStats({
    required this.overview,
    required this.today,
    required this.thisMonth,
    required this.appointmentsByStatus,
    required this.chat,
    required this.notifications,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      overview: OverviewStats.fromJson((json['overview'] as Map?)?.cast<String, dynamic>() ?? const {}),
      today: TodayStats.fromJson((json['today'] as Map?)?.cast<String, dynamic>() ?? const {}),
      thisMonth: ThisMonthStats.fromJson((json['this_month'] as Map?)?.cast<String, dynamic>() ?? const {}),
      appointmentsByStatus: AppointmentsByStatus.fromJson(
        (json['appointments_by_status'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      chat: ChatStats.fromJson((json['chat'] as Map?)?.cast<String, dynamic>() ?? const {}),
      notifications: NotificationsStats.fromJson((json['notifications'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }
}

class OverviewStats {
  final int totalPatients;
  final int totalDoctors;
  final int totalAppointments;
  final int upcomingAppointments;

  OverviewStats({
    required this.totalPatients,
    required this.totalDoctors,
    required this.totalAppointments,
    required this.upcomingAppointments,
  });

  factory OverviewStats.fromJson(Map<String, dynamic> json) => OverviewStats(
        totalPatients: _asInt(json['total_patients']),
        totalDoctors: _asInt(json['total_doctors']),
        totalAppointments: _asInt(json['total_appointments']),
        upcomingAppointments: _asInt(json['upcoming_appointments']),
      );
}

class TodayStats {
  final int newPatients;
  final int appointments;
  final int chatMessages;

  TodayStats({
    required this.newPatients,
    required this.appointments,
    required this.chatMessages,
  });

  factory TodayStats.fromJson(Map<String, dynamic> json) => TodayStats(
        newPatients: _asInt(json['new_patients']),
        appointments: _asInt(json['appointments']),
        chatMessages: _asInt(json['chat_messages']),
      );
}

class ThisMonthStats {
  final int newPatients;
  final int appointments;

  ThisMonthStats({
    required this.newPatients,
    required this.appointments,
  });

  factory ThisMonthStats.fromJson(Map<String, dynamic> json) => ThisMonthStats(
        newPatients: _asInt(json['new_patients']),
        appointments: _asInt(json['appointments']),
      );
}

class AppointmentsByStatus {
  final int scheduled;
  final int completed;
  final int canceled;

  AppointmentsByStatus({
    required this.scheduled,
    required this.completed,
    required this.canceled,
  });

  factory AppointmentsByStatus.fromJson(Map<String, dynamic> json) => AppointmentsByStatus(
        scheduled: _asInt(json['scheduled']),
        completed: _asInt(json['completed']),
        // backend يستخدم canceled (بالإنجليزية الأمريكية) داخل get_dashboard_stats
        canceled: _asInt(json['canceled'] ?? json['cancelled']),
      );
}

class ChatStats {
  final int totalRooms;
  final int totalMessages;

  ChatStats({
    required this.totalRooms,
    required this.totalMessages,
  });

  factory ChatStats.fromJson(Map<String, dynamic> json) => ChatStats(
        totalRooms: _asInt(json['total_rooms']),
        totalMessages: _asInt(json['total_messages']),
      );
}

class NotificationsStats {
  final int totalSent;
  final int activeDevices;

  NotificationsStats({
    required this.totalSent,
    required this.activeDevices,
  });

  factory NotificationsStats.fromJson(Map<String, dynamic> json) => NotificationsStats(
        totalSent: _asInt(json['total_sent']),
        activeDevices: _asInt(json['active_devices']),
      );
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}


