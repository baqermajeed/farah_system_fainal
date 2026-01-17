import 'package:get/get.dart';
import 'package:frontend_desktop/models/implant_stage_model.dart';
import 'package:frontend_desktop/services/implant_stage_service.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';

class ImplantStageController extends GetxController {
  final _implantStageService = ImplantStageService();

  final RxList<ImplantStageModel> stages = <ImplantStageModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Prevent request storms (e.g. calling loadStages from build/Obx multiple times)
  final Set<String> _inFlightPatientIds = <String>{};
  final Set<String> _loadedOncePatientIds = <String>{};

  bool hasStagesForPatient(String patientId) {
    return stages.any((s) => s.patientId == patientId);
  }

  List<ImplantStageModel> stagesForPatient(String patientId) {
    return stages.where((s) => s.patientId == patientId).toList();
  }

  /// Load stages once per patient unless you explicitly call [loadStages] to refresh.
  Future<void> ensureStagesLoaded(String patientId) async {
    // If we already tried once (even if empty) don't keep hammering the backend.
    if (_loadedOncePatientIds.contains(patientId) || _inFlightPatientIds.contains(patientId)) {
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

  // تحميل مراحل زراعة الأسنان للمريض
  Future<void> loadStages(String patientId) async {
    // Mark as attempted to avoid loops when the result is legitimately empty.
    _loadedOncePatientIds.add(patientId);
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final loadedStages = await _implantStageService.getImplantStages(patientId);
      // Merge stages for this patient into the global list (don't overwrite other patients)
      stages.removeWhere((s) => s.patientId == patientId);
      stages.addAll(loadedStages);
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [ImplantStageController] ApiException: ${e.message}');
    } catch (e) {
      errorMessage.value = 'فشل تحميل المراحل: ${e.toString()}';
      print('❌ [ImplantStageController] Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Batch load stages for multiple patients.
  /// This reduces repeated UI rebuilds and avoids overwriting stages.
  Future<void> loadStagesForPatients(List<String> patientIds) async {
    if (patientIds.isEmpty) return;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Mark as attempted to avoid loops.
      _loadedOncePatientIds.addAll(patientIds);

      final results = await Future.wait(
        patientIds.map((id) => _implantStageService.getImplantStages(id)),
      );

      // Remove old stages for these patients, then add all loaded stages in one go.
      final setIds = patientIds.toSet();
      stages.removeWhere((s) => setIds.contains(s.patientId));
      stages.addAll(results.expand((x) => x));
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [ImplantStageController] ApiException: ${e.message}');
    } catch (e) {
      errorMessage.value = 'فشل تحميل المراحل: ${e.toString()}';
      print('❌ [ImplantStageController] Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // تهيئة مراحل زراعة الأسنان
  Future<void> initializeStages(String patientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final initializedStages = await _implantStageService.initializeImplantStages(patientId);
      // Merge for this patient (don't overwrite other patients)
      stages.removeWhere((s) => s.patientId == patientId);
      stages.addAll(initializedStages);
      _loadedOncePatientIds.add(patientId);
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [ImplantStageController] ApiException: ${e.message}');
    } catch (e) {
      errorMessage.value = 'فشل تهيئة المراحل: ${e.toString()}';
      print('❌ [ImplantStageController] Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // تحديث تاريخ مرحلة
  Future<bool> updateStageDate(
    String patientId,
    String stageName,
    DateTime date,
    String time,
  ) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final updatedStage = await _implantStageService.updateStageDate(
        patientId,
        stageName,
        date,
        time,
      );

      // تحديث المرحلة في القائمة
      final index = stages.indexWhere((s) => s.id == updatedStage.id);
      if (index != -1) {
        stages[index] = updatedStage;
      }

      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [ImplantStageController] ApiException: ${e.message}');
      return false;
    } catch (e) {
      errorMessage.value = 'فشل تحديث التاريخ: ${e.toString()}';
      print('❌ [ImplantStageController] Error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // إكمال مرحلة
  Future<bool> completeStage(String patientId, String stageName) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _implantStageService.completeStage(
        patientId,
        stageName,
      );

      // إعادة تحميل جميع المراحل لأن المرحلة التالية قد تم إنشاؤها تلقائياً
      await loadStages(patientId);

      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [ImplantStageController] ApiException: ${e.message}');
      return false;
    } catch (e) {
      errorMessage.value = 'فشل إكمال المرحلة: ${e.toString()}';
      print('❌ [ImplantStageController] Error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // إلغاء إكمال مرحلة
  Future<bool> uncompleteStage(String patientId, String stageName) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final uncompletedStage = await _implantStageService.uncompleteStage(
        patientId,
        stageName,
      );

      // تحديث المرحلة في القائمة
      final index = stages.indexWhere((s) => s.id == uncompletedStage.id);
      if (index != -1) {
        stages[index] = uncompletedStage;
      }

      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [ImplantStageController] ApiException: ${e.message}');
      return false;
    } catch (e) {
      errorMessage.value = 'فشل إلغاء إكمال المرحلة: ${e.toString()}';
      print('❌ [ImplantStageController] Error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
