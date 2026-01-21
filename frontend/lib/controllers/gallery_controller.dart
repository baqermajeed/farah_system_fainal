import 'dart:io';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:farah_sys_final/models/gallery_image_model.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';

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

      // 1) محاولة التحميل من الكاش أولاً (Hive)
      final box = Hive.box('gallery');
      final cacheKey = 'patient_$patientId';
      
      final cachedList = box.get(cacheKey);
      if (cachedList != null && cachedList is List) {
        try {
          final cachedImages = cachedList
              .map(
                (json) => GalleryImageModel.fromJson(
                  Map<String, dynamic>.from(json as Map),
                ),
              )
              .toList();
          galleryImages.value = cachedImages;
          print('✅ [GalleryController] Loaded ${galleryImages.length} images from cache');
        } catch (e) {
          print('❌ [GalleryController] Error parsing cached images: $e');
        }
      }

      final images = await _doctorService.getPatientGallery(patientId);
      galleryImages.value = images;

      // 2) تحديث الكاش بعد نجاح الجلب من API
      try {
        await box.put(cacheKey, galleryImages.map((img) => img.toJson()).toList());
        await box.put('${cacheKey}_lastUpdated', DateTime.now().toIso8601String());
        print('💾 [GalleryController] Cache updated with ${galleryImages.length} images');
      } catch (e) {
        print('❌ [GalleryController] Error updating cache: $e');
      }
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [GalleryController] Error loading gallery: $e');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Error loading gallery: $e');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
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
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [GalleryController] Error uploading image: $e');

      // Rollback: إزالة الصورة المؤقتة
      if (tempImage != null) {
        galleryImages.removeWhere((img) => img.id == tempImage!.id);
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Error uploading image: $e');

      // Rollback: إزالة الصورة المؤقتة
      if (tempImage != null) {
        galleryImages.removeWhere((img) => img.id == tempImage!.id);
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
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
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [GalleryController] Error deleting image: $e');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Error deleting image: $e');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
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

