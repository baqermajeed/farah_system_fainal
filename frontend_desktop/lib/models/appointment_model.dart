import 'package:hive/hive.dart';

part 'appointment_model.g.dart';

@HiveType(typeId: 2)
class AppointmentModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String patientId;

  @HiveField(2)
  final String patientName;

  @HiveField(12)
  final String? patientPhone;  // ⭐ إضافة رقم الهاتف

  @HiveField(3)
  final String doctorId;

  @HiveField(4)
  final String doctorName;

  @HiveField(5)
  final DateTime date;

  @HiveField(6)
  final String time;

  @HiveField(7)
  final String status;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final String? imagePath;

  @HiveField(10)
  final List<String> imagePaths;

  @HiveField(13)
  final bool isLate;

  @HiveField(14)
  final String kind;

  @HiveField(15)
  final String? stageName;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientPhone,  // ⭐ إضافة رقم الهاتف
    required this.doctorId,
    required this.doctorName,
    required this.date,
    required this.time,
    required this.status,
    this.notes,
    this.imagePath,
    this.imagePaths = const [],
    this.isLate = false,
    this.kind = 'regular',
    this.stageName,
  });

  /// وقت العيادة يُرسل/يُخزَّن كوقت حائط (wall-clock) محلي.
  /// الباكند قد يُرجعه مع لاحقة UTC/`Z` بالخطأ؛ لا نطبّق toLocal() حتى لا يُزاد فرق العراق (+3).
  static DateTime _parseScheduledAt(String value) {
    try {
      final parsed = DateTime.parse(value);
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
      );
    } catch (_) {
      return DateTime.now();
    }
  }

  static DateTime _asWallClock(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
    );
  }

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    // Backend/Hive support logic adapted
    final scheduledAt = json['scheduled_at'] ?? json['date'];

    // ⭐ إصلاح: نحتفظ بالتاريخ والوقت الكامل بدلاً من التاريخ فقط
    DateTime appointmentDateTime;
    String? isoString;
    if (scheduledAt is String) {
      isoString = scheduledAt;
      try {
        appointmentDateTime = _parseScheduledAt(scheduledAt);
      } catch (_) {
        appointmentDateTime = DateTime.now();
      }
    } else if (scheduledAt is DateTime) {
      appointmentDateTime = _asWallClock(scheduledAt);
      isoString = scheduledAt.toIso8601String();
    } else {
      appointmentDateTime = DateTime.now();
    }

    // استخراج الوقت (HH:mm) من الـ ISO string
    String _extractTimeFromIso(String? value) {
      if (value == null || value.isEmpty) {
        return _formatTime(DateTime.now());
      }
      try {
        final dt = _parseScheduledAt(value);
        return _formatTime(dt);
      } catch (_) {
        // fallback: محاولة قراءة النمط "THH:MM" يدوياً
        final regex = RegExp(r'T(\d{2}):(\d{2})');
        final match = regex.firstMatch(value);
        if (match != null) {
          final hh = match.group(1)!;
          final mm = match.group(2)!;
          return '$hh:$mm';
        }
        // fallback نهائي: الوقت الحالي
        return _formatTime(DateTime.now());
      }
    }

    List<String> finalImagePaths = [];
    if (json['image_paths'] != null && json['image_paths'] is List) {
      finalImagePaths = List<String>.from(json['image_paths']);
    } else if (json['image_path'] != null) {
      finalImagePaths = [json['image_path']];
    }

    return AppointmentModel(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? json['patientId'] ?? '',
      patientName: json['patient_name'] ?? json['patientName'] ?? '',
      patientPhone: json['patient_phone'] ?? json['patientPhone'],  // ⭐ إضافة رقم الهاتف
      doctorId: json['doctor_id']?.toString() ?? json['doctorId'] ?? '',
      doctorName: json['doctor_name'] ?? json['doctorName'] ?? '',
      date: appointmentDateTime, // ⭐ استخدام التاريخ والوقت الكامل
      time: json['time'] ?? _extractTimeFromIso(isoString),
      status: json['status'] ?? 'pending',
      notes: json['note'] ?? json['notes'],
      imagePath: json['image_path'],
      imagePaths: finalImagePaths,
      isLate: (json['is_late'] ?? json['isLate'] ?? false) == true,
      kind: (json['kind'] ?? 'regular').toString(),
      stageName: json['stage_name']?.toString() ?? json['stageName']?.toString(),
    );
  }

  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,  // ⭐ إضافة رقم الهاتف
      'doctorId': doctorId,
      'doctorName': doctorName,
      'date': date.toIso8601String(),
      'time': time,
      'status': status,
      'notes': notes,
      'image_path': imagePath,
      'image_paths': imagePaths,
      'is_late': isLate,
      'kind': kind,
      'stage_name': stageName,
    };
  }
}
