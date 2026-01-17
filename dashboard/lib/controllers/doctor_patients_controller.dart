import 'package:get/get.dart';

import '../models/patient_item.dart';
import '../services/admin_service.dart';

enum PatientsFilterMode { daily, monthly, custom }

class DoctorPatientsController extends GetxController {
  final String doctorId;
  DoctorPatientsController({required this.doctorId});

  final _admin = AdminService();

  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxList<PatientItem> patients = <PatientItem>[].obs;

  final Rx<PatientsFilterMode> mode = PatientsFilterMode.daily.obs;
  final Rxn<DateTime> from = Rxn<DateTime>();
  final Rxn<DateTime> to = Rxn<DateTime>();

  bool get isCustomRangeReady =>
      mode.value != PatientsFilterMode.custom ||
      (from.value != null && to.value != null);

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      // Custom filter must have from/to selected. Otherwise don't call API (avoid returning all patients).
      if (mode.value == PatientsFilterMode.custom &&
          (from.value == null || to.value == null)) {
        patients.clear();
        return;
      }
      final range = _computeRange();
      final list = await _admin.getDoctorPatients(
        doctorId: doctorId,
        dateFromIso: range.$1?.toUtc().toIso8601String(),
        dateToIso: range.$2?.toUtc().toIso8601String(),
        skip: 0,
        limit: 100,
      );
      patients.assignAll(_sortNewestFirst(list));
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  (DateTime?, DateTime?) _computeRange() {
    final now = DateTime.now();
    switch (mode.value) {
      case PatientsFilterMode.daily:
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return (start, end);
      case PatientsFilterMode.monthly:
        final start = DateTime(now.year, now.month, 1);
        final end = (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        return (start, end);
      case PatientsFilterMode.custom:
        return (from.value, to.value);
    }
  }

  List<PatientItem> _sortNewestFirst(List<PatientItem> list) {
    final sorted = List<PatientItem>.from(list);
    int oidSeconds(String id) {
      if (id.length < 8) return 0;
      return int.tryParse(id.substring(0, 8), radix: 16) ?? 0;
    }

    sorted.sort((a, b) => oidSeconds(b.id).compareTo(oidSeconds(a.id)));
    return sorted;
  }
}


