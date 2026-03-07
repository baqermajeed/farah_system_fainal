import 'dart:async';
import 'package:get/get.dart';
import 'package:frontend_desktop/models/patient_model.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/doctor_service.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';

class PatientController extends GetxController {
  final _patientService = PatientService();
  final _doctorService = DoctorService();
  final _cacheService = CacheService();

  final RxList<PatientModel> patients = <PatientModel>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<PatientModel?> selectedPatient = Rx<PatientModel?>(null);
  // for patient usage, currently we focus on doctor usage
  final Rx<PatientModel?> myProfile = Rx<PatientModel?>(null);

  // ⭐ متغيرات Pagination - بنفس طريقة eversheen
  var currentPage = 1;
  var totalPages = 1;
  var isLoadingMorePatients = false.obs;
  var hasMorePatients = true.obs;
  final int pageLimit = 25; // 25 مريض في كل مرة (بدلاً من 10 في eversheen)

  // ⭐ متغيرات البحث - بنفس طريقة eversheen
  RxList<PatientModel> searchResults = <PatientModel>[].obs;
  RxBool isSearching = false.obs;
  var searchPage = 1;
  var hasMoreSearchResults = true.obs;
  var isLoadingMoreSearch = false.obs;
  var lastSearchQuery = ''.obs;

  // ⭐ متغيرات للجلب الذكي (للتوافق مع الكود القديم)
  final RxInt loadedPatientsCount = 0.obs;
  final RxString loadingProgress = ''.obs;
  final RxBool isFetchingInBackground = false.obs;

  Future<List<PatientModel>> _fetchAllPages({
    required Future<List<PatientModel>> Function(int skip, int limit) fetchPage,
    int pageSize = 100,
    int maxItems = 200000,
  }) async {
    final all = <PatientModel>[];
    var skip = 0;

    while (true) {
      final page = await fetchPage(skip, pageSize);
      if (page.isEmpty) break;

      all.addAll(page);

      // Stop when we reached the last page.
      if (page.length < pageSize) break;

      // Safety guard to avoid unbounded memory usage if the API misbehaves.
      if (all.length >= maxItems) {
        print(
          '⚠️ [PatientController] Reached maxItems=$maxItems while fetching patients. Stopping pagination to avoid memory issues.',
        );
        break;
      }

      skip += pageSize;
    }

    // Deduplicate by id (defensive) while preserving order.
    final seen = <String>{};
    final deduped = <PatientModel>[];
    for (final p in all) {
      if (seen.add(p.id)) {
        deduped.add(p);
      }
    }
    return deduped;
  }

  // ⭐ دالة مساعدة: دمج المرضى (جديد + محدث)
  Map<String, dynamic> _mergePatients(
    List<PatientModel> cached,
    List<PatientModel> recent,
  ) {
    final cachedMap = <String, PatientModel>{};
    for (final p in cached) {
      cachedMap[p.id] = p;
    }

    int newCount = 0;
    int updatedCount = 0;

    // إضافة/تحديث المرضى من recent
    for (final recentPatient in recent) {
      final cachedPatient = cachedMap[recentPatient.id];

      if (cachedPatient == null) {
        // ⭐ مريض جديد
        cachedMap[recentPatient.id] = recentPatient;
        newCount++;
        print('🆕 [PatientController] New patient: ${recentPatient.name}');
      } else {
        // ⭐ التحقق إذا كان محدث
        final isUpdated = _isPatientUpdated(cachedPatient, recentPatient);
        if (isUpdated) {
          cachedMap[recentPatient.id] = recentPatient;
          updatedCount++;
          print(
            '🔄 [PatientController] Updated patient: ${recentPatient.name}',
          );
        }
      }
    }

    // ترتيب حسب ID (الأحدث أولاً)
    final merged = cachedMap.values.toList();
    merged.sort((a, b) => b.id.compareTo(a.id));

    return {
      'merged': merged,
      'newCount': newCount,
      'updatedCount': updatedCount,
    };
  }

