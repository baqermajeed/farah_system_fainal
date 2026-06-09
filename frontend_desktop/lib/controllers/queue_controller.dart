import 'dart:async';

import 'package:get/get.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/models/queue_entry_model.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/services/queue_announcement_service.dart';
import 'package:frontend_desktop/services/queue_window_service.dart';

class QueueController extends GetxController {
  QueueController({this.remoteMode = false});

  final bool remoteMode;
  final _cacheService = CacheService();
  final RxList<QueueEntry> entries = <QueueEntry>[].obs;
  final RxInt nextNumber = 1.obs;

  bool get isEmpty => activeEntries.isEmpty;

  List<QueueEntry> get activeEntries =>
      entries.where((e) => e.status != QueueEntryStatus.done).toList();

  List<QueueEntry> get sortedEntries {
    final list = List<QueueEntry>.from(activeEntries);
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  List<QueueEntry> get waitingEntries {
    final list =
        entries.where((e) => e.status == QueueEntryStatus.waiting).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  QueueEntry? get currentEntry {
    for (final entry in entries) {
      if (entry.status == QueueEntryStatus.called) return entry;
    }
    return null;
  }

  QueueEntry? get nextEntry {
    final waiting = waitingEntries;
    if (waiting.isEmpty) return null;
    return waiting.first;
  }

  List<QueueEntry> get displayWaitingList {
    final waiting = waitingEntries;
    if (waiting.length <= 1) return const [];
    return waiting.sublist(1);
  }

  @override
  void onInit() {
    super.onInit();
    if (!remoteMode) {
      _loadFromCache();
    }
  }

  Map<String, dynamic> toSyncPayload() {
    return {
      'date': _todayKey(),
      'nextNumber': nextNumber.value,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  void applyRemoteState(Map<String, dynamic> data) {
    final today = _todayKey();
    final date = data['date']?.toString() ?? '';
    if (date != today) {
      entries.clear();
      nextNumber.value = 1;
      update();
      return;
    }

    nextNumber.value = data['nextNumber'] is int
        ? data['nextNumber'] as int
        : int.tryParse('${data['nextNumber']}') ?? 1;

    final parsed = <QueueEntry>[];
    final entriesRaw = data['entries'];
    if (entriesRaw is List) {
      for (final item in entriesRaw) {
        if (item is Map) {
          parsed.add(QueueEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    entries.assignAll(parsed);
    update();
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> reloadFromCache() async {
    await _cacheService.reloadQueueBox();
    await _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    final state = _cacheService.loadQueueState();
    final today = _todayKey();

    if (state == null || state.date != today) {
      entries.clear();
      nextNumber.value = 1;
      if (state != null && state.date != today) {
        await _cacheService.clearQueueState();
      }
      update();
      return;
    }

    entries.assignAll(state.entries);
    nextNumber.value = state.nextNumber;
    update();
  }

  Future<void> _saveToCache() async {
    if (!remoteMode) {
      await _cacheService.saveQueueState(
        dateKey: _todayKey(),
        nextNumber: nextNumber.value,
        entries: entries.toList(),
      );
    }
    update();
    if (!remoteMode) {
      await QueueWindowService.notifyDisplayUpdate(toSyncPayload());
    }
  }

  String _normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isNameTaken(String name, {String? excludeId}) {
    final normalized = _normalizeName(name);
    for (final entry in activeEntries) {
      if (excludeId != null && entry.id == excludeId) continue;
      if (_normalizeName(entry.name) == normalized) return true;
    }
    return false;
  }

  String? validateName(String name) {
    final trimmed = _normalizeName(name);
    if (trimmed.isEmpty) {
      return 'يرجى إدخال اسم المريض';
    }
    if (trimmed.length < 2) {
      return 'الاسم قصير جداً';
    }
    return null;
  }

  bool addPatient(String name) {
    if (nextNumber.value > 100) {
      _showValidationError('تم الوصول إلى الحد الأقصى للطابور (100)');
      return false;
    }

    final error = validateName(name);
    if (error != null) {
      _showValidationError(error);
      return false;
    }

    final trimmed = _normalizeName(name);
    if (_isNameTaken(trimmed)) {
      _showValidationError('هذا الاسم موجود مسبقاً في الطابور');
      return false;
    }

    entries.add(
      QueueEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        number: nextNumber.value,
        name: trimmed,
      ),
    );
    nextNumber.value++;
    _saveToCache();
    return true;
  }

  bool updatePatient(String id, String name) {
    final error = validateName(name);
    if (error != null) {
      _showValidationError(error);
      return false;
    }

    final index = entries.indexWhere((e) => e.id == id);
    if (index == -1) return false;

    final trimmed = _normalizeName(name);
    if (_isNameTaken(trimmed, excludeId: id)) {
      _showValidationError('هذا الاسم موجود مسبقاً في الطابور');
      return false;
    }

    entries[index] = entries[index].copyWith(name: trimmed);
    _saveToCache();
    return true;
  }

  void deletePatient(String id) {
    entries.removeWhere((e) => e.id == id);
    _saveToCache();
  }

  bool callNext() {
    final waiting = waitingEntries;
    if (waiting.isEmpty) {
      _showValidationError('لا يوجد مرضى في الانتظار');
      return false;
    }

    for (var i = 0; i < entries.length; i++) {
      if (entries[i].status == QueueEntryStatus.called) {
        entries[i] = entries[i].copyWith(status: QueueEntryStatus.done);
      }
    }

    final next = waiting.first;
    final index = entries.indexWhere((e) => e.id == next.id);
    if (index == -1) return false;

    entries[index] = entries[index].copyWith(status: QueueEntryStatus.called);

    unawaited(
      QueueAnnouncementService.instance.announcePatient(
        number: next.number,
        name: next.name,
      ),
    );
    _saveToCache();
    return true;
  }

  void _showValidationError(String message) {
    Get.snackbar(
      'تنبيه',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.white,
    );
  }

  QueueEntry? findById(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
