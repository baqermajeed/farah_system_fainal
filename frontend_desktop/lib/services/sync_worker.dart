import 'dart:async';
import 'dart:io';

import 'package:frontend_desktop/models/sync_outbox_entry.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/outbox_store.dart';
import 'package:frontend_desktop/services/sync_events.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';

/// عامل مزامنة خلفية: يرفع أوامر الـ Outbox بالترتيب ويعيد المحاولة بلا نهاية.
/// يتوقف عند انقطاع الشبكة/إغلاق التطبيق، ويستأنف فوراً عند الفتح أو عودة الشبكة.
class SyncWorker {
  static final SyncWorker instance = SyncWorker._internal();
  SyncWorker._internal();

  final _outbox = OutboxStore();
  final _doctorService = DoctorService();
  final _cacheService = CacheService();

  bool _started = false;
  bool _processing = false;
  Timer? _wakeTimer;
  StreamSubscription<void>? _outboxSub;

  final RxPendingCount pendingCount = RxPendingCount();

  bool get isStarted => _started;

  Future<void> start() async {
    await _outbox.init();
    await _outbox.resetInterruptedSending();
    _started = true;

    _outboxSub?.cancel();
    _outboxSub = _outbox.changes.listen((_) {
      _publishPendingCount();
      unawaited(kick());
    });

    _publishPendingCount();
    await kick();
    _scheduleWake();
    print(
      '✅ [SyncWorker] Started (pending=${_outbox.pendingCount})',
    );
  }

  /// إيقاف حلقة المعالجة (عند تسجيل الخروج). الأوامر تبقى على القرص.
  void stop() {
    _started = false;
    _wakeTimer?.cancel();
    _wakeTimer = null;
    _outboxSub?.cancel();
    _outboxSub = null;
    print('⏸️ [SyncWorker] Stopped (queue preserved on disk)');
  }

  /// استئناف فوري — يُستدعى عند عودة الشبكة أو فتح التطبيق.
  Future<void> resumeNow() async {
    if (!_started) {
      await start();
      return;
    }
    await _outbox.markAllReadyNow();
    await kick();
    _scheduleWake();
  }

  Future<void> kick() async {
    if (!_started || _processing) return;
    _processing = true;
    try {
      while (_started) {
        final entry = _outbox.nextReady();
        if (entry == null) break;
        final shouldStopLoop = await _processEntry(entry);
        if (shouldStopLoop) break;
      }
    } finally {
      _processing = false;
      _publishPendingCount();
      _scheduleWake();
    }
  }

  void _scheduleWake() {
    _wakeTimer?.cancel();
    if (!_started) return;

    final wait = _outbox.timeUntilNextAttempt();
    if (wait == null) return;

    final delay = wait < const Duration(milliseconds: 200)
        ? const Duration(milliseconds: 200)
        : (wait > const Duration(seconds: 30)
            ? const Duration(seconds: 30)
            : wait);

    _wakeTimer = Timer(delay, () {
      unawaited(kick());
    });
  }

  void _publishPendingCount() {
    final count = _outbox.pendingCount;
    pendingCount.value = count;
    SyncEvents.emitPendingCount(count);
  }

