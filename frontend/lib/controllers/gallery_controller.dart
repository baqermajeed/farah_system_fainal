import 'dart:io';
import 'package:get/get.dart';
import 'package:farah_sys_final/models/gallery_image_model.dart';
import 'package:farah_sys_final/services/doctor_service.dart';

class GalleryController extends GetxController {
  final _doctorService = DoctorService();

  final galleryImages = <GalleryImageModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // جلب صور المعرض للمريض
  Future<void> loadGallery(String patientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final images = await _doctorService.getPatientGallery(patientId);
      galleryImages.value = images;
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Error loading gallery: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // رفع صورة جديدة
  Future<bool> uploadImage(
    String patientId,
    File imageFile,
    String? note,
  ) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final newImage = await _doctorService.uploadGalleryImage(
        patientId,
        imageFile,
        note,
      );
      
      // إضافة الصورة الجديدة في البداية (الأحدث أولاً)
      galleryImages.insert(0, newImage);
      
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Error uploading image: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // حذف صورة من المعرض
  Future<bool> deleteImage(String patientId, String imageId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final success = await _doctorService.deleteGalleryImage(patientId, imageId);
      
      if (success) {
        // إزالة الصورة من القائمة
        galleryImages.removeWhere((img) => img.id == imageId);
      }
      
      return success;
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Error deleting image: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // مسح القائمة
  void clearGallery() {
    galleryImages.clear();
    errorMessage.value = '';
  }
}