  // ⭐ دالة مساعدة: التحقق إذا كان المريض محدث
  bool _isPatientUpdated(PatientModel cached, PatientModel recent) {
    // مقارنة الحقول المهمة
    return cached.name != recent.name ||
        cached.phoneNumber != recent.phoneNumber ||
        cached.age != recent.age ||
        cached.city != recent.city ||
        cached.visitType != recent.visitType ||
        cached.activityStatus != recent.activityStatus ||
        cached.treatmentHistory?.length != recent.treatmentHistory?.length ||
        cached.doctorIds.length != recent.doctorIds.length ||
        cached.imageUrl != recent.imageUrl ||
        !_areStringListsEqual(cached.paymentMethods, recent.paymentMethods);
  }

  bool _areStringListsEqual(List<String>? a, List<String>? b) {
    final aEmpty = a == null || a.isEmpty;
    final bEmpty = b == null || b.isEmpty;
    if (aEmpty && bEmpty) return true;
    if (aEmpty != bEmpty) return false;
    if (a!.length != b!.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ⭐ دالة مساعدة: جلب باقي الوجبات في الخلفية
  Future<void> _loadRemainingBatches({
    required String? userType,
    required int currentCount,
    required int batchSize,
    required int maxBatches,
    required DateTime startTime,
  }) async {
    var skip = currentCount;
    int batchNumber = 1;

    while (batchNumber <= maxBatches && hasMorePatients.value) {
      try {
        final batchStartTime = DateTime.now();
        print(
          '📦 [PatientController] Loading batch ${batchNumber + 1} (skip: $skip, limit: $batchSize)...',
        );

        List<PatientModel> batch;
        if (userType == 'receptionist') {
          batch = await _patientService.getAllPatients(
            skip: skip,
            limit: batchSize,
          );
        } else {
          batch = await _doctorService.getMyPatients(
            skip: skip,
            limit: batchSize,
          );
        }

        if (batch.isEmpty) {
          print('✅ [PatientController] No more patients to load');
          hasMorePatients.value = false;
          break;
        }

        final batchDuration = DateTime.now().difference(batchStartTime);

        // إضافة الوجبة الجديدة للقائمة
        patients.addAll(batch);
        loadedPatientsCount.value = patients.length;

        loadingProgress.value = 'جاري التحميل: ${patients.length} مريض...';

        print(
          '✅ [PatientController] Batch ${batchNumber + 1}: ${batch.length} patients in ${batchDuration.inMilliseconds}ms',
        );
        print('📊 [PatientController] Total: ${patients.length} patients');

        // تحديث الكاش كل 5 وجبات
        if (batchNumber % 5 == 0) {
          try {
            await _cacheService.savePatients(patients.toList());
            print(
              '💾 [PatientController] Cache updated (batch ${batchNumber + 1})',
            );
          } catch (e) {
            print('❌ [PatientController] Error updating cache: $e');
          }
        }

        if (batch.length < batchSize) {
          hasMorePatients.value = false;
          print('✅ [PatientController] Reached end of data');
          break;
        }

        skip += batchSize;
        batchNumber++;

        // استراحة صغيرة بين الوجبات
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        print(
          '❌ [PatientController] Error loading batch ${batchNumber + 1}: $e',
        );
        skip += batchSize;
        batchNumber++;

        if (batchNumber > 3) {
          print(
            '⚠️ [PatientController] Too many errors, stopping batch loading',
          );
          hasMorePatients.value = false;
          break;
        }
      }
    }

    // تحديث الكاش النهائي
    try {
      await _cacheService.savePatients(patients.toList());
    } catch (e) {
      print('❌ [PatientController] Error updating final cache: $e');
    }

    isFetchingInBackground.value = false;
    loadingProgress.value = 'تم تحميل ${patients.length} مريض';

    final totalTime = DateTime.now().difference(startTime);
    print('🎯 [PatientController] Batch loading complete!');
    print('👥 Total patients: ${patients.length}');
    print('⏱️ Total time: ${totalTime.inSeconds}s');
  }

  // جلب قائمة المرضى (للطبيب) - بنفس طريقة eversheen مع Pagination
  Future<void> loadPatients({
    bool isInitial = false,
    bool isRefresh = false,
  }) async {
    try {
      if (isRefresh || isInitial) {
        currentPage = 1;
        hasMorePatients.value = true;
        isLoading.value = true;
        patients.clear();
      } else {
        if (!hasMorePatients.value || isLoadingMorePatients.value) return;
        isLoadingMorePatients.value = true;
      }

      print(
        '📋 [PatientController] Loading patients - page: $currentPage, limit: $pageLimit',
      );

      // 1) محاولة التحميل من الكاش أولاً (Hive) - بنفس طريقة eversheen
      if (isInitial || isRefresh) {
        try {
          // ✅ حل نهائي: تحميل فقط أول 25 مريض من Cache لتجنب تحميل آلاف السجلات
          final cachedPatients = _cacheService.getFirstPatients(pageLimit);
          if (cachedPatients.isNotEmpty) {
            patients.assignAll(cachedPatients);
            print(
              '✅ [PatientController] Loaded ${patients.length} patients from cache',
            );
          }
        } catch (e) {
          print('❌ [PatientController] Error loading from cache: $e');
          // مسح Cache التالف
          try {
            await _cacheService.clearPatients();
          } catch (_) {}
        }
      }

      // 2) جلب من API
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      List<PatientModel> patientsList;
      if (userType == 'receptionist') {
        patientsList = await _patientService.getAllPatients(
          skip: (currentPage - 1) * pageLimit,
          limit: pageLimit,
        );
      } else {
        patientsList = await _doctorService.getMyPatients(
          skip: (currentPage - 1) * pageLimit,
          limit: pageLimit,
        );
      }

      if (isRefresh || isInitial) {
        patients.assignAll(patientsList);
      } else {
        patients.addAll(patientsList);
      }

      // تحديث حالة Pagination
      // افتراض أن هناك المزيد إذا كان عدد النتائج = pageLimit
      hasMorePatients.value = patientsList.length >= pageLimit;

      if (hasMorePatients.value) {
        currentPage++;
      }

      print(
        '✅ [PatientController] Loaded ${patientsList.length} patients from API (total: ${patients.length})',
      );

      // 3) تحديث الكاش بعد نجاح الجلب من API - بنفس طريقة eversheen
      // تشغيل في الخلفية بدون انتظار لتجنب blocking UI thread
      unawaited(
        _cacheService
            .savePatients(patients.toList())
            .then((_) {
              print(
                '💾 [PatientController] Cache updated with ${patients.length} patients',
              );
            })
            .catchError((e, stackTrace) {
              print('❌ [PatientController] Error updating cache: $e');
              print('❌ [PatientController] Stack trace: $stackTrace');
            }),
      );
    } on ApiException catch (e) {
      print('❌ [PatientController] ApiException: ${e.message}');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e) {
      print('❌ [PatientController] Error: $e');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المرضى');
      }
    } finally {
      isLoading.value = false;
      isLoadingMorePatients.value = false;
    }
  }

  // جلب المزيد من المرضى - بنفس طريقة eversheen
  Future<void> loadMorePatients() async {
    if (!hasMorePatients.value || isLoadingMorePatients.value) return;
    await loadPatients(isInitial: false, isRefresh: false);
  }

  // ⭐ الدالة الرئيسية: جلب ذكي مع الكاش
  Future<void> loadPatientsSmart({
    int initialBatchSize = 100, // حجم أول وجبة
    int batchSize = 100, // حجم باقي الوجبات
    int maxBatches = 200, // أقصى عدد وجبات
    int recentPatientsCheck = 200, // عدد المرضى الأحدث للتحقق
  }) async {
    try {
      isLoading.value = true;
      isFetchingInBackground.value = false;
      loadedPatientsCount.value = 0;
      loadingProgress.value = '';
      hasMorePatients.value = true;

      print('📋 [PatientController] Starting smart loading...');
      final startTime = DateTime.now();

      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      // ⭐ الخطوة 1: محاولة قراءة الكاش - بنفس طريقة eversheen
      final cachedPatients = _cacheService.getAllPatients();
      final cachedLastUpdated = _cacheService.getLastUpdateTime('patients');
      final hasCache = cachedPatients.isNotEmpty;

      if (hasCache) {
        print(
          '✅ [PatientController] Found ${cachedPatients.length} patients in cache',
        );
        print('📅 [PatientController] Cache last updated: $cachedLastUpdated');
      }

      // ⭐ الخطوة 2: إذا الكاش موجود - عرضه فوراً والتحقق من التحديثات
      if (hasCache && cachedPatients.isNotEmpty) {
        print('📦 [PatientController] Cache found - displaying immediately');

        // عرض الكاش فوراً
        patients.value = cachedPatients;
        loadedPatientsCount.value = cachedPatients.length;
        loadingProgress.value =
            'تم تحميل ${cachedPatients.length} مريض من الكاش';
        isLoading.value = false; // ⭐ مهم: إيقاف loading للعرض الفوري

        print(
          '✅ [PatientController] Displaying ${cachedPatients.length} patients from cache',
        );

        // ⭐ التحقق من التحديثات في الخلفية (غير blocking)
        _checkForUpdates(
          userType: userType,
          cachedPatients: cachedPatients,
          recentPatientsCheck: recentPatientsCheck,
        );

        return; // ⭐ خروج مبكر - عرض الكاش فوراً
      }

      // ⭐ الخطوة 3: إذا الكاش فارغ - جلب على شكل وجبات
      print('📦 [PatientController] Cache is empty - loading in batches...');

      // جلب أول وجبة
      List<PatientModel> firstBatch;
      if (userType == 'receptionist') {
        firstBatch = await _patientService.getAllPatients(
          skip: 0,
          limit: initialBatchSize,
        );
      } else {
        firstBatch = await _doctorService.getMyPatients(
          skip: 0,
          limit: initialBatchSize,
        );
      }

      if (firstBatch.isEmpty) {
        print('⚠️ [PatientController] No patients found');
        patients.value = [];
        isLoading.value = false;
        return;
      }

      patients.value = firstBatch;
      loadedPatientsCount.value = firstBatch.length;
      loadingProgress.value = 'تم تحميل ${firstBatch.length} مريض';

      print(
        '✅ [PatientController] First batch loaded: ${firstBatch.length} patients',
      );

      // تحديث الكاش بأول وجبة - بنفس طريقة eversheen
      try {
        await _cacheService.savePatients(patients.toList());
        print('💾 [PatientController] Cache updated with first batch');
      } catch (e) {
        print('❌ [PatientController] Error updating cache: $e');
      }

      // جلب باقي الوجبات في الخلفية
      if (firstBatch.length == initialBatchSize) {
        isFetchingInBackground.value = true;
        loadingProgress.value = 'جاري تحميل باقي البيانات...';

        _loadRemainingBatches(
          userType: userType,
          currentCount: firstBatch.length,
          batchSize: batchSize,
          maxBatches: maxBatches,
          startTime: startTime,
        );
      }

      isLoading.value = false;
    } catch (e) {
      print('❌ [PatientController] Error in smart loading: $e');
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المرضى');
      }
      isLoading.value = false;
    }
  }

