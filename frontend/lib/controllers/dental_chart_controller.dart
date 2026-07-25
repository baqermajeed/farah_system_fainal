import 'package:get/get.dart';

import 'package:farah_sys_final/models/dental_note_entry.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/widgets/dental_chart/dental_chart_constants.dart';

class DentalChartController extends GetxController {
  final DoctorService _doctorService = DoctorService();

  String? _patientId;
  final Map<String, Set<String>> chart = {};
  final Map<String, List<DentalNoteEntry>> notesByTooth = {};
  String? selectedTooth;

  final revision = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;

  bool _serverFetched = false;
  bool _fetchInFlight = false;

  void bindPatient(String patientId) {
    if (_patientId == patientId) return;
    _patientId = patientId;
    chart.clear();
    notesByTooth.clear();
    selectedTooth = null;
    _serverFetched = false;
    _fetchInFlight = false;
    _notify();
    ensureLoaded(patientId);
  }

  void ensureLoaded(String patientId) {
    if (patientId.isEmpty) return;
    _patientId = patientId;
    if (!_serverFetched && !_fetchInFlight) {
      _fetchInFlight = true;
      _fetchFromServer(patientId);
    }
  }

  void _notify() => revision.value++;

  Future<void> _fetchFromServer(String patientId) async {
    isLoading.value = true;
    try {
      final data = await _doctorService.getDentalChart(patientId);
      _applyPayload(
        chartRaw: data['chart'],
        notesRaw: data['notes'],
        selectedToothRaw: data['selected_tooth'] ?? data['selectedTooth'],
      );
    } catch (e) {
      print('⚠️ [DentalChart] Server fetch failed: $e');
    } finally {
      _fetchInFlight = false;
      _serverFetched = true;
      isLoading.value = false;
      _notify();
    }
  }

  void _applyPayload({
    required dynamic chartRaw,
    required dynamic notesRaw,
    required dynamic selectedToothRaw,
  }) {
    chart.clear();
    if (chartRaw is Map) {
      chartRaw.forEach((key, value) {
        final tooth = key.toString();
        if (value is List && value.isNotEmpty) {
          chart[tooth] = value.map((e) => e.toString()).toSet();
        }
      });
    }

    notesByTooth.clear();
    if (notesRaw is Map) {
      notesRaw.forEach((key, value) {
        final tooth = key.toString();
        final entries = <DentalNoteEntry>[];
        if (value is List) {
          for (final item in value) {
            if (item is Map) {
              final note = DentalNoteEntry.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (note.text.trim().isNotEmpty) {
                entries.add(note);
              }
            }
          }
        }
        if (entries.isNotEmpty) {
          notesByTooth[tooth] = entries;
        }
      });
    }

    final selected = selectedToothRaw?.toString();
    selectedTooth =
        (selected != null && selected.isNotEmpty) ? selected : null;
  }

  Future<void> saveTooth({
    required String toothNo,
    required Set<String> previous,
    required Set<String> selected,
    required List<DentalNoteEntry> notes,
  }) async {
    final patientId = _patientId;
    if (patientId == null || patientId.isEmpty) return;

    DentalChartConstants.saveToothStatuses(
      chart: chart,
      toothNo: toothNo,
      previous: previous,
      selected: selected,
    );

    if (notes.isEmpty) {
      notesByTooth.remove(toothNo);
    } else {
      notesByTooth[toothNo] = List<DentalNoteEntry>.from(notes);
    }
    selectedTooth = toothNo;
    _notify();

    await _persist(patientId);
  }

  Future<void> _persist(String patientId) async {
    isSaving.value = true;
    try {
      final chartPayload = <String, List<String>>{};
      chart.forEach((tooth, statuses) {
        if (statuses.isNotEmpty) {
          chartPayload[tooth] = statuses.toList();
        }
      });

      final notesPayload = <String, List<Map<String, dynamic>>>{};
      notesByTooth.forEach((tooth, entries) {
        if (entries.isNotEmpty) {
          notesPayload[tooth] = entries.map((e) => e.toJson()).toList();
        }
      });

      await _doctorService.upsertDentalChart(
        patientId: patientId,
        chart: chartPayload,
        notes: notesPayload,
        selectedTooth: selectedTooth,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حفظ مخطط الأسنان');
      rethrow;
    } finally {
      isSaving.value = false;
    }
  }
}
