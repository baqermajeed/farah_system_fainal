import 'dart:async';

import 'package:get/get.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/models/queue_entry_model.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/services/queue_announcement_service.dart';
import 'package:frontend_desktop/services/queue_archive_service.dart';
import 'package:frontend_desktop/services/queue_window_service.dart';

class QueueController extends GetxController {
  QueueController({this.remoteMode = false});

  final bool remoteMode;
  final _cacheService = CacheService();
  final _archiveService = QueueArchiveService();
  final RxList<QueueEntry> entries = <QueueEntry>[].obs;
  final RxInt nextNumber = 1.obs;
  /// آخر مستدعى بنج في دايلوك الإدارة (لا يُدفع لشاشة العرض تلقائياً)
  final RxnString lastCalledId = RxnString();

  /// نسخة شاشة العرض — مستقلة عن استدعاءات البنچ/الصف في الإدارة
  final List<QueueEntry> _displayEntries = <QueueEntry>[];
  String? _displayNowId;

  int _archiveSyncToken = 0;
  /// تاريخ جلسة الطابور الحالي (yyyy-MM-dd) — للكشف عن انتقال اليوم أثناء بقاء التطبيق مفتوحاً
  String _sessionDateKey = '';
  Timer? _dayRolloverTimer;

  bool get isEmpty => sortedEntries.isEmpty;

  /// كل الحالات تظهر في دايلوك الإدارة (انتظار / بنج / عملية / تأجيل)
  List<QueueEntry> get activeEntries => List<QueueEntry>.from(entries);

