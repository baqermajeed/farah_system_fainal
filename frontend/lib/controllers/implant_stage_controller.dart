import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:farah_sys_final/models/implant_stage_model.dart';
import 'package:farah_sys_final/services/implant_stage_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';

class ImplantStageController extends GetxController {
  final _implantStageService = ImplantStageService();

  final RxList<ImplantStageModel> stages = <ImplantStageModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxString errorMessage = ''.obs;

  /// Prevent request storms (e.g. calling loadStages from build/Obx multiple times)
  final Set<String> _inFlightPatientIds = <String>{};
  final Set<String> _loadedOncePatientIds = <String>{};

  String _cacheKey(String patientId) => 'patient_$patientId';

  bool hasStagesForPatient(String patientId) {
    return stages.any((s) => s.patientId == patientId);
  }

  List<ImplantStageModel> stagesForPatient(String patientId) {
    return stages.where((s) => s.patientId == patientId).toList();
  }

  /// Load stages once per patient unless you explicitly call [loadStages] to refresh.
  Future<void> ensureStagesLoaded(String patientId) async {
    if (_loadedOncePatientIds.contains(patientId) ||
        _inFlightPatientIds.contains(patientId) ||
        hasStagesForPatient(patientId)) {
      // خلفية: حدّث إن وُجد كاش/ذاكرة بدون إظهار تحميل كامل
      if (hasStagesForPatient(patientId) || _hasCache(patientId)) {
        unawaited(loadStages(patientId, silent: true));
      }
      return;
    }

    _inFlightPatientIds.add(patientId);
    try {
      await loadStages(patientId);
    } finally {
      _inFlightPatientIds.remove(patientId);
      _loadedOncePatientIds.add(patientId);
    }
  }

  bool _hasCache(String patientId) {
    try {
      final box = Hive.box('implantStages');
      final cached = box.get(_cacheKey(patientId));
      return cached is List && cached.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  List<ImplantStageModel> _readCache(String patientId) {
    try {
      final box = Hive.box('implantStages');
      final cachedList = box.get(_cacheKey(patientId));
      if (cachedList is! List) return const [];
      return cachedList
          .map(
            (json) => ImplantStageModel.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ImplantStageController] cache read error: $e');
      }
      return const [];
    }
  }

  Future<void> _writeCache(
    String patientId,
    List<ImplantStageModel> list,
  ) async {
    try {
      final box = Hive.box('implantStages');
      await box.put(
        _cacheKey(patientId),
        list.map((s) => s.toJson()).toList(),
      );
      await box.put(
        '${_cacheKey(patientId)}_lastUpdated',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ImplantStageController] cache write error: $e');
      }
    }
  }

  void _applyPatientStages(
    String patientId,
    List<ImplantStageModel> loadedStages,
  ) {
    if (_listEquals(stagesForPatient(patientId), loadedStages)) {
      return;
    }
    stages.removeWhere((s) => s.patientId == patientId);
    stages.addAll(loadedStages);
  }

  bool _listEquals(
    List<ImplantStageModel> a,
    List<ImplantStageModel> b,
  ) {
    if (a.length != b.length) return false;
    final byId = {for (final s in a) s.id: s};
    for (final other in b) {
      final cur = byId[other.id];
      if (cur == null) return false;
      if (cur.stageName != other.stageName ||
          cur.isCompleted != other.isCompleted ||
          cur.scheduledAt != other.scheduledAt ||
          cur.appointmentId != other.appointmentId ||
          cur.updatedAt != other.updatedAt) {
        return false;
      }
    }
    return true;
  }

