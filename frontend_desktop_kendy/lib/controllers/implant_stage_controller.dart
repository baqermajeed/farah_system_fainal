import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/models/implant_stage_model.dart';
import 'package:frontend_desktop/services/implant_stage_service.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/controllers/appointment_controller.dart';

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
    if (_loadedOncePatientIds.contains(patientId) ||
        _inFlightPatientIds.contains(patientId)) {
      return;
    }

    _inFlightPatientIds.add(patientId);
    try {
      // لتجنّب "القفزة" في الواجهة: نحذف أي بيانات قديمة في الذاكرة
      // ونُظهر حالة تحميل إلى أن تَصل بيانات الباكند الفعلية.
      isLoading.value = true;
      stages.removeWhere((s) => s.patientId == patientId);

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
    ImplantStageModel? oldStage;

    try {
      errorMessage.value = '';

      // 1) تحديث متفائل محلياً
      final index = stages.indexWhere(
        (s) => s.patientId == patientId && s.stageName == stageName,
      );
      if (index != -1) {
        oldStage = stages[index];

        // دمج التاريخ والوقت محلياً (التاريخ يُمرر من الـ UI مع الوقت المختار)
        final timeParts = time.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
        final localDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        final optimisticStage = ImplantStageModel(
          id: oldStage.id,
          patientId: oldStage.patientId,
          stageName: oldStage.stageName,
          scheduledAt: localDateTime,
          isCompleted: oldStage.isCompleted,
          appointmentId: oldStage.appointmentId,
          createdAt: oldStage.createdAt,
          updatedAt: DateTime.now(),
        );

        stages[index] = optimisticStage;
      }

      // 2) استدعاء السيرفر
      final updatedStage = await _implantStageService.updateStageDate(
        patientId,
        stageName,
        date,
        time,
      );

      // 3) استبدال المرحلة بالنسخة القادمة من السيرفر
      final newIndex = stages.indexWhere((s) => s.id == updatedStage.id);
      if (newIndex != -1) {
        stages[newIndex] = updatedStage;
      }

      // 4) إعادة تحميل جميع مراحل هذا المريض من الباكند لضمان تحديث
      // مواعيد المراحل التالية التي يُعاد حسابها في السيرفر.
      await loadStages(patientId);

      return true;
    } on ApiException catch (e) {
      // Rollback
      if (oldStage != null) {
        final original = oldStage;
        final index = stages.indexWhere((s) => s.id == original.id);
        if (index != -1) {
          stages[index] = original;
        }
      }
      errorMessage.value = e.message;
      print('❌ [ImplantStageController] ApiException: ${e.message}');

      // في حالة مشاكل الشبكة نظهر دايلوج التحقق من الاتصال فقط
      if (e is NetworkException) {
        Get.dialog(
          AlertDialog(
            title: const Text('خطأ في الاتصال'),
            content:
                const Text('تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
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
      print('❌ [ImplantStageController] Error: $e');
      Get.dialog(
        AlertDialog(
          title: const Text('خطأ في الاتصال'),
          content: const Text('تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return false;
    }
  }

  // إكمال مرحلة
  Future<bool> completeStage(String patientId, String stageName) async {
    ImplantStageModel? oldStage;

    try {
      errorMessage.value = '';

      // 1) تحديث متفائل محلياً
      final index = stages.indexWhere(
        (s) => s.patientId == patientId && s.stageName == stageName,
      );
      if (index != -1) {
        oldStage = stages[index];
        final optimisticStage = ImplantStageModel(
          id: oldStage.id,
          patientId: oldStage.patientId,
          stageName: oldStage.stageName,
          scheduledAt: oldStage.scheduledAt,
          isCompleted: true,
          appointmentId: oldStage.appointmentId,
          createdAt: oldStage.createdAt,
          updatedAt: DateTime.now(),
        );
        stages[index] = optimisticStage;
      }

      // 2) استدعاء السيرفر
      final completedStage =
          await _implantStageService.completeStage(patientId, stageName);

      // 3) استبدال المرحلة بالنسخة القادمة من السيرفر أو إضافتها إذا لم تكن موجودة
      final newIndex = stages.indexWhere((s) => s.id == completedStage.id);
      if (newIndex != -1) {
        stages[newIndex] = completedStage;
      } else {
        stages.add(completedStage);
      }

      // 4) إعادة تحميل المراحل من الباكند حتى يتم تحديث موعد المرحلة التالية
      // التي يتم إنشاؤها / تعديلها تلقائياً في السيرفر بعد الإكمال.
      await loadStages(patientId);

      // 5) تحديث جدول المواعيد من الباكند أيضاً حتى يختفي الموعد المكتمل
      // من تبويب المواعيد (اليوم/المتأخرون/هذا الشهر) وكذلك من مواعيد المريض.
      try {
        final appointmentController = Get.find<AppointmentController>();
        await appointmentController.loadDoctorAppointments();
        await appointmentController.loadPatientAppointmentsById(patientId);
      } catch (_) {
        // إذا فشل التحديث هنا، سيظهر التغيير عند إعادة تحميل المواعيد يدوياً.
      }

      return true;
    } on ApiException catch (e) {
      // Rollback
      if (oldStage != null) {
        final original = oldStage;
        final index = stages.indexWhere((s) => s.id == original.id);
        if (index != -1) {
          stages[index] = original;
        }
      }
      errorMessage.value = e.message;
      print('❌ [ImplantStageController] ApiException: ${e.message}');

      // في حالة مشاكل الشبكة نظهر دايلوج التحقق من الاتصال فقط
      if (e is NetworkException) {
        Get.dialog(
          AlertDialog(
            title: const Text('خطأ في الاتصال'),
            content:
                const Text('تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
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
      print('❌ [ImplantStageController] Error: $e');
      Get.dialog(
        AlertDialog(
          title: const Text('خطأ في الاتصال'),
          content: const Text('تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return false;
    }
  }

  // إلغاء إكمال مرحلة
  Future<bool> uncompleteStage(String patientId, String stageName) async {
    ImplantStageModel? oldStage;

    try {
      errorMessage.value = '';

      // 1) تحديث متفائل محلياً
      final index = stages.indexWhere(
        (s) => s.patientId == patientId && s.stageName == stageName,
      );
      if (index != -1) {
        oldStage = stages[index];
        final optimisticStage = ImplantStageModel(
          id: oldStage.id,
          patientId: oldStage.patientId,
          stageName: oldStage.stageName,
          scheduledAt: oldStage.scheduledAt,
          isCompleted: false,
          appointmentId: oldStage.appointmentId,
          createdAt: oldStage.createdAt,
          updatedAt: DateTime.now(),
        );
        stages[index] = optimisticStage;
      }

      // 2) استدعاء السيرفر
      final uncompletedStage =
          await _implantStageService.uncompleteStage(patientId, stageName);

      // 3) استبدال المرحلة بالنسخة القادمة من السيرفر
      final newIndex = stages.indexWhere((s) => s.id == uncompletedStage.id);
      if (newIndex != -1) {
        stages[newIndex] = uncompletedStage;
      }

      // 4) إعادة تحميل المراحل لضمان تطابق الواجهة مع حالة الباكند
      await loadStages(patientId);

      // 5) إعادة تحميل المواعيد حتى يعود الموعد إلى جدول المواعيد
      try {
        final appointmentController = Get.find<AppointmentController>();
        await appointmentController.loadDoctorAppointments();
        await appointmentController.loadPatientAppointmentsById(patientId);
      } catch (_) {}

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
      print('❌ [ImplantStageController] ApiException: ${e.message}');

      // في حالة مشاكل الشبكة نظهر دايلوج التحقق من الاتصال فقط
      if (e is NetworkException) {
        Get.dialog(
          AlertDialog(
            title: const Text('خطأ في الاتصال'),
            content:
                const Text('تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
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
      print('❌ [ImplantStageController] Error: $e');
      Get.dialog(
        AlertDialog(
          title: const Text('خطأ في الاتصال'),
          content: const Text('تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return false;
    }
  }
}