  List<QueueEntry> get sortedEntries {
    final list = List<QueueEntry>.from(entries);
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  /// بانتظار استدعاء البنچ
  List<QueueEntry> get waitingEntries {
    final list =
        entries.where((e) => e.status == QueueEntryStatus.waiting).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  /// تم استدعاؤهم للبنچ وبانتظار العملية
  List<QueueEntry> get anesthesiaEntries {
    final list =
        entries.where((e) => e.status == QueueEntryStatus.anesthesia).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  List<QueueEntry> get _displaySourceEntries {
    if (remoteMode) return entries.toList();
    return List<QueueEntry>.from(_displayEntries);
  }

  String? get _displaySourceNowId =>
      remoteMode ? lastCalledId.value : _displayNowId;

  /// «الآن» على شاشة العرض — فقط إن وُضع صراحة عبر استدعاء العملية (لا بنج)
  QueueEntry? get displayCurrentEntry {
    final id = _displaySourceNowId;
    if (id == null || id.isEmpty) return null;
    for (final entry in _displaySourceEntries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// توافق قديم مع شاشة العرض
  QueueEntry? get currentEntry => displayCurrentEntry;

  /// التالي في دايلوك الإدارة (أول منتظر للبنچ)
  QueueEntry? get nextEntry {
    final waiting = waitingEntries;
    if (waiting.isEmpty) return null;
    return waiting.first;
  }

  /// «القادم» على شاشة العرض — أول رقم بعد «الآن»
  QueueEntry? get displayNextEntry {
    final currentId = displayCurrentEntry?.id;
    final waiting = _displaySourceEntries
        .where((e) => e.id != currentId)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    if (waiting.isEmpty) return null;
    return waiting.first;
  }

  List<QueueEntry> get displayWaitingList {
    final currentId = displayCurrentEntry?.id;
    final nextId = displayNextEntry?.id;
    return _displaySourceEntries
        .where((e) => e.id != currentId && e.id != nextId)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
  }

  @override
  void onInit() {
    super.onInit();
    _sessionDateKey = _todayKey();
    if (!remoteMode) {
      _loadFromCache();
    }
    _startDayRolloverWatcher();
  }

  @override
  void onClose() {
    _dayRolloverTimer?.cancel();
    _dayRolloverTimer = null;
    super.onClose();
  }

  Map<String, dynamic> toSyncPayload() {
    ensureNewDay();
    // نرسل نسخة شاشة العرض فقط — بدون حالات البنچ من الإدارة
    final nowId = remoteMode ? lastCalledId.value : _displayNowId;
    final displayList = (remoteMode
            ? entries.toList()
            : List<QueueEntry>.from(_displayEntries))
        .map(
          (e) => QueueEntry(
            id: e.id,
            number: e.number,
            name: e.name,
            // كل القائمة انتظار في الـ payload؛ «الآن» يُحدد فقط بـ displayNowId
            status: QueueEntryStatus.waiting,
          ),
        )
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return {
      'date': _todayKey(),
      'nextNumber': nextNumber.value,
      'displayNowId': nowId,
      'lastCalledId': nowId, // توافق مع شاشة العرض القديمة
      'entries': displayList.map((e) => e.toJson()).toList(),
    };
  }

  void _clearDisplaySnapshot() {
    _displayEntries.clear();
    _displayNowId = null;
  }

  /// تهيئة نسخة العرض عند التحميل — بدون توريث استدعاءات البنچ كـ «الآن»
  void _seedDisplaySnapshotFromEntries() {
    _displayEntries
      ..clear()
      ..addAll(
        entries.where((e) => e.status.isVisibleOnDisplay).map(
              (e) => QueueEntry(
                id: e.id,
                number: e.number,
                name: e.name,
                status: QueueEntryStatus.waiting,
              ),
            ),
      );
    _displayNowId = null;
  }

  void _addToDisplaySnapshot(QueueEntry entry) {
    _displayEntries.removeWhere((e) => e.id == entry.id);
    _displayEntries.add(
      QueueEntry(
        id: entry.id,
        number: entry.number,
        name: entry.name,
        status: QueueEntryStatus.waiting,
      ),
    );
  }

  void _updateDisplaySnapshotName(String id, String name) {
    final index = _displayEntries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _displayEntries[index] = _displayEntries[index].copyWith(name: name);
  }

  void _removeFromDisplaySnapshot(String id) {
    _displayEntries.removeWhere((e) => e.id == id);
    if (_displayNowId == id) {
      _displayNowId = null;
    }
  }

  /// عند استدعاء العملية من الشريط العلوي فقط: يصبح المريض «الآن»
  void _applySurgeryToDisplaySnapshot(QueueEntry entry) {
    if (_displayNowId != null && _displayNowId != entry.id) {
      _displayEntries.removeWhere((e) => e.id == _displayNowId);
    }
    _displayEntries.removeWhere((e) => e.id == entry.id);
    _displayEntries.add(
      QueueEntry(
        id: entry.id,
        number: entry.number,
        name: entry.name,
        status: QueueEntryStatus.waiting,
      ),
    );
    _displayNowId = entry.id;
  }

  void applyRemoteState(Map<String, dynamic> data) {
    final today = _todayKey();
    final date = data['date']?.toString() ?? '';
    if (date != today || _entriesFromPreviousDay(data['entries'])) {
      _resetInMemoryForNewDay(today);
      update();
      return;
    }

    final parsed = <QueueEntry>[];
    final entriesRaw = data['entries'];
    if (entriesRaw is List) {
      for (final item in entriesRaw) {
        if (item is Map) {
          final entry =
              QueueEntry.fromJson(Map<String, dynamic>.from(item));
          // شاشة العرض لا تستخدم حالات البنچ — كلها انتظار + displayNowId
          parsed.add(
            QueueEntry(
              id: entry.id,
              number: entry.number,
              name: entry.name,
              status: QueueEntryStatus.waiting,
            ),
          );
        }
      }
    }
    entries.assignAll(parsed);
    final remoteNext = data['nextNumber'];
    if (remoteNext is int) {
      nextNumber.value = remoteNext;
    } else {
      nextNumber.value = int.tryParse('$remoteNext') ?? nextNumber.value;
    }
    // «الآن» فقط من displayNowId الصريح (يُضبط عند استدعاء العملية)
    final remoteNow = data['displayNowId']?.toString() ??
        data['lastCalledId']?.toString();
    lastCalledId.value =
        (remoteNow != null && remoteNow.isNotEmpty) ? remoteNow : null;
    _sessionDateKey = today;
    update();
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _startDayRolloverWatcher() {
    _dayRolloverTimer?.cancel();
    // كل 30 ثانية: يكفي لاكتشاف منتصف الليل دون إبقاء التطبيق مفتوحاً على بيانات الأمس
    _dayRolloverTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ensureNewDay();
    });
  }

  /// يصفّر الطابور إن تغيّر اليوم (حتى لو التطبيق بقي مفتوحاً من الأمس).
  /// يُرجع true إذا تم التصفير.
  bool ensureNewDay() {
    final today = _todayKey();
    if (_sessionDateKey == today) return false;
    _rollOverToNewDay(today);
    return true;
  }

  void _resetInMemoryForNewDay(String today) {
    entries.clear();
    nextNumber.value = 1;
    lastCalledId.value = null;
    _clearDisplaySnapshot();
    _sessionDateKey = today;
  }

  void _rollOverToNewDay(String today) {
    _resetInMemoryForNewDay(today);
    update();
    if (!remoteMode) {
      unawaited(_persistEmptyDay(today));
    }
  }

  Future<void> _persistEmptyDay(String today) async {
    await _cacheService.saveQueueState(
      dateKey: today,
      nextNumber: 1,
      entries: const [],
    );
    await QueueWindowService.notifyDisplayUpdate(toSyncPayload());
  }

  /// كشف بيانات أمس التي أُعيد حفظها بتاريخ اليوم بالخطأ (id = microsecondsSinceEpoch).
  bool _entriesFromPreviousDay(dynamic entriesRaw) {
    if (entriesRaw is! List || entriesRaw.isEmpty) return false;
    final startMicros = _startOfToday().microsecondsSinceEpoch;
    for (final item in entriesRaw) {
      if (item is! Map) continue;
      final idMicros = int.tryParse(item['id']?.toString() ?? '');
      if (idMicros != null && idMicros < startMicros) {
        return true;
      }
    }
    return false;
  }

  bool _listFromPreviousDay(List<QueueEntry> list) {
    if (list.isEmpty) return false;
    final startMicros = _startOfToday().microsecondsSinceEpoch;
    for (final entry in list) {
      final idMicros = int.tryParse(entry.id);
      if (idMicros != null && idMicros < startMicros) {
        return true;
      }
    }
    return false;
  }

  Future<void> reloadFromCache() async {
    await _cacheService.reloadQueueBox();
    await _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    final state = _cacheService.loadQueueState();
    final today = _todayKey();
    _sessionDateKey = today;

    final staleByDate = state != null && state.date != today;
    final staleByEntries =
        state != null && state.date == today && _listFromPreviousDay(state.entries);

    if (state == null || staleByDate || staleByEntries) {
      entries.clear();
      nextNumber.value = 1;
      lastCalledId.value = null;
      _clearDisplaySnapshot();
      if (staleByDate || staleByEntries) {
        await _cacheService.saveQueueState(
          dateKey: today,
          nextNumber: 1,
          entries: const [],
        );
      }
      update();
      if (!remoteMode) {
        await QueueWindowService.notifyDisplayUpdate(toSyncPayload());
      }
      return;
    }

    entries.assignAll(state.entries);
    nextNumber.value = state.nextNumber;
    // استعادة آخر مستدعى بنج من الحالات المحفوظة إن وُجد
    QueueEntry? lastCalled;
    for (var i = state.entries.length - 1; i >= 0; i--) {
      if (state.entries[i].status == QueueEntryStatus.anesthesia) {
        lastCalled = state.entries[i];
        break;
      }
    }
    lastCalledId.value = lastCalled?.id;
    _seedDisplaySnapshotFromEntries();
    update();
    // إعادة دفع أرشيف اليوم عند التشغيل (لا يُستخدم للعرض)
    if (entries.isNotEmpty) {
      _syncArchiveToServer();
    }
  }

  Future<void> _saveToCache({
    bool syncArchive = true,
    // افتراضي false حتى لا تُزامَن شاشة العرض صدفة (مثلاً عند البنچ)
    bool syncDisplay = false,
  }) async {
    // لا تستدعِ ensureNewDay هنا بعد إضافة مريض — يُستدعى قبل العمليات
    if (_sessionDateKey != _todayKey()) {
      _rollOverToNewDay(_todayKey());
      return;
    }
    if (!remoteMode) {
      await _cacheService.saveQueueState(
        dateKey: _sessionDateKey,
        nextNumber: nextNumber.value,
        entries: entries.toList(),
      );
    }
    update();
    if (!remoteMode) {
      // شاشة العرض فقط عند syncDisplay=true (إضافة/تعديل/حذف/استدعاء عملية)
      if (syncDisplay) {
        await QueueWindowService.notifyDisplayUpdate(toSyncPayload());
      }
      if (syncArchive) {
        _syncArchiveToServer();
      }
    }
  }

  /// أرشفة في السيرفر فقط — لا تؤثر على العرض أو النداء المحلي.
  void _syncArchiveToServer() {
    final dateKey = _todayKey();
    final snapshot = entries
        .map((e) => QueueEntry(id: e.id, number: e.number, name: e.name))
        .toList(growable: false);
    final token = ++_archiveSyncToken;
    unawaited(_pushArchive(dateKey, snapshot, token));
  }

  Future<void> _pushArchive(
    String dateKey,
    List<QueueEntry> snapshot,
    int token,
  ) async {
    try {
      await _archiveService.syncDay(dateKey: dateKey, entries: snapshot);
      if (token != _archiveSyncToken) return;
    } catch (_) {
      // فشل الأرشفة لا يوقف عمل الطابور المحلي
    }
  }

  String _normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isNameTaken(String name, {String? excludeId}) {
    final normalized = _normalizeName(name);
    for (final entry in entries) {
      // العملية/التأجيل لا يمنعان إعادة إضافة نفس الاسم لاحقاً
      if (entry.status == QueueEntryStatus.surgery ||
          entry.status == QueueEntryStatus.postponed) {
        continue;
      }
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
    ensureNewDay();
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

    final entry = QueueEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      number: nextNumber.value,
      name: trimmed,
    );
    entries.add(entry);
    nextNumber.value++;
    _addToDisplaySnapshot(entry);
    // الإضافة وحدها (مع استدعاء العملية من الزر العلوي) تحدّث شاشة العرض
    _saveToCache(syncDisplay: true);
    return true;
  }

  bool updatePatient(String id, String name) {
    ensureNewDay();
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
    _updateDisplaySnapshotName(id, trimmed);
    // التعديل يحدّث الاسم على شاشة العرض
    _saveToCache(syncDisplay: true);
    return true;
  }

  void deletePatient(String id) {
    ensureNewDay();
    entries.removeWhere((e) => e.id == id);
    if (lastCalledId.value == id) {
      lastCalledId.value = null;
    }
    _removeFromDisplaySnapshot(id);
    // الحذف يزيل المراجع من شاشة العرض
    _saveToCache(syncDisplay: true);
  }

  /// تصفير يدوي للطابور — يمسح الكل ويعيد الترقيم من 1.
  void clearQueue() {
    final today = _todayKey();
    _resetInMemoryForNewDay(today);
    update();
    if (!remoteMode) {
      unawaited(_persistEmptyDay(today));
    }
  }

  /// استدعاء التالي لغرفة التخدير (البنچ)
  bool callNextAnesthesia() {
    ensureNewDay();
    final waiting = waitingEntries;
    if (waiting.isEmpty) {
      _showValidationError('لا يوجد مرضى بانتظار البنچ');
      return false;
    }
    return callAnesthesia(waiting.first.id);
  }

  /// استدعاء التالي لغرفة العمليات من الشريط العلوي فقط.
  /// يحدّث شاشة العرض بالترتيب (أصغر رقم ظاهر في نسخة العرض بعد «الآن»).
  bool callNextSurgery() {
    ensureNewDay();
    final ready = anesthesiaEntries;
    if (ready.isEmpty) {
      _showValidationError('لا يوجد مرضى بانتظار العملية (بعد البنچ)');
      return false;
    }

    // ترتيب شاشة العرض: لا نتخطى رقماً أصغر ما زال في قائمة العرض
    final displayOrdered = List<QueueEntry>.from(_displayEntries)
      ..sort((a, b) => a.number.compareTo(b.number));
    final nowId = _displayNowId;
    QueueEntry? displayNext;
    for (final entry in displayOrdered) {
      if (entry.id == nowId) continue;
      displayNext = entry;
      break;
    }

    if (displayNext != null) {
      final managed = findById(displayNext.id);
      if (managed == null || managed.status != QueueEntryStatus.anesthesia) {
        _showValidationError(
          'يجب استدعاء البنچ للرقم ${displayNext.number} أولاً قبل العملية',
        );
        return false;
      }
      return callSurgery(managed.id, syncDisplay: true);
    }

    return callSurgery(ready.first.id, syncDisplay: true);
  }

  /// توافق مع الاستدعاءات القديمة — يعامل كاستدعاء بنج
  bool callNext() => callNextAnesthesia();

  /// استدعاء / إعادة استدعاء للبنچ — صوت + حالة في الإدارة فقط.
  /// لا يغيّر شاشة العرض نهائياً.
  bool callAnesthesia(String id) {
    ensureNewDay();
    final index = entries.indexWhere((e) => e.id == id);
    if (index == -1) {
      _showValidationError('المريض غير موجود في الطابور');
      return false;
    }

    final entry = entries[index];
    if (entry.status == QueueEntryStatus.surgery) {
      _showValidationError('تم استدعاء هذا المراجع للعملية مسبقاً');
      return false;
    }
    if (entry.status == QueueEntryStatus.postponed) {
      _showValidationError('المراجع مؤجّل — ألغِ التأجيل أولاً أو أعد إضافته');
      return false;
    }

    entries[index] = entry.copyWith(status: QueueEntryStatus.anesthesia);
    lastCalledId.value = entry.id;

    unawaited(
      QueueAnnouncementService.instance.announcePatient(
        number: entry.number,
        name: entry.name,
      ),
    );
    // مهم: لا مزامنة لشاشة العرض ولا تعديل لنسخة العرض
    _saveToCache(syncArchive: false, syncDisplay: false);
    return true;
  }

  /// استدعاء للعملية — صوت + حالة خضراء في الإدارة.
  /// تحديث شاشة العرض فقط عندما [syncDisplay] = true (زر الشريط العلوي).
  bool callSurgery(String id, {bool syncDisplay = false}) {
    ensureNewDay();
    final index = entries.indexWhere((e) => e.id == id);
    if (index == -1) {
      _showValidationError('المريض غير موجود في الطابور');
      return false;
    }

    final entry = entries[index];
    if (entry.status == QueueEntryStatus.postponed) {
      _showValidationError('لا يمكن استدعاء مراجع مؤجّل للعملية');
      return false;
    }
    if (entry.status == QueueEntryStatus.waiting) {
      _showValidationError('يجب استدعاء البنچ أولاً قبل العملية');
      return false;
    }
    if (entry.status == QueueEntryStatus.surgery) {
      // إعادة النداء الصوتي فقط — بدون تغيير للطابور أو شاشة العرض
      unawaited(
        QueueAnnouncementService.instance.announcePatient(
          number: entry.number,
          name: entry.name,
        ),
      );
      return true;
    }

    final updated = entry.copyWith(status: QueueEntryStatus.surgery);
    entries[index] = updated;
    if (lastCalledId.value == entry.id) {
      lastCalledId.value = null;
    }
    if (syncDisplay) {
      _applySurgeryToDisplaySnapshot(updated);
    }

    unawaited(
      QueueAnnouncementService.instance.announcePatient(
        number: entry.number,
        name: entry.name,
      ),
    );
    _saveToCache(syncArchive: false, syncDisplay: syncDisplay);
    return true;
  }

  /// تأجيل المراجع (لم يحضر) — أحمر في الإدارة فقط (بدون تغيير شاشة العرض)
  bool postponePatient(String id) {
    ensureNewDay();
    final index = entries.indexWhere((e) => e.id == id);
    if (index == -1) {
      _showValidationError('المريض غير موجود في الطابور');
      return false;
    }

    final entry = entries[index];
    if (entry.status == QueueEntryStatus.surgery) {
      _showValidationError('لا يمكن تأجيل مراجع بعد استدعاء العملية');
      return false;
    }

    entries[index] = entry.copyWith(status: QueueEntryStatus.postponed);
    if (lastCalledId.value == entry.id) {
      lastCalledId.value = null;
    }
    _saveToCache(syncArchive: false, syncDisplay: false);
    return true;
  }

  /// توافق قديم — استدعاء بنج
  bool recallPatient(String id) => callAnesthesia(id);

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
