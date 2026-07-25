import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/services/stats_service.dart';

class DoctorStatsAgeBucket {
  const DoctorStatsAgeBucket({required this.label, required this.count});

  final String label;
  final int count;
}

class DoctorStatsController extends GetxController {
  final StatsService _statsService = StatsService();

  static const int sectionCount = 16;

  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxInt revealedSections = 0.obs;
  bool _fetchInProgress = false;

  final RxInt _totalPatients = 0.obs;
  final RxInt _newPatientsToday = 0.obs;
  final RxInt _newPatientsMonth = 0.obs;
  final RxInt _todayCount = 0.obs;
  final RxInt _monthAppointmentsCount = 0.obs;
  final RxInt _lateAppointmentsCount = 0.obs;
  final RxInt _completedAppointmentsCount = 0.obs;
  final RxInt _pendingAppointmentsCount = 0.obs;
  final RxInt _activePatients = 0.obs;
  final RxInt _pendingPatients = 0.obs;
  final RxInt _inactivePatients = 0.obs;
  final RxInt _maleCount = 0.obs;
  final RxInt _femaleCount = 0.obs;
  final RxDouble _completionRate = 0.0.obs;
  final RxList<int> _dailyAppointmentCounts = RxList<int>.filled(7, 0);
  final RxList<DoctorStatsAgeBucket> _ageBuckets = <DoctorStatsAgeBucket>[].obs;
  final RxMap<String, int> _treatmentDistribution = <String, int>{}.obs;

  int get totalPatients => _totalPatients.value;
  String get totalPatientsLabel => '${_totalPatients.value}';
  int get newPatientsToday => _newPatientsToday.value;
  int get newPatientsMonth => _newPatientsMonth.value;
  int get todayAppointmentsCount => _todayCount.value;
  int get monthAppointmentsCount => _monthAppointmentsCount.value;
  int get lateAppointmentsCount => _lateAppointmentsCount.value;
  int get completedAppointmentsCount => _completedAppointmentsCount.value;
  int get pendingAppointmentsCount => _pendingAppointmentsCount.value;
  int get activePatients => _activePatients.value;
  int get pendingPatients => _pendingPatients.value;
  int get inactivePatients => _inactivePatients.value;
  int get maleCount => _maleCount.value;
  int get femaleCount => _femaleCount.value;
  double get completionRate => _completionRate.value;
  List<int> get dailyAppointmentCounts => _dailyAppointmentCounts;
  List<DoctorStatsAgeBucket> get ageBuckets => _ageBuckets;
  Map<String, int> get treatmentDistribution => _treatmentDistribution;

  late final List<String> weekDayLabels = _buildWeekDayLabels();

  static List<String> _buildWeekDayLabels() {
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

  @override
  void onInit() {
    super.onInit();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) loadStats();
    });
  }

  Future<void> loadStats() async {
    if (_fetchInProgress) return;

    _fetchInProgress = true;
    try {
      isLoading.value = true;
      hasError.value = false;
      revealedSections.value = 0;

      final doctorId = await _statsService.resolveDoctorId();
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6));
      final weekEnd = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1));

      var loadedAny = false;

      final weekAppointmentsFuture = _statsService
          .getDoctorAppointmentsBreakdown(
            doctorId,
            dateFrom: weekStart.toUtc().toIso8601String(),
            dateTo: weekEnd.toUtc().toIso8601String(),
            group: 'day',
          )
          .then((appointments) {
            _applyAppointmentsStats(appointments, weekStart);
            return true;
          })
          .catchError((e, stack) async {
            if (kDebugMode) {
              debugPrint('[DoctorStatsController] appointments error: $e');
              debugPrint('$stack');
            }
            try {
              final fallback = await _statsService.getDoctorAppointmentsBreakdown(
                doctorId,
                group: 'day',
              );
              _applyAppointmentsStats(fallback, weekStart);
              return true;
            } catch (fallbackError, fallbackStack) {
              if (kDebugMode) {
                debugPrint(
                  '[DoctorStatsController] appointments fallback error: $fallbackError',
                );
                debugPrint('$fallbackStack');
              }
              return false;
            }
          });

      final cardsFuture = _statsService
          .getDoctorDetailsCards(doctorId)
          .then((cards) {
            _applyCardsStats(cards);
            return true;
          })
          .catchError((e, stack) {
            if (kDebugMode) {
              debugPrint('[DoctorStatsController] cards error: $e');
              debugPrint('$stack');
            }
            return false;
          });

      final results = await Future.wait([cardsFuture, weekAppointmentsFuture]);
      loadedAny = results.any((loaded) => loaded);

      hasError.value = !loadedAny;
    } catch (e, stack) {
      hasError.value = true;
      if (kDebugMode) {
        debugPrint('[DoctorStatsController] loadStats error: $e');
        debugPrint('$stack');
      }
    } finally {
      isLoading.value = false;
      _fetchInProgress = false;
      if (!hasError.value) {
        await _revealSectionsGradually();
      } else {
        revealedSections.value = 0;
      }
    }
  }

  Future<void> _revealSectionsGradually() async {
    for (var i = 1; i <= sectionCount; i++) {
      if (isClosed) return;
      revealedSections.value = i;
      await Future<void>.delayed(Duration.zero);
    }
  }

  void _applyCardsStats(Map<String, dynamic> cards) {
    final counts = (cards['counts'] as Map?)?.cast<String, dynamic>() ?? {};
    final metrics = (cards['metrics'] as Map?)?.cast<String, dynamic>() ?? {};
    final insights =
        (cards['patient_insights'] as Map?)?.cast<String, dynamic>() ?? {};
    final gender =
        (insights['gender'] as Map?)?.cast<String, dynamic>() ?? {};
    final activity =
        (insights['activity_status'] as Map?)?.cast<String, dynamic>() ??
            metrics;
    final age =
        (insights['age'] as Map?)?.cast<String, dynamic>() ?? {};
    final treatment =
        (insights['treatment'] as Map?)?.cast<String, dynamic>() ?? {};

    _totalPatients.value = _asInt(counts['total_patients']);
    _newPatientsToday.value = _asInt(metrics['transfers_today']);
    _newPatientsMonth.value = _asInt(metrics['transfers_month_unique']);

    _activePatients.value = _asInt(activity['active']);
    _pendingPatients.value = _asInt(activity['pending']);
    _inactivePatients.value = _asInt(activity['inactive']);

    _maleCount.value = _asInt(gender['male']);
    _femaleCount.value = _asInt(gender['female']);

    final buckets = <DoctorStatsAgeBucket>[];
    for (final item in age['buckets'] as List? ?? []) {
      if (item is! Map) continue;
      final label = item['label']?.toString() ?? '';
      final count = _asInt(item['count']);
      if (label.isEmpty || count <= 0) continue;
      buckets.add(DoctorStatsAgeBucket(label: label, count: count));
    }
    _ageBuckets.assignAll(buckets);

    final distribution = <String, int>{};
    for (final item in treatment['distribution'] as List? ?? []) {
      if (item is! Map) continue;
      final type = item['type']?.toString() ?? '';
      final count = _asInt(item['count']);
      if (type.isEmpty || count <= 0) continue;
      distribution[type] = count;
    }
    if (distribution.isEmpty) {
      final topType = treatment['top_type']?.toString() ?? '';
      final topCount = _asInt(treatment['top_count']);
      final totalLinked = _asInt(treatment['total_linked']);
      if (topCount > 0 && topType.isNotEmpty) {
        distribution[topType] = topCount;
      }
      final others = totalLinked - topCount;
      if (others > 0) {
        distribution['أخرى'] = others;
      }
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
}