  /// يعيد true لإيقاف حلقة الرفع مؤقتاً (انقطاع شبكة) حتى المحاولة التالية / resumeNow.
  Future<bool> _processEntry(SyncOutboxEntry entry) async {
    // عند انقطاع الشبكة نتوقف عن المحاولة حتى تعود الشبكة أو يُستأنف يدوياً
    final online = await NetworkUtils.hasInternetConnection();
    if (!online) {
      await _outbox.save(
        entry.copyWith(
          status: SyncOutboxEntry.statusPending,
          nextAttemptAtMs:
              DateTime.now().millisecondsSinceEpoch + 5000,
          lastError: 'offline',
        ),
      );
      print('⏸️ [SyncWorker] Offline — will retry when network returns');
      return true;
    }

    await _outbox.markSending(entry);
    try {
      switch (entry.type) {
        case SyncOutboxEntry.typeAddNote:
          await _processAddNote(entry);
          break;
        case SyncOutboxEntry.typeUpdateNote:
          await _processUpdateNote(entry);
          break;
        case SyncOutboxEntry.typeDeleteNote:
          await _processDeleteNote(entry);
          break;
        default:
          // نوع غير معروف — نبقيه ونؤجل (لا نحذف بيانات)
          await _outbox.scheduleRetry(
            entry,
            'Unknown outbox type: ${entry.type}',
          );
      }
      return false;
    } catch (e, st) {
      print('❌ [SyncWorker] Upload failed (will retry forever): $e');
      print('❌ [SyncWorker] $st');
      final latest = _outbox.getById(entry.id) ?? entry;
      await _outbox.scheduleRetry(latest, e);
      // انقطاع الشبكة: أوقف هذه الجولة؛ resumeNow أو المؤقت يعيد المحاولة
      if (NetworkUtils.isNetworkError(e)) {
        print('⏸️ [SyncWorker] Network error — pause this pass');
        return true;
      }
      return false;
    }
  }

  Future<void> _processAddNote(SyncOutboxEntry entry) async {
    final patientId = '${entry.payload['patientId'] ?? ''}';
    final localNoteId = '${entry.payload['localNoteId'] ?? ''}';
    final note = entry.payload['note']?.toString();
    final imagePaths = _readStringList(entry.payload['imagePaths']);

    if (patientId.isEmpty || localNoteId.isEmpty) {
      // بيانات تالفة — نؤجل ولا نحذف
      await _outbox.scheduleRetry(entry, 'Invalid add_note payload');
      return;
    }

    final files = <File>[];
    for (final path in imagePaths) {
      final f = File(path);
      if (await f.exists()) files.add(f);
    }

    final serverRecord = await _doctorService.addNote(
      patientId: patientId,
      note: note,
      imageFiles: files.isEmpty ? null : files,
      idempotencyKey: entry.idempotencyKey,
    );

    // استبدال السجل المحلي بالسجل الحقيقي في الكاش
    try {
      await _cacheService.deleteMedicalRecord(patientId, localNoteId);
      await _cacheService.saveMedicalRecord(serverRecord);
    } catch (e) {
      print('⚠️ [SyncWorker] Cache update after add_note: $e');
    }

    // أي تحديث/حذف معلّق على المعرف المحلي يُحوَّل لمعرف السيرفر
    await _remapLocalNoteId(
      patientId: patientId,
      localNoteId: localNoteId,
      serverNoteId: serverRecord.id,
    );

    await _outbox.markDone(entry);

    SyncEvents.emitNoteSynced(
      NoteSyncedEvent(
        patientId: patientId,
        localNoteId: localNoteId,
        serverRecord: serverRecord,
      ),
    );

    print(
      '✅ [SyncWorker] add_note synced $localNoteId -> ${serverRecord.id}',
    );
  }

  Future<void> _remapLocalNoteId({
    required String patientId,
    required String localNoteId,
    required String serverNoteId,
  }) async {
    final oldKey = OutboxStore.noteEntityKey(patientId, localNoteId);
    final newKey = OutboxStore.noteEntityKey(patientId, serverNoteId);

    for (final entry in _outbox.getAll()) {
      final payload = Map<String, dynamic>.from(entry.payload);
      var changed = false;

      if (payload['noteId']?.toString() == localNoteId) {
        payload['noteId'] = serverNoteId;
        changed = true;
      }
      if (payload['localNoteId']?.toString() == localNoteId) {
        payload['localNoteId'] = serverNoteId;
        changed = true;
      }

      final entityKey =
          entry.entityKey == oldKey ? newKey : entry.entityKey;

      if (changed || entityKey != entry.entityKey) {
        await _outbox.save(
          SyncOutboxEntry(
            id: entry.id,
            idempotencyKey: entry.idempotencyKey,
            type: entry.type,
            entityKey: entityKey,
            payload: payload,
            status: SyncOutboxEntry.statusPending,
            createdAtMs: entry.createdAtMs,
            priority: entry.priority,
            retryCount: entry.retryCount,
            nextAttemptAtMs: DateTime.now().millisecondsSinceEpoch,
            lastError: entry.lastError,
          ),
        );
      }
    }
  }