  // ⭐ دالة مساعدة: التحقق من التحديثات في الخلفية
  Future<void> _checkForUpdates({
    required String? userType,
    required List<PatientModel> cachedPatients,
    required int recentPatientsCheck,
  }) async {
    try {
      print('🔄 [PatientController] Checking for updates...');

      // جلب المرضى الأحدث من API
      List<PatientModel> recentPatients;
      if (userType == 'receptionist') {
        recentPatients = await _patientService.getAllPatients(
          skip: 0,
          limit: recentPatientsCheck,
        );
      } else {
        recentPatients = await _doctorService.getMyPatients(
          skip: 0,
          limit: recentPatientsCheck,
        );
      }

      // دمج التحديثات
      final updated = _mergePatients(cachedPatients, recentPatients);

      if (updated['newCount'] > 0 || updated['updatedCount'] > 0) {
        print(
          '🔄 [PatientController] Found ${updated['newCount']} new and ${updated['updatedCount']} updated patients',
        );

        // تحديث القائمة
        patients.value = updated['merged'] as List<PatientModel>;
        loadedPatientsCount.value = patients.length;
        loadingProgress.value =
            'تم تحديث ${updated['newCount'] + updated['updatedCount']} مريض';

        // تحديث الكاش - بنفس طريقة eversheen
        try {
          await _cacheService.savePatients(patients.toList());
          print('💾 [PatientController] Cache updated with changes');
        } catch (e) {
          print('❌ [PatientController] Error updating cache: $e');
        }

        // إشعار المستخدم (اختياري)
        if (updated['newCount'] > 0 || updated['updatedCount'] > 0) {
          Get.snackbar(
            'تحديث',
            'تم تحديث ${updated['newCount'] + updated['updatedCount']} مريض',
            snackPosition: SnackPosition.TOP,
            duration: Duration(seconds: 2),
          );
        }
      } else {
        print('✅ [PatientController] No updates found - cache is up to date');
        loadingProgress.value = 'البيانات محدثة';
      }
    } catch (e) {
      print('❌ [PatientController] Error checking for updates: $e');
      // لا نعرض خطأ للمستخدم لأن الكاش موجود ويعمل
    }
  }

