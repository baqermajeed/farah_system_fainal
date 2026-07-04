import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';
import 'package:frontend_desktop/models/medical_record_model.dart';
import 'package:frontend_desktop/models/sync_outbox_entry.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/services/outbox_store.dart';
import 'package:frontend_desktop/services/sync_worker.dart';
import 'package:frontend_desktop/services/sync_events.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';

class MedicalRecordController extends GetxController {
  final _doctorService = DoctorService();
  final _cacheService = CacheService();
  final _outbox = OutboxStore();

  final RxList<MedicalRecordModel> records = <MedicalRecordModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt pendingSyncCount = 0.obs;

  String? _activePatientId;
  StreamSubscription<NoteSyncedEvent>? _syncedSub;
  StreamSubscription<NoteRemovedEvent>? _removedSub;
  StreamSubscription<int>? _pendingSub;

  @override
  void onInit() {
    super.onInit();
    _syncedSub = SyncEvents.noteSynced.listen(_onNoteSynced);
    _removedSub = SyncEvents.noteRemoved.listen(_onNoteRemoved);
    _pendingSub = SyncEvents.pendingCount.listen((count) {
      pendingSyncCount.value = count;
    });
    pendingSyncCount.value = SyncWorker.instance.pendingCount.value;
  }

  @override
  void onClose() {
    _syncedSub?.cancel();
    _removedSub?.cancel();
    _pendingSub?.cancel();
    super.onClose();
  }

  void _onNoteSynced(NoteSyncedEvent event) {
    if (_activePatientId != null && event.patientId != _activePatientId) {
      return;
    }
    final index = records.indexWhere((r) => r.id == event.localNoteId);
    if (index != -1) {
      records[index] = event.serverRecord;
    } else if (!records.any((r) => r.id == event.serverRecord.id)) {
      records.insert(0, event.serverRecord);
    }
  }

  void _onNoteRemoved(NoteRemovedEvent event) {
    if (_activePatientId != null && event.patientId != _activePatientId) {
      return;
    }
    records.removeWhere((r) => r.id == event.noteId);
  }

  /// الطبيب: لوكال + Outbox. الاستقبال وباقي الأدوار: سيرفر مباشرة.
  bool get _useLocalOutbox {
    try {
      if (!Get.isRegistered<AuthController>()) return false;
      final type =
          Get.find<AuthController>().currentUser.value?.userType.toLowerCase();
      return type == 'doctor';
    } catch (_) {
      return false;
    }
  }