  Future<void> _processUpdateNote(SyncOutboxEntry entry) async {
    final patientId = '${entry.payload['patientId'] ?? ''}';
    final noteId = '${entry.payload['noteId'] ?? ''}';
    final note = entry.payload['note']?.toString();
    final imagePaths = _readStringList(entry.payload['imagePaths']);

    if (patientId.isEmpty || noteId.isEmpty) {
      await _outbox.scheduleRetry(entry, 'Invalid update_note payload');
      return;
    }

    // لم يُرفع الإنشاء بعد — نؤجل التحديث حتى ينجح add_note
    if (noteId.startsWith('local_')) {
      await _outbox.scheduleRetry(
        entry,
        'Waiting for local note create to sync',
      );
      return;
    }

    final files = <File>[];
    for (final path in imagePaths) {
      final f = File(path);
      if (await f.exists()) files.add(f);
    }

    final serverRecord = await _doctorService.updateNote(
      patientId: patientId,
      noteId: noteId,
      note: note,
      imageFiles: files.isEmpty ? null : files,
      idempotencyKey: entry.idempotencyKey,
    );

    try {
      await _cacheService.saveMedicalRecord(serverRecord);
    } catch (e) {
      print('⚠️ [SyncWorker] Cache update after update_note: $e');
    }

    await _outbox.markDone(entry);

    SyncEvents.emitNoteSynced(
      NoteSyncedEvent(
        patientId: patientId,
        localNoteId: noteId,
        serverRecord: serverRecord,
      ),
    );

    print('✅ [SyncWorker] update_note synced $noteId');
  }

  Future<void> _processDeleteNote(SyncOutboxEntry entry) async {
    final patientId = '${entry.payload['patientId'] ?? ''}';
    final noteId = '${entry.payload['noteId'] ?? ''}';

    if (patientId.isEmpty || noteId.isEmpty) {
      await _outbox.scheduleRetry(entry, 'Invalid delete_note payload');
      return;
    }

    if (noteId.startsWith('local_')) {
      await _outbox.scheduleRetry(
        entry,
        'Waiting for local note create to sync',
      );
      return;
    }

    try {
      await _doctorService.deleteNote(
        patientId: patientId,
        noteId: noteId,
        idempotencyKey: entry.idempotencyKey,
      );
    } on ApiException catch (e) {
      // الحذف مرتين = نجاح (at-least-once)
      final isNotFound = e.statusCode == 404 ||
          e is NotFoundException ||
          e.message.toLowerCase().contains('not found') ||
          e.message.contains('غير موجود');
      if (!isNotFound) rethrow;
    }

    try {
      await _cacheService.deleteMedicalRecord(patientId, noteId);
    } catch (e) {
      print('⚠️ [SyncWorker] Cache delete after delete_note: $e');
    }

    await _outbox.markDone(entry);

    SyncEvents.emitNoteRemoved(
      NoteRemovedEvent(patientId: patientId, noteId: noteId),
    );

    print('✅ [SyncWorker] delete_note synced $noteId');
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
}

/// عدّاد بسيط بدون الاعتماد على GetX داخل الخدمة.
class RxPendingCount {
  int _value = 0;
  final _controller = StreamController<int>.broadcast();

  int get value => _value;
  Stream<int> get stream => _controller.stream;

  set value(int v) {
    if (_value == v) return;
    _value = v;
    if (!_controller.isClosed) _controller.add(v);
  }
}
