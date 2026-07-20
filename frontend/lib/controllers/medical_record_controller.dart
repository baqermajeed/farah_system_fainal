import 'dart:io';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:farah_sys_final/models/medical_record_model.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';

class MedicalRecordController extends GetxController {
  final _doctorService = DoctorService();
  
  final RxList<MedicalRecordModel> records = <MedicalRecordModel>[].obs;
  final RxBool isLoading = false.obs;

  // جلب سجلات مريض محدد
  Future<void> loadPatientRecords(String patientId) async {
    try {
      isLoading.value = true;

      // 1) محاولة التحميل من الكاش أولاً (Hive)
      final box = Hive.box('medicalRecords');
      final cacheKey = 'patient_$patientId';
      
      final cachedList = box.get(cacheKey);
      if (cachedList != null && cachedList is List) {
        try {
          final cachedRecords = cachedList
              .map(
                (json) => MedicalRecordModel.fromJson(
                  Map<String, dynamic>.from(json as Map),
                ),
              )
              .toList();
          records.value = cachedRecords;
          print('✅ [MedicalRecordController] Loaded ${records.length} records from cache');
        } catch (e) {
          print('❌ [MedicalRecordController] Error parsing cached records: $e');
        }
      }

      final recordsList = await _doctorService.getPatientNotes(
        patientId: patientId,
      );
      records.value = recordsList;

      // 2) تحديث الكاش بعد نجاح الجلب من API
      try {
        await box.put(cacheKey, records.map((r) => r.toJson()).toList());
        await box.put('${cacheKey}_lastUpdated', DateTime.now().toIso8601String());
        print('💾 [MedicalRecordController] Cache updated with ${records.length} records');
      } catch (e) {
        print('❌ [MedicalRecordController] Error updating cache: $e');
      }
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
    } catch (e) {
      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء تحميل السجلات');
    } finally {
      isLoading.value = false;
    }
  }

  // إضافة سجل جديد
  Future<void> addRecord({
    required String patientId,
    String? note,
    List<File>? imageFiles,
  }) async {
    MedicalRecordModel? tempRecord;

    try {
      // 1) إنشاء سجل مؤقت (تحديث متفائل)
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

      // 2) استدعاء السيرفر
      final newRecord = await _doctorService.addNote(
        patientId: patientId,
        note: note,
        imageFiles: imageFiles,
      );

      // 3) استبدال السجل المؤقت بالسجل الحقيقي
      final index = records.indexWhere((r) => r.id == tempRecord!.id);
      if (index != -1) {
        records[index] = newRecord;
      } else {
        records.insert(0, newRecord);
      }

      Get.snackbar('نجح', 'تم إضافة السجل بنجاح');
    } on ApiException catch (e) {
      // Rollback
      if (tempRecord != null) {
        records.removeWhere((r) => r.id == tempRecord!.id);
      }

      await NetworkUtils.showError(e);
      rethrow;
    } catch (e) {
      if (tempRecord != null) {
        records.removeWhere((r) => r.id == tempRecord!.id);
      }

      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء إضافة السجل');
      rethrow;
    } finally {
      // لا نستخدم isLoading هنا حتى لا نظهر تحميل عام على كامل الشاشة
    }
  }

  // تحديث سجل موجود
  Future<void> updateRecord({
    required String patientId,
    required String recordId,
    String? note,
    List<File>? imageFiles,
  }) async {
    try {
      isLoading.value = true;
      final updatedRecord = await _doctorService.updateNote(
        patientId: patientId,
        noteId: recordId,
        note: note,
        imageFiles: imageFiles,
      );
      // تحديث السجل في القائمة
      final index = records.indexWhere((r) => r.id == recordId);
      if (index != -1) {
        records[index] = updatedRecord;
      }
      Get.snackbar('نجح', 'تم تحديث السجل بنجاح');
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
      rethrow;
    } catch (e) {
      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء تحديث السجل');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // حذف سجل
  Future<void> deleteRecord({
    required String patientId,
    required String recordId,
  }) async {
    try {
      isLoading.value = true;
      await _doctorService.deleteNote(
        patientId: patientId,
        noteId: recordId,
      );
      // حذف السجل من القائمة
      records.removeWhere((r) => r.id == recordId);
      Get.snackbar('نجح', 'تم حذف السجل بنجاح');
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
      rethrow;
    } catch (e) {
      await NetworkUtils.showError(e, fallbackMessage: 'حدث خطأ أثناء حذف السجل');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // الحصول على سجل بواسطة ID
  MedicalRecordModel? getRecordById(String recordId) {
    try {
      return records.firstWhere((r) => r.id == recordId);
    } catch (e) {
      return null;
    }
  }
}