  void selectPatient(PatientModel? patient) {
    selectedPatient.value = patient;
  }

  Future<void> setTreatmentType({
    required String patientId,
    required String treatmentType,
  }) async {
    PatientModel? oldPatient;

    try {
      isLoading.value = true;

      // 1) حفظ نسخة قديمة (لأجل التراجع) + تحديث متفائل في الواجهة والكاش
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        oldPatient = patients[index];

        // بناء نسخة محدثة بشكل متفائل
        final optimisticPatient = PatientModel(
          id: oldPatient.id,
          name: oldPatient.name,
          phoneNumber: oldPatient.phoneNumber,
          gender: oldPatient.gender,
          age: oldPatient.age,
          city: oldPatient.city,
          visitType: oldPatient.visitType,
          imageUrl: oldPatient.imageUrl,
          doctorIds: oldPatient.doctorIds,
          treatmentHistory: <String>[
            ...?oldPatient.treatmentHistory,
            treatmentType,
          ],
          qrCodeData: oldPatient.qrCodeData,
          qrImagePath: oldPatient.qrImagePath,
          paymentMethods: oldPatient.paymentMethods,
          activityStatus: oldPatient.activityStatus,
        );

        patients[index] = optimisticPatient;
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = optimisticPatient;
        }

        // تحديث الكاش بشكل متفائل - بنفس طريقة eversheen
        try {
          await _cacheService.savePatient(optimisticPatient);
        } catch (_) {}
      }

