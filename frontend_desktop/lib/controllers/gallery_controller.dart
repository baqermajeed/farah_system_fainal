import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';
import 'package:frontend_desktop/models/gallery_image_model.dart';
import 'package:frontend_desktop/models/sync_outbox_entry.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/services/outbox_store.dart';
import 'package:frontend_desktop/services/sync_worker.dart';
import 'package:frontend_desktop/services/sync_events.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';

class GalleryController extends GetxController {
  final _doctorService = DoctorService();
  final _patientService = PatientService();
  final _cacheService = CacheService();
  final _outbox = OutboxStore();
  final AuthController _authController = Get.find<AuthController>();

  final galleryImages = <GalleryImageModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  String? _activePatientId;
  StreamSubscription<GallerySyncedEvent>? _syncedSub;
  StreamSubscription<GalleryRemovedEvent>? _removedSub;

  /// الطبيب: لوكال + Outbox. الاستقبال: سيرفر مباشرة.
  bool get _useLocalOutbox {
    final type = _authController.currentUser.value?.userType.toLowerCase();
    return type == 'doctor';
  }

  @override
  void onInit() {
    super.onInit();
    _syncedSub = SyncEvents.gallerySynced.listen(_onGallerySynced);
    _removedSub = SyncEvents.galleryRemoved.listen(_onGalleryRemoved);
  }

  @override
  void onClose() {
    _syncedSub?.cancel();
    _removedSub?.cancel();
    super.onClose();
  }

  void _onGallerySynced(GallerySyncedEvent event) {
    if (_activePatientId != null && event.patientId != _activePatientId) {
      return;
    }
    final index = galleryImages.indexWhere((i) => i.id == event.localImageId);
    if (index != -1) {
      galleryImages[index] = event.serverImage;
    } else if (!galleryImages.any((i) => i.id == event.serverImage.id)) {
      galleryImages.insert(0, event.serverImage);
    }
  }

  void _onGalleryRemoved(GalleryRemovedEvent event) {
    if (_activePatientId != null && event.patientId != _activePatientId) {
      return;
    }
    galleryImages.removeWhere((i) => i.id == event.imageId);
  }

