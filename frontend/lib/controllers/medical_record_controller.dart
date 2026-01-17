import 'dart:io';
import 'package:get/get.dart';
import 'package:farah_sys_final/models/medical_record_model.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';

class MedicalRecordController extends GetxController {
  final _doctorService = DoctorService();
  
  final RxList<MedicalRecordModel> records = <MedicalRecordModel>[].obs;
  final RxBool isLoading = false.obs;

  // جلب سجلات مريض محدد
  Future<void> loadPatientRecords(String patientId) async {
    try {
      isLoading.value = true;
      final recordsList = await _doctorService.getPatientNotes(
        patientId: patientId,
      );
      records.value = recordsList;
    } on ApiException catch (e) {
      Get.snackbar('خطأ', e.message);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل السجلات');
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
    try {
      isLoading.value = true;
      final newRecord = await _doctorService.addNote(
        patientId: patientId,
        note: note,
        imageFiles: imageFiles,
      );
      // إضافة السجل الجديد في البداية (الأحدث أولاً)
      records.insert(0, newRecord);
      Get.snackbar('نجح', 'تم إضافة السجل بنجاح');
    } on ApiException catch (e) {
      Get.snackbar('خطأ', e.message);
      rethrow;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء إضافة السجل');
      rethrow;
    } finally {
      isLoading.value = false;
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
      Get.snackbar('خطأ', e.message);
      rethrow;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث السجل');
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
      Get.snackbar('خطأ', e.message);
      rethrow;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء حذف السجل');
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