      // 2) إرسال الطلب إلى السيرفر
      final updatedPatient = await _doctorService.setTreatmentType(
        patientId: patientId,
        treatmentType: treatmentType,
      );

      // تحديث القائمة
      final newIndex = patients.indexWhere((p) => p.id == patientId);
      if (newIndex != -1) {
        patients[newIndex] = updatedPatient;
      }

      // تحديث المريض المحدد إذا كان هو نفسه
      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }

      // تحديث الكاش بالبيانات المؤكدة من السيرفر - بنفس طريقة eversheen
      try {
        await _cacheService.savePatient(updatedPatient);
      } catch (_) {}

      Get.snackbar('نجح', 'تم تحديث نوع العلاج');
    } on ApiException catch (e) {
      // تراجع (Rollback) إلى الحالة القديمة
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          await _cacheService.savePatient(oldPatient);
        } catch (_) {}
      }

      // حوار تحذير للمستخدم أو سناك بار حسب نوع الخطأ
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e) {
      // تراجع (Rollback) إلى الحالة القديمة
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          await _cacheService.savePatient(oldPatient);
        } catch (_) {}
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث نوع العلاج');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setPaymentMethods({
    required String patientId,
    required List<String> methods,
  }) async {
    PatientModel? oldPatient;

    try {
      isLoading.value = true;

      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        oldPatient = patients[index];

        final optimisticPatient = PatientModel(
          id: oldPatient.id,
          name: oldPatient.name,
          phoneNumber: oldPatient.phoneNumber,
          gender: oldPatient.gender,
          age: oldPatient.age,
          city: oldPatient.city,
          visitType: oldPatient.visitType,
          imageUrl: oldPatient.imageUrl,
          doctorIds: oldPatient.doctorIds,
          treatmentHistory: oldPatient.treatmentHistory,
          qrCodeData: oldPatient.qrCodeData,
          qrImagePath: oldPatient.qrImagePath,
          paymentMethods: methods,
          activityStatus: oldPatient.activityStatus,
        );

        patients[index] = optimisticPatient;
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = optimisticPatient;
        }

        try {
          await _cacheService.savePatient(optimisticPatient);
        } catch (_) {}
      }

      final updatedPatient = await _doctorService.setPaymentMethods(
        patientId: patientId,
        methods: methods,
      );

      final newIndex = patients.indexWhere((p) => p.id == patientId);
      if (newIndex != -1) {
        patients[newIndex] = updatedPatient;
      }

      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }

      try {
        await _cacheService.savePatient(updatedPatient);
      } catch (_) {}

      Get.snackbar('نجح', 'تم تحديث طرق الدفع');
    } on ApiException catch (e) {
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          await _cacheService.savePatient(oldPatient);
        } catch (_) {}
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'خطا');
      }
    } catch (e) {
      if (oldPatient != null) {
        final index = patients.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          patients[index] = oldPatient;
        }
        if (selectedPatient.value?.id == patientId) {
          selectedPatient.value = oldPatient;
        }
        try {
          await _cacheService.savePatient(oldPatient);
        } catch (_) {}
      }

      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث طرق الدفع');
      }
    } finally {
      isLoading.value = false;
    }
  }

  // تحديث الأطباء المرتبطين بمريض معين في الواجهة بدون إعادة تحميل كاملة
  Future<void> updatePatientDoctorIds(
    String patientId,
    List<String> doctorIds,
  ) async {
    final index = patients.indexWhere((p) => p.id == patientId);
    if (index == -1) return;

    final patient = patients[index];
    final updatedPatient = PatientModel(
      id: patient.id,
      name: patient.name,
      phoneNumber: patient.phoneNumber,
      gender: patient.gender,
      age: patient.age,
      city: patient.city,
      visitType: patient.visitType,
      imageUrl: patient.imageUrl,
      doctorIds: doctorIds,
      treatmentHistory: patient.treatmentHistory,
      qrCodeData: patient.qrCodeData,
      qrImagePath: patient.qrImagePath,
      paymentMethods: patient.paymentMethods,
      activityStatus: patient.activityStatus,
    );

    patients[index] = updatedPatient;

    if (selectedPatient.value?.id == patientId) {
      selectedPatient.value = updatedPatient;
    }

    // تحديث الكاش - بنفس طريقة eversheen
    try {
      await _cacheService.savePatient(updatedPatient);
    } catch (_) {}
  }

  Future<void> activatePatientByReception(String patientId) async {
    try {
      isLoading.value = true;
      final updatedPatient = await _patientService.activatePatient(patientId);
      final index = patients.indexWhere((p) => p.id == patientId);
      if (index != -1) {
        patients[index] = updatedPatient;
      }
      if (selectedPatient.value?.id == patientId) {
        selectedPatient.value = updatedPatient;
      }
      try {
        await _cacheService.savePatient(updatedPatient);
      } catch (_) {}
      Get.snackbar('نجح', 'تم تنشيط المريض');
    } on ApiException catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', e.message);
      }
    } catch (e) {
      if (NetworkUtils.isNetworkError(e)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'فشل تنشيط المريض');
      }
    } finally {
      isLoading.value = false;
    }
  }

  PatientModel? getPatientById(String patientId) {
    try {
      return patients.firstWhere((p) => p.id == patientId);
    } catch (_) {}

    // Fallback to search results for cases where the patient was opened via search/QR.
    try {
      return searchResults.firstWhere((p) => p.id == patientId);
    } catch (_) {}

    // Final fallback: currently selected patient.
    final selected = selectedPatient.value;
    if (selected?.id == patientId) {
      return selected;
    }

    return null;
  }

  // إضافة مريض جديد إلى القائمة وتعيينه كمريض محدد بدون إعادة تحميل كاملة
  Future<void> addPatient(PatientModel patient) async {
    // ⭐ التحقق إذا كان المريض موجود بالفعل
    final existingIndex = patients.indexWhere((p) => p.id == patient.id);

    if (existingIndex != -1) {
      // ⭐ إذا كان موجود، نحدثه بدلاً من إضافته
      patients[existingIndex] = patient;
      print('✅ [PatientController] Patient updated: ${patient.name}');
    } else {
      // ⭐ إذا لم يكن موجود، نضيفه في بداية القائمة
      patients.insert(0, patient);
      loadedPatientsCount.value = patients.length; // ⭐ تحديث العداد
      print('✅ [PatientController] Patient added: ${patient.name}');
    }

    selectedPatient.value = patient;

    // تحديث الكاش بعد الإضافة/التحديث - بنفس طريقة eversheen
    try {
      await _cacheService.savePatient(patient);
    } catch (_) {}
  }

  // ⭐ دوال البحث - بنفس طريقة eversheen
  Future<void> searchPatients({required String searchQuery}) async {
    try {
      if (searchQuery.trim().isEmpty) {
        clearSearch();
        return;
      }

      // إذا كان نفس البحث، لا تعيد البحث
      if (searchQuery == lastSearchQuery.value && searchResults.isNotEmpty) {
        return;
      }

      // بحث جديد
      searchPage = 1;
      hasMoreSearchResults.value = true;
      lastSearchQuery.value = searchQuery;
      isSearching.value = true;
      searchResults.clear();

      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      List<PatientModel> results;
      if (userType == 'receptionist') {
        results = await _patientService.searchPatients(
          searchQuery: searchQuery.trim(),
          skip: (searchPage - 1) * pageLimit,
          limit: pageLimit,
        );
      } else {
        results = await _doctorService.searchMyPatients(
          searchQuery: searchQuery.trim(),
          skip: (searchPage - 1) * pageLimit,
          limit: pageLimit,
        );
      }

      searchResults.assignAll(results);

      // تحقق من وجود المزيد
      hasMoreSearchResults.value = results.length >= pageLimit;
      if (hasMoreSearchResults.value) {
        searchPage = 2; // الصفحة التالية
      }
    } catch (e) {
      print('❌ [PatientController] Error searching patients: $e');
    } finally {
      isSearching.value = false;
    }
  }

  // ⭐ دالة لتحميل المزيد من نتائج البحث
  Future<void> loadMoreSearchResults() async {
    if (isLoadingMoreSearch.value || !hasMoreSearchResults.value) {
      return;
    }

    isLoadingMoreSearch.value = true;

    try {
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;

      List<PatientModel> results;
      if (userType == 'receptionist') {
        results = await _patientService.searchPatients(
          searchQuery: lastSearchQuery.value,
          skip: (searchPage - 1) * pageLimit,
          limit: pageLimit,
        );
      } else {
        results = await _doctorService.searchMyPatients(
          searchQuery: lastSearchQuery.value,
          skip: (searchPage - 1) * pageLimit,
          limit: pageLimit,
        );
      }

      if (results.isNotEmpty) {
        searchResults.addAll(results);
        searchPage++;

        // تحقق من وجود المزيد
        hasMoreSearchResults.value = results.length >= pageLimit;
      } else {
        hasMoreSearchResults.value = false;
      }
    } catch (e) {
      print('❌ [PatientController] Error loading more search results: $e');
    } finally {
      isLoadingMoreSearch.value = false;
    }
  }

  // ⭐ مسح البحث والعودة للقائمة العادية
  void clearSearch() {
    lastSearchQuery.value = '';
    searchPage = 1;
    hasMoreSearchResults.value = true;
    isLoadingMoreSearch.value = false;
    isSearching.value = false;
    searchResults.clear();
  }
}