  /// تحميل المراحل: كاش أولاً ثم تحديث بالخلفية إن تغيّر شيء.
  /// [silent] = true → لا يُظهر شاشة التحميل الكاملة (تحديث خلفي).
  Future<void> loadStages(
    String patientId, {
    bool silent = false,
  }) async {
    _loadedOncePatientIds.add(patientId);

    // 1) كاش / ذاكرة أولاً
    final hadMemory = hasStagesForPatient(patientId);
    if (!hadMemory) {
      final cached = _readCache(patientId);
      if (cached.isNotEmpty) {
        _applyPatientStages(patientId, cached);
      }
    }

    final hasLocal = hasStagesForPatient(patientId);
    if (!silent && !hasLocal) {
      isLoading.value = true;
    } else if (hasLocal) {
      isRefreshing.value = true;
    }

    try {
      errorMessage.value = '';
      final loadedStages =
          await _implantStageService.getImplantStages(patientId);
      _applyPatientStages(patientId, loadedStages);
      await _writeCache(patientId, loadedStages);
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      if (!hasLocal) {
        await NetworkUtils.showError(e);
      }
      if (kDebugMode) {
        debugPrint('[ImplantStageController] ApiException: ${e.message}');
      }
    } catch (e) {
      errorMessage.value = 'فشل تحميل المراحل: ${e.toString()}';
      if (!hasLocal) {
        await NetworkUtils.showError(
          e,
          fallbackMessage: 'فشل تحميل المراحل',
        );
      }
      if (kDebugMode) {
        debugPrint('[ImplantStageController] Error: $e');
      }
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  /// Batch load stages for multiple patients.
  Future<void> loadStagesForPatients(List<String> patientIds) async {
    if (patientIds.isEmpty) return;

    try {
      for (final id in patientIds) {
        if (!hasStagesForPatient(id)) {
          final cached = _readCache(id);
          if (cached.isNotEmpty) {
            _applyPatientStages(id, cached);
          }
        }
      }

      final stillMissing =
          patientIds.where((id) => !hasStagesForPatient(id)).toList();
      if (stillMissing.isNotEmpty) {
        isLoading.value = true;
      } else {
        isRefreshing.value = true;
      }
      errorMessage.value = '';
      _loadedOncePatientIds.addAll(patientIds);

      final results = await Future.wait(
        patientIds.map((id) => _implantStageService.getImplantStages(id)),
      );

      for (var i = 0; i < patientIds.length; i++) {
        final id = patientIds[i];
        final loaded = results[i];
        _applyPatientStages(id, loaded);
        await _writeCache(id, loaded);
      }
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      if (kDebugMode) {
        debugPrint('[ImplantStageController] ApiException: ${e.message}');
      }
    } catch (e) {
      errorMessage.value = 'فشل تحميل المراحل: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('[ImplantStageController] Error: $e');
      }
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<void> initializeStages(String patientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final initializedStages =
          await _implantStageService.initializeImplantStages(patientId);
      _applyPatientStages(patientId, initializedStages);
      await _writeCache(patientId, initializedStages);
      _loadedOncePatientIds.add(patientId);
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      if (kDebugMode) {
        debugPrint('[ImplantStageController] ApiException: ${e.message}');
      }
    } catch (e) {
      errorMessage.value = 'فشل تهيئة المراحل: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('[ImplantStageController] Error: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateStageDate(
    String patientId,
    String stageName,
    DateTime date,
    String time,
  ) async {
    ImplantStageModel? oldStage;

    try {
      errorMessage.value = '';

      final index = stages.indexWhere(
        (s) => s.patientId == patientId && s.stageName == stageName,
      );
      if (index != -1) {
        oldStage = stages[index];

        final timeParts = time.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute =
            timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
        final localDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        stages[index] = ImplantStageModel(
          id: oldStage.id,
          patientId: oldStage.patientId,
          stageName: oldStage.stageName,
          scheduledAt: localDateTime,
          isCompleted: oldStage.isCompleted,
          appointmentId: oldStage.appointmentId,
          createdAt: oldStage.createdAt,
          updatedAt: DateTime.now(),
        );
      }

      final updatedStage = await _implantStageService.updateStageDate(
        patientId,
        stageName,
        date,
        time,
      );

      final newIndex = stages.indexWhere((s) => s.id == updatedStage.id);
      if (newIndex != -1) {
        stages[newIndex] = updatedStage;
      }
      await _writeCache(patientId, stagesForPatient(patientId));

      return true;
    } on ApiException catch (e) {
      if (oldStage != null) {
        final original = oldStage;
        final index = stages.indexWhere((s) => s.id == original.id);
        if (index != -1) {
          stages[index] = original;
        }
      }
      errorMessage.value = e.message;
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
      return false;
    } catch (e) {
      if (oldStage != null) {
        final original = oldStage;
        final index = stages.indexWhere((s) => s.id == original.id);
        if (index != -1) {
          stages[index] = original;
        }
      }
      errorMessage.value = 'فشل تحديث التاريخ: ${e.toString()}';
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
      return false;
    }
  }

  Future<bool> completeStage(String patientId, String stageName) async {
    ImplantStageModel? oldStage;

    try {
      errorMessage.value = '';

      final index = stages.indexWhere(
        (s) => s.patientId == patientId && s.stageName == stageName,
      );
      if (index != -1) {
        oldStage = stages[index];
        stages[index] = ImplantStageModel(
          id: oldStage.id,
          patientId: oldStage.patientId,
          stageName: oldStage.stageName,
          scheduledAt: oldStage.scheduledAt,
          isCompleted: true,
          appointmentId: oldStage.appointmentId,
          createdAt: oldStage.createdAt,
          updatedAt: DateTime.now(),
        );
      }

      final completedStage =
          await _implantStageService.completeStage(patientId, stageName);

      final newIndex = stages.indexWhere((s) => s.id == completedStage.id);
      if (newIndex != -1) {
        stages[newIndex] = completedStage;
      } else {
        stages.add(completedStage);
      }
      await _writeCache(patientId, stagesForPatient(patientId));

      return true;
    } on ApiException catch (e) {
      if (oldStage != null) {
        final original = oldStage;
        final index = stages.indexWhere((s) => s.id == original.id);
        if (index != -1) {
          stages[index] = original;
        }
      }
      errorMessage.value = e.message;
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
      return false;
    } catch (e) {
      if (oldStage != null) {
        final original = oldStage;
        final index = stages.indexWhere((s) => s.id == original.id);
        if (index != -1) {
          stages[index] = original;
        }
      }
      errorMessage.value = 'فشل إكمال المرحلة: ${e.toString()}';
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
      return false;
    }
  }

  Future<bool> uncompleteStage(String patientId, String stageName) async {
    ImplantStageModel? oldStage;

    try {
      errorMessage.value = '';

      final index = stages.indexWhere(
        (s) => s.patientId == patientId && s.stageName == stageName,
      );
      if (index != -1) {
        oldStage = stages[index];
        stages[index] = ImplantStageModel(
          id: oldStage.id,
          patientId: oldStage.patientId,
          stageName: oldStage.stageName,
          scheduledAt: oldStage.scheduledAt,
          isCompleted: false,
          appointmentId: oldStage.appointmentId,
          createdAt: oldStage.createdAt,
          updatedAt: DateTime.now(),
        );
      }

      final uncompletedStage =
          await _implantStageService.uncompleteStage(patientId, stageName);

      final newIndex = stages.indexWhere((s) => s.id == uncompletedStage.id);
      if (newIndex != -1) {
        stages[newIndex] = uncompletedStage;
      }
      await _writeCache(patientId, stagesForPatient(patientId));

      return true;
    } on ApiException catch (e) {
      if (oldStage != null) {
        final original = oldStage;
        final index = stages.indexWhere((s) => s.id == original.id);
        if (index != -1) {
          stages[index] = original;
        }
      }
      errorMessage.value = e.message;
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
      return false;
    } catch (e) {
      if (oldStage != null) {
        final original = oldStage;
        final index = stages.indexWhere((s) => s.id == original.id);
        if (index != -1) {
          stages[index] = original;
        }
      }
      errorMessage.value = 'فشل إلغاء إكمال المرحلة: ${e.toString()}';
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
      return false;
    }
  }
}
