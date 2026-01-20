import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/models/gallery_image_model.dart';
import 'package:frontend_desktop/services/doctor_service.dart';

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
    GalleryImageModel? tempImage;

    try {
      errorMessage.value = '';

      // 1) صورة مؤقتة (مسار فارغ، تواريخ تقريبية)
      tempImage = GalleryImageModel(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        patientId: patientId,
        imagePath: '',
        note: note,
        createdAt: DateTime.now().toIso8601String(),
      );

      galleryImages.insert(0, tempImage);

      // 2) رفع فعلي للسيرفر
      final newImage = await _doctorService.uploadGalleryImage(
        patientId,
        imageFile,
        note,
      );

      // 3) استبدال الصورة المؤقتة بالحقيقية
      final index = galleryImages.indexWhere((img) => img.id == tempImage!.id);
      if (index != -1) {
        galleryImages[index] = newImage;
      } else {
        galleryImages.insert(0, newImage);
      }

      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Error uploading image: $e');

      // Rollback: إزالة الصورة المؤقتة
      if (tempImage != null) {
        galleryImages.removeWhere((img) => img.id == tempImage!.id);
      }

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
    } finally {
      // لا نستخدم isLoading هنا حتى لا نظهر تحميل عام على كامل الشاشة
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

