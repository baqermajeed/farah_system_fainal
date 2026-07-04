import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:frontend_desktop/models/sync_outbox_entry.dart';

/// تخزين دائم لطابور المزامنة.
/// منفصل عن CacheService ولا يُمسح أبداً مع مسح الكاش العادي.
class OutboxStore {
  static const String _boxName = 'syncOutboxBox';
  static const String _filesDirName = 'sync_outbox_files';

  static final OutboxStore _instance = OutboxStore._internal();
  factory OutboxStore() => _instance;
  OutboxStore._internal();

  Box? _box;
  Future<void>? _initFuture;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  bool get isReady => _box != null && _box!.isOpen;

  Future<void> init() async {
    if (isReady) return;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _initImpl();
    try {
      await _initFuture!;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _initImpl() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }

    // أي أمر توقف أثناء الإرسال يُعاد للمحاولة فوراً عند فتح التطبيق.
    await resetInterruptedSending();
  }

  Box get _requireBox {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('OutboxStore not initialized');
    }
    return box;
  }

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  /// إعادة أوامر `sending` إلى `pending` (انقطاع أثناء الرفع / إغلاق التطبيق).
  Future<void> resetInterruptedSending() async {
    final box = _requireBox;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final entry = SyncOutboxEntry.fromMap(raw);
      if (entry.status == SyncOutboxEntry.statusSending) {
        await box.put(
          entry.id,
          entry
              .copyWith(
                status: SyncOutboxEntry.statusPending,
                nextAttemptAtMs: now,
                clearLastError: true,
              )
              .toMap(),
        );
      }
    }
    _notify();
  }

  /// جعل كل الأوامر جاهزة فوراً (مثلاً عند عودة الشبكة).
  Future<void> markAllReadyNow() async {
    final box = _requireBox;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final key in box.keys.toList()) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final entry = SyncOutboxEntry.fromMap(raw);
      await box.put(
        entry.id,
        entry
            .copyWith(
              status: SyncOutboxEntry.statusPending,
              nextAttemptAtMs: now,
            )
            .toMap(),
      );
    }
    _notify();
  }

  Future<SyncOutboxEntry> enqueue({
    required String type,
    required String entityKey,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
    int priority = 0,
  }) async {
    await init();
    final id = _newId();
    final entry = SyncOutboxEntry(
      id: id,
      idempotencyKey: idempotencyKey ?? id,
      type: type,
      entityKey: entityKey,
      payload: Map<String, dynamic>.from(payload),
      status: SyncOutboxEntry.statusPending,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      priority: priority,
      nextAttemptAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    await _requireBox.put(entry.id, entry.toMap());
    // flush لضمان الكتابة على القرص قبل اعتبار العملية ناجحة محلياً
    await _requireBox.flush();
    _notify();
    return entry;
  }

  Future<void> save(SyncOutboxEntry entry) async {
    await _requireBox.put(entry.id, entry.toMap());
    await _requireBox.flush();
    _notify();
  }

  Future<void> markSending(SyncOutboxEntry entry) async {
    await save(
      entry.copyWith(
        status: SyncOutboxEntry.statusSending,
        clearLastError: true,
      ),
    );
  }

  /// فشل مؤقت — يبقى الأمر ويُعاد لاحقاً بلا نهاية.
  Future<void> scheduleRetry(SyncOutboxEntry entry, Object error) async {
    final retryCount = entry.retryCount + 1;
    final delayMs = _backoffMs(retryCount);
    await save(
      entry.copyWith(
        status: SyncOutboxEntry.statusPending,
        retryCount: retryCount,
        nextAttemptAtMs: DateTime.now().millisecondsSinceEpoch + delayMs,
        lastError: error.toString(),
      ),
    );
  }

  /// نجاح مؤكد من السيرفر — الحذف الوحيد المسموح.
  Future<void> markDone(SyncOutboxEntry entry) async {
    await _requireBox.delete(entry.id);
    await _requireBox.flush();
    await _cleanupPayloadFiles(entry);
    _notify();
  }

  Future<void> remove(String id) async {
    final existing = getById(id);
    await _requireBox.delete(id);
    await _requireBox.flush();
    if (existing != null) {
      await _cleanupPayloadFiles(existing);
    }
    _notify();
  }

  SyncOutboxEntry? getById(String id) {
    final raw = _requireBox.get(id);
    if (raw is! Map) return null;
    return SyncOutboxEntry.fromMap(raw);
  }

  List<SyncOutboxEntry> getAll() {
    final list = <SyncOutboxEntry>[];
    for (final raw in _requireBox.values) {
      if (raw is Map) {
        list.add(SyncOutboxEntry.fromMap(raw));
      }
    }
    list.sort((a, b) {
      final p = b.priority.compareTo(a.priority);
      if (p != 0) return p;
      return a.createdAtMs.compareTo(b.createdAtMs);
    });
    return list;
  }

  int get pendingCount => getAll().length;

  /// أقدم أمر جاهز للمحاولة (FIFO مع أولوية).
  SyncOutboxEntry? nextReady() {
    final now = DateTime.now().millisecondsSinceEpoch;
    SyncOutboxEntry? best;
    for (final entry in getAll()) {
      if (entry.status != SyncOutboxEntry.statusPending) continue;
      if (entry.nextAttemptAtMs > now) continue;
      best = entry;
      break;
    }
    return best;
  }

  /// متى يحين موعد أقرب إعادة محاولة (للموقّت).
  Duration? timeUntilNextAttempt() {
    final now = DateTime.now().millisecondsSinceEpoch;
    int? soonest;
    for (final entry in getAll()) {
      if (entry.status != SyncOutboxEntry.statusPending) continue;
      final t = entry.nextAttemptAtMs;
      if (soonest == null || t < soonest) soonest = t;
    }
    if (soonest == null) return null;
    final delta = soonest - now;
    if (delta <= 0) return Duration.zero;
    return Duration(milliseconds: delta);
  }

  List<SyncOutboxEntry> findByEntityKey(String entityKey) {
    return getAll().where((e) => e.entityKey == entityKey).toList();
  }

  SyncOutboxEntry? findPendingAddNote(String entityKey) {
    for (final entry in findByEntityKey(entityKey)) {
      if (entry.type == SyncOutboxEntry.typeAddNote) return entry;
    }
    return null;
  }

  /// نسخ ملفات الصور لمجلد دائم حتى لا تُفقد قبل الرفع.
  Future<List<String>> persistImageFiles({
    required String operationId,
    required List<File> files,
  }) async {
    if (files.isEmpty) return const [];

    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _filesDirName, operationId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final saved = <String>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      if (!await file.exists()) continue;
      final ext = p.extension(file.path);
      final target = File(p.join(dir.path, 'img_$i$ext'));
      await file.copy(target.path);
      saved.add(target.path);
    }
    return saved;
  }

  Future<void> _cleanupPayloadFiles(SyncOutboxEntry entry) async {
    try {
      final opId = entry.payload['operationId']?.toString();
      if (opId == null || opId.isEmpty) return;
      final root = await getApplicationSupportDirectory();
      final dir = Directory(p.join(root.path, _filesDirName, opId));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      print('⚠️ [OutboxStore] cleanup files failed: $e');
    }
  }

  static String noteEntityKey(String patientId, String noteId) =>
      'note:$patientId:$noteId';

  static String _newId() {
    final rand = Random.secure();
    final a = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final b = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    final c = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${a}_$b$c';
  }

  /// تأخير متزايد مع سقف — لا نتوقف عن المحاولة أبداً.
  static int _backoffMs(int retryCount) {
    // 1s, 2s, 4s, 8s, 16s, 30s, 30s, ...
    final exp = retryCount.clamp(0, 10);
    final ms = 1000 * (1 << (exp > 5 ? 5 : exp));
    return ms > 30000 ? 30000 : ms;
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