  /// جلب سجلات مريض: كاش فوري + دمج السجلات المحلية المعلّقة + تحديث من السيرفر.
  Future<void> loadPatientRecords(String patientId) async {
    _activePatientId = patientId;
    try {
      final cachedRecords = _cacheService.getMedicalRecords(patientId);
      if (cachedRecords.isNotEmpty) {
        records.value = _sortRecords(cachedRecords);
      }

      // سبينر فقط عند عدم وجود بيانات معروضة
      if (records.isEmpty) {
        isLoading.value = true;
      }

      try {
        final recordsList = await _doctorService.getPatientNotes(
          patientId: patientId,
        );
        records.value = _mergeWithLocalPending(patientId, recordsList);

        try {
          await _cacheService.saveMedicalRecords(patientId, records.toList());
        } catch (e) {
          print('❌ [MedicalRecordController] Error updating cache: $e');
        }
      } on ApiException catch (e) {
        if (cachedRecords.isEmpty) {
          if (NetworkUtils.isNetworkError(e)) {
            NetworkUtils.showNetworkErrorDialog();
          } else {
            Get.snackbar('خطأ', 'خطا');
          }
        }
        // مع وجود كاش محلي نكمل العمل بدون حظر
      } catch (e) {
        if (cachedRecords.isEmpty) {
          if (NetworkUtils.isNetworkError(e)) {
            NetworkUtils.showNetworkErrorDialog();
          } else {
            Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل السجلات');
          }
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// دمج بيانات السيرفر مع السجلات المحلية التي لم تُرفع بعد.
  List<MedicalRecordModel> _mergeWithLocalPending(
    String patientId,
    List<MedicalRecordModel> serverRecords,
  ) {
    final merged = <MedicalRecordModel>[];
    final serverIds = serverRecords.map((r) => r.id).toSet();

    // سجلات محلية معلّقة (local_*) تبقى ظاهرة حتى تُرفع
    final localPending = _cacheService
        .getMedicalRecords(patientId)
        .where((r) => r.id.startsWith('local_'))
        .toList();

    for (final local in localPending) {
      if (!serverIds.contains(local.id)) {
        merged.add(local);
      }
    }

    // تطبيق تعديلات معلّقة على سجلات السيرفر
    for (final server in serverRecords) {
      final pendingUpdate = _findPendingUpdatePayload(patientId, server.id);
      if (pendingUpdate != null) {
        final noteText = pendingUpdate['note']?.toString() ?? server.notes;
        merged.add(
          MedicalRecordModel(
            id: server.id,
            patientId: server.patientId,
            doctorId: server.doctorId,
            date: server.date,
            treatmentType: server.treatmentType,
            diagnosis: noteText ?? server.diagnosis,
            images: server.images,
            notes: noteText,
          ),
        );
      } else {
        merged.add(server);
      }
    }

    // استبعاد سجلات عليها حذف معلّق
    final pendingDeletes = _pendingDeleteIds(patientId);
    merged.removeWhere((r) => pendingDeletes.contains(r.id));

    return _sortRecords(merged);
  }

  Map<String, dynamic>? _findPendingUpdatePayload(
    String patientId,
    String noteId,
  ) {
    if (!_outbox.isReady) return null;
    final key = OutboxStore.noteEntityKey(patientId, noteId);
    for (final entry in _outbox.findByEntityKey(key)) {
      if (entry.type == SyncOutboxEntry.typeUpdateNote) {
        return entry.payload;
      }
    }
    return null;
  }

  Set<String> _pendingDeleteIds(String patientId) {
    if (!_outbox.isReady) return {};
    final ids = <String>{};
    for (final entry in _outbox.getAll()) {
      if (entry.type != SyncOutboxEntry.typeDeleteNote) continue;
      if (entry.payload['patientId']?.toString() != patientId) continue;
      final noteId = entry.payload['noteId']?.toString();
      if (noteId != null && noteId.isNotEmpty) ids.add(noteId);
    }
    return ids;
  }

  List<MedicalRecordModel> _sortRecords(List<MedicalRecordModel> list) {
    final sorted = List<MedicalRecordModel>.from(list);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  /// إضافة سجل: للطبيب محلي+Outbox؛ للاستقبال مباشرة على السيرفر.
  Future<void> addRecord({
    required String patientId,
    String? note,
    List<File>? imageFiles,
  }) async {
    if (!_useLocalOutbox) {
      await _addRecordOnline(
        patientId: patientId,
        note: note,
        imageFiles: imageFiles,
      );
      return;
    }

    await _outbox.init();

    final localNoteId = 'local_${_newId()}';
    final operationId = _newId();
    final entityKey = OutboxStore.noteEntityKey(patientId, localNoteId);

    final durableImages = await _outbox.persistImageFiles(
      operationId: operationId,
      files: imageFiles ?? const [],
    );

    final localRecord = MedicalRecordModel(
      id: localNoteId,
      patientId: patientId,
      doctorId: '',
      date: DateTime.now(),
      treatmentType: '',
      diagnosis: note ?? '',
      images: durableImages.isEmpty ? null : durableImages,
      notes: note,
    );

    // 1) القرص أولاً: الكاش + الـ Outbox
    await _cacheService.saveMedicalRecord(localRecord);
    await _outbox.enqueue(
      type: SyncOutboxEntry.typeAddNote,
      entityKey: entityKey,
      idempotencyKey: operationId,
      payload: {
        'operationId': operationId,
        'patientId': patientId,
        'localNoteId': localNoteId,
        'note': note,
        'imagePaths': durableImages,
      },
    );

    // 2) الواجهة فوراً
    records.insert(0, localRecord);

    // 3) رفع بالخلفية (يعيد المحاولة بلا نهاية)
    unawaited(SyncWorker.instance.kick());

    Get.snackbar('نجح', 'تم حفظ السجل وسيُرفع تلقائياً');
  }

  Future<void> _addRecordOnline({
    required String patientId,
    String? note,
    List<File>? imageFiles,
  }) async {
    MedicalRecordModel? tempRecord;
    try {
      tempRecord = MedicalRecordModel(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        patientId: patientId,
        doctorId: '',
        date: DateTime.now(),
        treatmentType: '',
        diagnosis: note ?? '',
        images: null,
        notes: note,
      );
      records.insert(0, tempRecord);

      final newRecord = await _doctorService.addNote(
        patientId: patientId,
        note: note,
        imageFiles: imageFiles,
      );

      final index = records.indexWhere((r) => r.id == tempRecord!.id);
      if (index != -1) {
        records[index] = newRecord;
      } else {
        records.insert(0, newRecord);
      }

      try {
        await _cacheService.saveMedicalRecord(newRecord);
      } catch (e) {
        print('❌ [MedicalRecordController] Error updating cache: $e');
      }

      Get.snackbar('نجح', 'تم إضافة السجل بنجاح');
    } on ApiException catch (e) {
      if (tempRecord != null) {
        records.removeWhere((r) => r.id == tempRecord!.id);
      }
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
      rethrow;
    } catch (e) {
      if (tempRecord != null) {
        records.removeWhere((r) => r.id == tempRecord!.id);
      }
      NetworkUtils.showNetworkErrorDialog();
      rethrow;
    }
  }

  /// تحديث سجل: محلي فوراً ثم رفع بالخلفية.
  Future<void> updateRecord({
    required String patientId,
    required String recordId,
    String? note,
    List<File>? imageFiles,
  }) async {
    if (!_useLocalOutbox) {
      await _updateRecordOnline(
        patientId: patientId,
        recordId: recordId,
        note: note,
        imageFiles: imageFiles,
      );
      return;
    }

    await _outbox.init();

    final existing = getRecordById(recordId);
    final entityKey = OutboxStore.noteEntityKey(patientId, recordId);

    // سجل لم يُرفع بعد: نحدّث أمر الإنشاء المعلّق بدل أمر تحديث منفصل
    if (recordId.startsWith('local_')) {
      final pendingAdd = _outbox.findPendingAddNote(entityKey);
      if (pendingAdd != null) {
        final operationId =
            pendingAdd.payload['operationId']?.toString() ?? pendingAdd.id;
        var durableImages =
            _readStringList(pendingAdd.payload['imagePaths']);
        if (imageFiles != null && imageFiles.isNotEmpty) {
          durableImages = await _outbox.persistImageFiles(
            operationId: '${operationId}_upd',
            files: imageFiles,
          );
        }

        final payload = Map<String, dynamic>.from(pendingAdd.payload);
        payload['note'] = note;
        payload['imagePaths'] = durableImages;
        await _outbox.save(
          pendingAdd.copyWith(
            payload: payload,
            status: SyncOutboxEntry.statusPending,
            nextAttemptAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        final updatedLocal = MedicalRecordModel(
          id: recordId,
          patientId: patientId,
          doctorId: existing?.doctorId ?? '',
          date: existing?.date ?? DateTime.now(),
          treatmentType: existing?.treatmentType ?? '',
          diagnosis: note ?? existing?.diagnosis ?? '',
          images: durableImages.isEmpty ? existing?.images : durableImages,
          notes: note,
        );
        await _cacheService.saveMedicalRecord(updatedLocal);
        final index = records.indexWhere((r) => r.id == recordId);
        if (index != -1) records[index] = updatedLocal;

        unawaited(SyncWorker.instance.kick());
        Get.snackbar('نجح', 'تم حفظ التعديل وسيُرفع تلقائياً');
        return;
      }
    }

    final operationId = _newId();
    final durableImages = await _outbox.persistImageFiles(
      operationId: operationId,
      files: imageFiles ?? const [],
    );

    final updatedLocal = MedicalRecordModel(
      id: recordId,
      patientId: patientId,
      doctorId: existing?.doctorId ?? '',
      date: existing?.date ?? DateTime.now(),
      treatmentType: existing?.treatmentType ?? '',
      diagnosis: note ?? existing?.diagnosis ?? '',
      images: durableImages.isEmpty ? existing?.images : durableImages,
      notes: note ?? existing?.notes,
    );

    await _cacheService.saveMedicalRecord(updatedLocal);

    // دمج مع تحديث معلّق سابق لنفس السجل
    final existingUpdates = _outbox
        .findByEntityKey(entityKey)
        .where((e) => e.type == SyncOutboxEntry.typeUpdateNote)
        .toList();
    for (final old in existingUpdates) {
      await _outbox.remove(old.id);
    }

    await _outbox.enqueue(
      type: SyncOutboxEntry.typeUpdateNote,
      entityKey: entityKey,
      idempotencyKey: operationId,
      payload: {
        'operationId': operationId,
        'patientId': patientId,
        'noteId': recordId,
        'note': note,
        'imagePaths': durableImages,
      },
    );

    final index = records.indexWhere((r) => r.id == recordId);
    if (index != -1) {
      records[index] = updatedLocal;
    }

    unawaited(SyncWorker.instance.kick());
    Get.snackbar('نجح', 'تم حفظ التعديل وسيُرفع تلقائياً');
  }

  Future<void> _updateRecordOnline({
    required String patientId,
    required String recordId,
    String? note,
    List<File>? imageFiles,
  }) async {
    try {
      final updatedRecord = await _doctorService.updateNote(
        patientId: patientId,
        noteId: recordId,
        note: note,
        imageFiles: imageFiles,
      );
      final index = records.indexWhere((r) => r.id == recordId);
      if (index != -1) {
        records[index] = updatedRecord;
      }
      try {
        await _cacheService.saveMedicalRecord(updatedRecord);
      } catch (e) {
        print('❌ [MedicalRecordController] Error updating cache: $e');
      }
      Get.snackbar('نجح', 'تم تحديث السجل بنجاح');
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
      rethrow;
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث السجل');
      }
      rethrow;
    }
  }

  /// حذف سجل: محلي فوراً ثم رفع بالخلفية (أو إلغاء إنشاء معلّق).
  Future<void> deleteRecord({
    required String patientId,
    required String recordId,
  }) async {
    if (!_useLocalOutbox) {
      await _deleteRecordOnline(patientId: patientId, recordId: recordId);
      return;
    }

    await _outbox.init();
    final entityKey = OutboxStore.noteEntityKey(patientId, recordId);

    // لم يصل للسيرفر بعد: إلغاء أمر الإنشاء فقط
    if (recordId.startsWith('local_')) {
      final pendingAdd = _outbox.findPendingAddNote(entityKey);
      if (pendingAdd != null) {
        await _outbox.remove(pendingAdd.id);
      }
      for (final entry in _outbox.findByEntityKey(entityKey)) {
        await _outbox.remove(entry.id);
      }
      await _cacheService.deleteMedicalRecord(patientId, recordId);
      records.removeWhere((r) => r.id == recordId);
      Get.snackbar('نجح', 'تم حذف السجل');
      return;
    }

    await _cacheService.deleteMedicalRecord(patientId, recordId);
    records.removeWhere((r) => r.id == recordId);

    // إلغاء تحديثات معلّقة واستبدالها بحذف واحد
    for (final entry in _outbox.findByEntityKey(entityKey)) {
      if (entry.type == SyncOutboxEntry.typeUpdateNote ||
          entry.type == SyncOutboxEntry.typeDeleteNote) {
        await _outbox.remove(entry.id);
      }
    }

    final operationId = _newId();
    await _outbox.enqueue(
      type: SyncOutboxEntry.typeDeleteNote,
      entityKey: entityKey,
      idempotencyKey: operationId,
      payload: {
        'operationId': operationId,
        'patientId': patientId,
        'noteId': recordId,
      },
    );

    unawaited(SyncWorker.instance.kick());
    Get.snackbar('نجح', 'تم الحذف وسيُزامن تلقائياً');
  }

  Future<void> _deleteRecordOnline({
    required String patientId,
    required String recordId,
  }) async {
    try {
      await _doctorService.deleteNote(
        patientId: patientId,
        noteId: recordId,
      );
      records.removeWhere((r) => r.id == recordId);
      try {
        await _cacheService.deleteMedicalRecord(patientId, recordId);
      } catch (e) {
        print('❌ [MedicalRecordController] Error deleting from cache: $e');
      }
      Get.snackbar('نجح', 'تم حذف السجل بنجاح');
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
      rethrow;
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء حذف السجل');
      }
      rethrow;
    }
  }

  MedicalRecordModel? getRecordById(String recordId) {
    try {
      return records.firstWhere((r) => r.id == recordId);
    } catch (_) {
      return null;
    }
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  String _newId() {
    final rand = Random.secure();
    final a = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final b = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    final c = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${a}_$b$c';
  }
}
