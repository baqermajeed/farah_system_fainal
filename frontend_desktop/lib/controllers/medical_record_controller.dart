import 'dart:io';
import 'package:get/get.dart';
import 'package:frontend_desktop/models/medical_record_model.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';

class MedicalRecordController extends GetxController {
  final _doctorService = DoctorService();
  final _cacheService = CacheService();
  
  final RxList<MedicalRecordModel> records = <MedicalRecordModel>[].obs;
  final RxBool isLoading = false.obs;

  // جلب سجلات مريض محدد (نفس مبدأ frontend: كاش Hive ثم API)
  Future<void> loadPatientRecords(String patientId) async {
    try {
      isLoading.value = true;

      // 1) محاولة التحميل من الكاش أولاً (Hive) - بنفس طريقة eversheen
      final cachedRecords = _cacheService.getMedicalRecords(patientId);
      if (cachedRecords.isNotEmpty) {
        records.value = cachedRecords;
        print(
          '✅ [MedicalRecordController] Loaded ${records.length} records from cache',
        );
      }

      final recordsList = await _doctorService.getPatientNotes(
        patientId: patientId,
      );
      records.value = recordsList;

      // 2) تحديث الكاش بعد نجاح الجلب من API - بنفس طريقة eversheen
      try {
        await _cacheService.saveMedicalRecords(patientId, records.toList());
        print(
          '💾 [MedicalRecordController] Cache updated with ${records.length} records',
        );
      } catch (e) {
        print('❌ [MedicalRecordController] Error updating cache: $e');
      }
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل السجلات');
      }
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

      // حفظ في Cache - بنفس طريقة eversheen
      try {
        await _cacheService.saveMedicalRecord(newRecord);
      } catch (e) {
        print('❌ [MedicalRecordController] Error updating cache: $e');
      }

      Get.snackbar('نجح', 'تم إضافة السجل بنجاح');
    } on ApiException catch (e) {
      // Rollback
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
      
      // حفظ في Cache - بنفس طريقة eversheen
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
      
      // حذف من Cache - بنفس طريقة eversheen
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

