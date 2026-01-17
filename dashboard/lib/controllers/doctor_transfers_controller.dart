import 'package:get/get.dart';

import '../models/transfers_stats.dart';
import '../services/stats_service.dart';

class DoctorTransfersController extends GetxController {
  final _stats = StatsService();

  final String doctorId;
  DoctorTransfersController({required this.doctorId});

  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final Rxn<TransfersStats> transfers = Rxn<TransfersStats>();

  final RxString group = 'day'.obs;
  final Rxn<DateTime> from = Rxn<DateTime>();
  final Rxn<DateTime> to = Rxn<DateTime>();

  @override
  Future<void> refresh() async {
    loading.value = true;
    error.value = null;
    try {
      transfers.value = await _stats.getTransfers(
        group: group.value,
        dateFromIso: _iso(from.value),
        dateToIso: _iso(to.value),
        doctorId: doctorId,
      );
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadQuickTodayAndMonth() async {
    // convenience: set range to today and month in the UI by using the same endpoint
    // (we keep it simple: the screen shows the current selected range totals + byPeriod)
  }

  String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
}


