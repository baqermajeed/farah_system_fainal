import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/services/chat_service.dart';
import 'package:farah_sys_final/services/stats_service.dart';

class DoctorStatsController extends GetxController {
  final StatsService _statsService = StatsService();
  final ChatService _chatService = ChatService();

  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;

  final RxInt _totalPatients = 0.obs;
  final RxString _totalPatientsLabel = '0'.obs;
  final RxInt _todayCount = 0.obs;
  final RxInt _monthAppointmentsCount = 0.obs;
  final RxInt _lateAppointmentsCount = 0.obs;
  final RxInt _completedAppointmentsCount = 0.obs;
  final RxInt _pendingAppointmentsCount = 0.obs;
  final RxInt _activeTreatments = 0.obs;
  final RxInt _unreadCount = 0.obs;
  final RxDouble _completionRate = 0.0.obs;
  final RxList<int> _dailyAppointmentCounts = RxList<int>.filled(7, 0);
  final RxMap<String, int> _treatmentDistribution = <String, int>{}.obs;

  @override
  void onReady() {
    super.onReady();
    loadStats();
  }

  int get totalPatients => _totalPatients.value;
  String get totalPatientsLabel => _totalPatientsLabel.value;
  int get todayAppointmentsCount => _todayCount.value;
  int get monthAppointmentsCount => _monthAppointmentsCount.value;
  int get lateAppointmentsCount => _lateAppointmentsCount.value;
  int get completedAppointmentsCount => _completedAppointmentsCount.value;
  int get pendingAppointmentsCount => _pendingAppointmentsCount.value;
  int get activeTreatments => _activeTreatments.value;
  int get totalUnreadMessages => _unreadCount.value;
  double get completionRate => _completionRate.value;
  List<int> get dailyAppointmentCounts => _dailyAppointmentCounts.toList();
  Map<String, int> get treatmentDistribution =>
      Map<String, int>.from(_treatmentDistribution);

  List<String> get weekDayLabels {
    const days = [
      'السبت',
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
    ];
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = DateTime(now.year, now.month, now.day).subtract(
        Duration(days: 6 - index),
      );
      return days[date.weekday % 7];
    });
  }

  Future<void> loadStats() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      hasError.value = false;

      final doctorId = await _statsService.resolveDoctorId();
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6));
      final weekEnd = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1));
      final dateFmt = DateFormat('yyyy-MM-dd');

      final results = await Future.wait([
        _statsService.getDoctorDetailsCards(doctorId),
        _statsService.getDoctorAppointmentsBreakdown(
          doctorId,
          dateFrom: dateFmt.format(weekStart),
          dateTo: dateFmt.format(weekEnd),
          group: 'day',
        ),
        _loadUnreadCount(),
      ]);

      final cards = results[0] as Map<String, dynamic>;
      final appointments = results[1] as Map<String, dynamic>;
      _unreadCount.value = results[2] as int;

      _applyCardsStats(cards);
      _applyAppointmentsStats(appointments, weekStart);
    } catch (e, stack) {
      hasError.value = true;
      if (kDebugMode) {
        debugPrint('[DoctorStatsController] loadStats error: $e');
        debugPrint('$stack');
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _applyCardsStats(Map<String, dynamic> cards) {
    final counts = (cards['counts'] as Map?)?.cast<String, dynamic>() ?? {};
    final metrics = (cards['metrics'] as Map?)?.cast<String, dynamic>() ?? {};
    final treatment =
        ((cards['patient_insights'] as Map?)?['treatment'] as Map?)
            ?.cast<String, dynamic>() ??
        {};

    final patientsTotal = _asInt(counts['total_patients']);
    _totalPatients.value = patientsTotal;
    _totalPatientsLabel.value = '$patientsTotal';
    _activeTreatments.value = _asInt(metrics['active_count']);

    final topType = treatment['top_type']?.toString() ?? 'غير محدد';
    final topCount = _asInt(treatment['top_count']);
    final totalLinked = _asInt(treatment['total_linked']);

    final distribution = <String, int>{};
    if (topCount > 0) {
      distribution[topType] = topCount;
    }
    final others = totalLinked - topCount;
    if (others > 0) {
      distribution['أخرى'] = others;
    }
    _treatmentDistribution.assignAll(distribution);
  }

  void _applyAppointmentsStats(
    Map<String, dynamic> appointments,
    DateTime weekStart,
  ) {
    final summary =
        (appointments['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final byStatusMonth =
        ((appointments['by_status'] as Map?)?['this_month'] as Map?)
            ?.cast<String, dynamic>() ??
        {};

    _todayCount.value = _asInt(summary['today']);
    _monthAppointmentsCount.value = _asInt(summary['this_month']);
    _lateAppointmentsCount.value = _asInt(byStatusMonth['late']);
    _completedAppointmentsCount.value = _asInt(byStatusMonth['completed']);
    _pendingAppointmentsCount.value = _asInt(byStatusMonth['pending']);

    final monthTotal = _monthAppointmentsCount.value;
    _completionRate.value =
        monthTotal == 0 ? 0 : _completedAppointmentsCount.value / monthTotal;

    final timeline = appointments['timeline'] as List? ?? [];
    final timelineMap = <String, int>{};
    for (final item in timeline) {
      if (item is! Map) continue;
      final period = item['period']?.toString();
      if (period == null) continue;
      timelineMap[period] = _asInt(item['count']);
    }

    final dateFmt = DateFormat('yyyy-MM-dd');
    final counts = List<int>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      counts[i] = timelineMap[dateFmt.format(day)] ?? 0;
    }
    _dailyAppointmentCounts.assignAll(counts);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<int> _loadUnreadCount() async {
    try {
      final chatList = await _chatService.getChatList();
      var total = 0;
      for (final chat in chatList) {
        total += chat['unread_count'] as int? ?? 0;
      }
      return total;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DoctorStatsController] unread load error: $e');
      }
      return 0;
    }
  }
}