  // جلب صور المعرض للمريض — بدون إخفاء المحتوى إن وُجدت صور محلية
  Future<void> loadGallery(String patientId) async {
    _activePatientId = patientId;
    try {
      errorMessage.value = '';

      final cachedImages = _cacheService.getGalleryImages(patientId);
      if (cachedImages.isNotEmpty) {
        galleryImages.value = _mergeWithLocalPending(patientId, cachedImages);
      }

      // لا نُظهر سبينر كامل الشاشة إلا إذا القائمة فارغة فعلاً
      final showBlockingLoader = galleryImages.isEmpty;
      if (showBlockingLoader) {
        isLoading.value = true;
      }

      final userType = _authController.currentUser.value?.userType.toLowerCase();

      List<GalleryImageModel> images;
      if (userType == 'doctor') {
        images = await _doctorService.getPatientGallery(patientId);
      } else if (userType == 'receptionist') {
        images = await _patientService.getReceptionPatientGallery(patientId);
      } else {
        images = <GalleryImageModel>[];
      }

      galleryImages.value = _mergeWithLocalPending(patientId, images);

      try {
        await _cacheService.saveGalleryImages(patientId, galleryImages.toList());
      } catch (e) {
        print('❌ [GalleryController] Error updating cache: $e');
      }
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [GalleryController] Error loading gallery: $e');
      if (galleryImages.isEmpty && NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Error loading gallery: $e');
      if (galleryImages.isEmpty && NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
    } finally {
      isLoading.value = false;
    }
  }

  List<GalleryImageModel> _mergeWithLocalPending(
    String patientId,
    List<GalleryImageModel> serverOrCache,
  ) {
    final merged = <GalleryImageModel>[];
    final knownIds = serverOrCache.map((i) => i.id).toSet();

    final localPending = _cacheService
        .getGalleryImages(patientId)
        .where((i) => i.id.startsWith('local_'))
        .toList();

    for (final local in localPending) {
      if (!knownIds.contains(local.id)) {
        merged.add(local);
      }
    }

    final pendingDeletes = _pendingDeleteIds(patientId);
    for (final image in serverOrCache) {
      if (!pendingDeletes.contains(image.id)) {
        merged.add(image);
      }
    }

    return merged;
  }

  Set<String> _pendingDeleteIds(String patientId) {
    if (!_outbox.isReady) return {};
    final ids = <String>{};
    for (final entry in _outbox.getAll()) {
      if (entry.type != SyncOutboxEntry.typeDeleteGalleryImage) continue;
      if (entry.payload['patientId']?.toString() != patientId) continue;
      final imageId = entry.payload['imageId']?.toString();
      if (imageId != null && imageId.isNotEmpty) ids.add(imageId);
    }
    return ids;
  }

  // رفع صورة جديدة
  Future<bool> uploadImage(
    String patientId,
    File imageFile,
    String? note,
  ) async {
    if (_useLocalOutbox) {
      return _uploadImageLocalFirst(patientId, imageFile, note);
    }
    return _uploadImageOnline(patientId, imageFile, note);
  }

  Future<bool> _uploadImageLocalFirst(
    String patientId,
    File imageFile,
    String? note,
  ) async {
    try {
      errorMessage.value = '';
      await _outbox.init();

      final localImageId = 'local_${_newId()}';
      final operationId = _newId();
      final entityKey = OutboxStore.galleryEntityKey(patientId, localImageId);

      final durablePaths = await _outbox.persistImageFiles(
        operationId: operationId,
        files: [imageFile],
      );
      if (durablePaths.isEmpty) {
        errorMessage.value = 'فشل حفظ الصورة محلياً';
        return false;
      }
      final durablePath = durablePaths.first;

      final localImage = GalleryImageModel(
        id: localImageId,
        patientId: patientId,
        imagePath: durablePath,
        note: note,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _cacheService.saveGalleryImage(localImage);
      await _outbox.enqueue(
        type: SyncOutboxEntry.typeAddGalleryImage,
        entityKey: entityKey,
        idempotencyKey: operationId,
        payload: {
          'operationId': operationId,
          'patientId': patientId,
          'localImageId': localImageId,
          'imagePath': durablePath,
          'note': note,
        },
      );

      galleryImages.insert(0, localImage);
      unawaited(SyncWorker.instance.kick());
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Local upload enqueue failed: $e');
      return false;
    }
  }

  Future<bool> _uploadImageOnline(
    String patientId,
    File imageFile,
    String? note,
  ) async {
    GalleryImageModel? tempImage;

    try {
      errorMessage.value = '';

      tempImage = GalleryImageModel(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        patientId: patientId,
        imagePath: imageFile.path,
        note: note,
        createdAt: DateTime.now().toIso8601String(),
      );

      galleryImages.insert(0, tempImage);

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

      final index = galleryImages.indexWhere((img) => img.id == tempImage!.id);
      if (index != -1) {
        galleryImages[index] = newImage;
      } else {
        galleryImages.insert(0, newImage);
      }

      try {
        await _cacheService.saveGalleryImage(newImage);
      } catch (e) {
        print('❌ [GalleryController] Error updating cache: $e');
      }

      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      print('❌ [GalleryController] Error uploading image: $e');

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

      if (tempImage != null) {
        galleryImages.removeWhere((img) => img.id == tempImage!.id);
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      }
      return false;
    }
  }

  // حذف صورة من المعرض
  Future<bool> deleteImage(String patientId, String imageId) async {
    if (_useLocalOutbox) {
      return _deleteImageLocalFirst(patientId, imageId);
    }
    return _deleteImageOnline(patientId, imageId);
  }

  Future<bool> _deleteImageLocalFirst(String patientId, String imageId) async {
    try {
      errorMessage.value = '';
      await _outbox.init();
      final entityKey = OutboxStore.galleryEntityKey(patientId, imageId);

      if (imageId.startsWith('local_')) {
        final pendingAdd = _outbox
            .findByEntityKey(entityKey)
            .where((e) => e.type == SyncOutboxEntry.typeAddGalleryImage)
            .toList();
        for (final entry in pendingAdd) {
          await _outbox.remove(entry.id);
        }
        for (final entry in _outbox.findByEntityKey(entityKey)) {
          await _outbox.remove(entry.id);
        }
        await _cacheService.deleteGalleryImage(patientId, imageId);
        galleryImages.removeWhere((img) => img.id == imageId);
        return true;
      }

      galleryImages.removeWhere((img) => img.id == imageId);
      await _cacheService.deleteGalleryImage(patientId, imageId);

      for (final entry in _outbox.findByEntityKey(entityKey)) {
        if (entry.type == SyncOutboxEntry.typeDeleteGalleryImage) {
          await _outbox.remove(entry.id);
        }
      }

      final operationId = _newId();
      await _outbox.enqueue(
        type: SyncOutboxEntry.typeDeleteGalleryImage,
        entityKey: entityKey,
        idempotencyKey: operationId,
        payload: {
          'operationId': operationId,
          'patientId': patientId,
          'imageId': imageId,
        },
      );

      unawaited(SyncWorker.instance.kick());
      return true;
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ [GalleryController] Local delete failed: $e');
      return false;
    }
  }

  Future<bool> _deleteImageOnline(String patientId, String imageId) async {
    try {
      // لا نستخدم isLoading حتى لا تختفي محتويات التبويب خلف الدايلوك
      errorMessage.value = '';

      final success = await _doctorService.deleteGalleryImage(
        patientId,
        imageId,
      );

      if (success) {
        galleryImages.removeWhere((img) => img.id == imageId);
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
    }
  }

  void clearGallery() {
    galleryImages.clear();
    errorMessage.value = '';
  }

  String _newId() {
    final rand = Random.secure();
    final a = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final b = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    final c = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${a}_$b$c';
  }
}
