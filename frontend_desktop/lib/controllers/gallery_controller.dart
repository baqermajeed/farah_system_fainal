import 'dart:io';
import 'package:get/get.dart';
import 'package:frontend_desktop/models/gallery_image_model.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';

class GalleryController extends GetxController {
  final _doctorService = DoctorService();
  final _patientService = PatientService();
  final _cacheService = CacheService();
  final AuthController _authController = Get.find<AuthController>();

  final galleryImages = <GalleryImageModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // جلب صور المعرض للمريض
  Future<void> loadGallery(String patientId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final userType = _authController.currentUser.value?.userType.toLowerCase();

      // 1) محاولة التحميل من الكاش أولاً (Hive) - بنفس طريقة eversheen
      final cachedImages = _cacheService.getGalleryImages(patientId);
      if (cachedImages.isNotEmpty) {
        galleryImages.value = cachedImages;
        print(
          '✅ [GalleryController] Loaded ${galleryImages.length} images from cache',
        );
      }

      // 2) جلب البيانات من الـ API حسب الدور
      List<GalleryImageModel> images;
      if (userType == 'doctor') {
        images = await _doctorService.getPatientGallery(patientId);
      } else if (userType == 'receptionist') {
        // موظف الاستقبال يرى فقط الصور التي قام برفعها بنفسه
        images = await _patientService.getReceptionPatientGallery(patientId);
      } else {
        // أدوار أخرى (إن وجدت) لا تعرض شيئاً في هذا التبويب حالياً
        images = <GalleryImageModel>[];
      }
      galleryImages.value = images;

      // 3) تحديث الكاش بعد نجاح الجلب من API - بنفس طريقة eversheen
      try {
        await _cacheService.saveGalleryImages(patientId, galleryImages.toList());
        print(
          '💾 [GalleryController] Cache updated with ${galleryImages.length} images',
        );
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

      // 2) رفع فعلي للسيرفر حسب الدور
      final userType = _authController.currentUser.value?.userType.toLowerCase();
      GalleryImageModel newImage;
      if (userType == 'doctor') {
        newImage = await _doctorService.uploadGalleryImage(
          patientId,
          imageFile,
          note,
        );
      } else if (userType == 'receptionist') {
        newImage = await _patientService.uploadReceptionGalleryImage(
          patientId: patientId,
          imageFile: imageFile,
          note: note,
        );
      } else {
        throw ApiException('هذا الدور غير مخوّل لرفع صور المعرض');
      }

      // 3) استبدال الصورة المؤقتة بالحقيقية
      final index = galleryImages.indexWhere((img) => img.id == tempImage!.id);
      if (index != -1) {
        galleryImages[index] = newImage;
      } else {
        galleryImages.insert(0, newImage);
      }

      // حفظ في Cache - بنفس طريقة eversheen
      try {
        await _cacheService.saveGalleryImage(newImage);
      } catch (e) {
        print('❌ [GalleryController] Error updating cache: $e');
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
        
        // حذف من Cache - بنفس طريقة eversheen
        try {
          await _cacheService.deleteGalleryImage(patientId, imageId);
        } catch (e) {
          print('❌ [GalleryController] Error deleting from cache: $e');
        }
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

