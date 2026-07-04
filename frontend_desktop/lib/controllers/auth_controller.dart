import 'dart:async';

import 'package:get/get.dart';
import 'package:frontend_desktop/models/user_model.dart';
import 'package:frontend_desktop/services/auth_service.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/core/routes/app_routes.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';
import 'package:frontend_desktop/controllers/presence_controller.dart';
import 'package:frontend_desktop/services/sync_worker.dart';

class AuthController extends GetxController {
  final _authService = AuthService();
  final _cacheService = CacheService();
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxnString patientProfileId = RxnString(null);
  final RxBool isLoading = false.obs;
  final RxString otpCode = ''.obs;
  final RxBool isOnline = true.obs;
  final RxInt reconnectVersion = 0.obs;
  Timer? _connectivityTimer;
  bool _isSessionSyncInProgress = false;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadPersistedSession());
    _startConnectivityMonitor();
    ever<int>(reconnectVersion, (_) {
      final user = currentUser.value;
      if (user != null) {
        unawaited(_syncPresence(user));
        unawaited(_resumeDoctorSyncIfNeeded(user));
      }
    });
  }

  @override
  void onClose() {
    _connectivityTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadPersistedSession() async {
    try {
      print('🔍 [AuthController] Loading persisted session...');
      
      // محاولة قراءة من Cache أولاً - بنفس طريقة eversheen
      final cachedUser = _cacheService.getUser();
      if (cachedUser != null) {
        currentUser.value = cachedUser;
        print('✅ [AuthController] User loaded from cache: ${cachedUser.name}');
        await _syncPatientProfileId();
        // استئناف رفع الأوامر بالخلفية عند فتح التطبيق
        unawaited(_startDoctorSyncIfNeeded(cachedUser));
      }
      
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        print('✅ [AuthController] Token found, loading user info from API...');
        final res = await _authService.getCurrentUser();
        if (res['ok'] == true) {
          final userData = res['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);
          currentUser.value = user;
          
          // حفظ في Cache - بنفس طريقة eversheen
          await _cacheService.saveUser(user);
          
          await _syncPatientProfileId();
          print(
            '✅ [AuthController] User loaded from session: ${user.name} (${user.userType})',
          );
          unawaited(_syncPresence(user));
          unawaited(_startDoctorSyncIfNeeded(user));
        } else {
          if (_isNetworkFailureResponse(res)) {
            print(
              '🌐 [AuthController] Network issue while restoring session. Keeping cached session.',
            );
            final existing = currentUser.value;
            if (existing != null) {
              unawaited(_startDoctorSyncIfNeeded(existing));
            }
            return;
          }

          if (_isUnauthorizedResponse(res)) {
            print(
              '⚠️ [AuthController] Session is unauthorized. Clearing local session.',
            );
            await _clearSessionLocal();
            return;
          }

          print(
            '⚠️ [AuthController] Failed to load user info from API, keeping existing session',
          );
        }
      } else {
        if (currentUser.value != null) {
          await _clearSessionLocal();
        }
        print('ℹ️ [AuthController] No saved session found');
      }
    } catch (e) {
      print('❌ [AuthController] Error loading persisted session: $e');
      if (!NetworkUtils.isNetworkError(e)) {
        currentUser.value = null;
      }
    }
  }

  Future<void> _syncPatientProfileId() async {
    final userType = currentUser.value?.userType.toLowerCase();
    if (userType != 'patient') {
      patientProfileId.value = null;
      return;
    }

    try {
      final patientService = PatientService();
      final profile = await patientService.getMyProfile();
      patientProfileId.value = profile.id;
      print('📋 [AuthController] Synced patientProfileId: ${profile.id}');
    } catch (e) {
      print('⚠️ [AuthController] Could not sync patientProfileId: $e');
    }
  }

  Future<void> checkLoggedInUser({bool navigate = true}) async {
    try {
      print('🔍 [AuthController] Checking logged in user...');
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final res = await _authService.getCurrentUser();
        if (res['ok'] == true) {
          final userData = res['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);
          currentUser.value = user;
          
          // حفظ في Cache - بنفس طريقة eversheen
          await _cacheService.saveUser(user);
          
          await _syncPatientProfileId();
          print(
            '✅ [AuthController] User loaded: ${user.name} (${user.userType})',
          );
          unawaited(_syncPresence(user));
          unawaited(_startDoctorSyncIfNeeded(user));

          if (!navigate) return;

          if (user.userType == 'doctor') {
            Get.offAllNamed(AppRoutes.doctorHome);
          } else if (user.userType == 'receptionist') {
            Get.offAllNamed(AppRoutes.receptionHome);
          } else if (user.userType == 'call_center') {
            Get.offAllNamed(AppRoutes.callCenterHome);
          } else {
            Get.offAllNamed(AppRoutes.userSelection);
          }
        } else {
          if (_isNetworkFailureResponse(res)) {
            print(
              '🌐 [AuthController] Network failure while checking user. Keeping session active.',
            );
            if (navigate) {
              final existing = currentUser.value;
              if (existing != null) {
                _navigateByUserType(existing);
              } else {
                Get.offAllNamed(AppRoutes.userSelection);
              }
            }
            return;
          }

          if (_isUnauthorizedResponse(res)) {
            // التوكن منتهي أو غير صالح (401) — مسح الجلسة والانتقال لاختيار المستخدم
            print(
              '⚠️ [AuthController] Unauthorized session, clearing local session',
            );
            await _clearSessionLocal();
            if (navigate) {
              Get.offAllNamed(AppRoutes.userSelection);
            }
            return;
          }

          // أخطاء غير مصنفة (مثل 5xx): لا نطرد المستخدم
          print(
            '⚠️ [AuthController] Failed to load user info (non-auth error), keeping session',
          );
          if (navigate) {
            final existing = currentUser.value;
            if (existing != null) {
              _navigateByUserType(existing);
            } else {
              Get.offAllNamed(AppRoutes.userSelection);
            }
          }
        }
      } else {
        print('ℹ️ [AuthController] User is not logged in');
        if (navigate) {
          Get.offAllNamed(AppRoutes.userSelection);
        }
      }
    } catch (e) {
      print('❌ [AuthController] Error checking logged in user: $e');
      if (NetworkUtils.isNetworkError(e)) {
        if (navigate) {
          final existing = currentUser.value;
          if (existing != null) {
            _navigateByUserType(existing);
          } else {
            Get.offAllNamed(AppRoutes.userSelection);
          }
        }
        return;
      }

      currentUser.value = null;
      if (navigate) {
        Get.offAllNamed(AppRoutes.userSelection);
      }
    }
  }

  // تسجيل دخول الطاقم (username/password)
  /// [expectedUserType] إن وُجد: يرفض الدخول إذا كان نوع المستخدم المُرجَع من API غير مطابق (مثلاً: اختيار مركز الاتصالات وإدخال بيانات موظف استقبال).
  Future<void> loginDoctor({
    required String username,
    required String password,
    String? expectedUserType,
  }) async {
    print('🎯 [AuthController] loginDoctor called: $username (expected: $expectedUserType)');

    if (username.trim().isEmpty || password.trim().isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال اسم المستخدم وكلمة المرور');
      return;
    }

    try {
      isLoading.value = true;
      final res = await _authService.staffLogin(
        username: username.trim(),
        password: password,
      );

      if (res['ok'] == true) {
        print('✅ [AuthController] Login successful');
        final userRes = await _authService.getCurrentUser();
        if (userRes['ok'] == true) {
          final userData = userRes['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);
          final actualType = user.userType.toLowerCase();

          // التحقق من تطابق نوع المستخدم مع صفحة الدخول المختارة
          if (expectedUserType != null && expectedUserType.trim().isNotEmpty) {
            final expected = expectedUserType.trim().toLowerCase().replaceAll(' ', '_');
            final actualNorm = actualType.replaceAll(' ', '_');
            if (actualNorm != expected) {
              await _authService.logout();
              await _cacheService.deleteUser();
              currentUser.value = null;
              isLoading.value = false;
              Get.snackbar(
                'رفض الدخول',
                'هذا الحساب لا يطابق نوع المستخدم المختار. يرجى استخدام صفحة تسجيل الدخول المناسبة.',
                snackPosition: SnackPosition.TOP,
              );
              return;
            }
          }

          currentUser.value = user;

          // حفظ محلي سريع ثم الانتقال فوراً — لا ننتظر Socket/Outbox على شاشة الدخول
          await _cacheService.saveUser(user);

          String targetRoute;
          switch (actualType) {
            case 'doctor':
              targetRoute = AppRoutes.doctorHome;
              break;
            case 'receptionist':
              targetRoute = AppRoutes.receptionHome;
              break;
            case 'call_center':
              targetRoute = AppRoutes.callCenterHome;
              break;
            default:
              targetRoute = AppRoutes.userSelection;
          }

          print('🔀 [AuthController] Navigating to: $targetRoute');
          isLoading.value = false;
          Get.offAllNamed(targetRoute);

          // مهام خلفية بعد الدخول (لا تُبطئ زر تسجيل الدخول)
          unawaited(_syncPatientProfileId());
          unawaited(_syncPresence(user));
          unawaited(_startDoctorSyncIfNeeded(user));

          Future<void>.delayed(const Duration(milliseconds: 300), () {
            if (Get.context != null) {
              try {
                Get.snackbar('نجح', 'تم تسجيل الدخول بنجاح');
              } catch (e) {
                print('⚠️ [AuthController] Error showing snackbar: $e');
              }
            }
          });
        } else {
          final errorMsg = userRes['error']?.toString() ?? 'فشل جلب معلومات المستخدم';
          if (NetworkUtils.isNetworkError(errorMsg)) {
            NetworkUtils.showNetworkErrorDialog();
          } else {
            Get.snackbar('خطأ', errorMsg);
          }
        }
      } else {
        final errorMsg = res['error']?.toString() ?? 'فشل تسجيل الدخول';
        if (NetworkUtils.isNetworkError(errorMsg)) {
          NetworkUtils.showNetworkErrorDialog();
        } else {
          Get.snackbar('خطأ', errorMsg);
        }
      }
    } catch (e) {
      print('❌ [AuthController] General error: $e');
      final errorMsg = e.toString();
      if (NetworkUtils.isNetworkError(errorMsg)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'فشل تسجيل الدخول');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      // إيقاف الرفع فقط — الأوامر المعلّقة تبقى على القرص وتُرفع عند الدخول مجدداً
      SyncWorker.instance.stop();
      if (Get.isRegistered<PresenceController>()) {
        Get.find<PresenceController>().disconnect();
      }
      await _authService.logout();
      
      // حذف من Cache - بنفس طريقة eversheen
      await _cacheService.deleteUser();
      
      currentUser.value = null;
      patientProfileId.value = null;
      print('✅ [AuthController] Logged out successfully');
      Get.offAllNamed(AppRoutes.userSelection);
    } catch (e) {
      final errorMsg = e.toString();
      if (NetworkUtils.isNetworkError(errorMsg)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تسجيل الخروج');
      }
    }
  }

  bool _isUnauthorizedResponse(Map<String, dynamic> response) {
    final statusCode = response['statusCode'];
    return statusCode == 401;
  }

  bool _isNetworkFailureResponse(Map<String, dynamic> response) {
    final isNetworkError = response['isNetworkError'];
    if (isNetworkError == true) return true;
    final error = response['error'];
    if (error == null) return false;
    return NetworkUtils.isNetworkError(error);
  }

  void _navigateByUserType(UserModel user) {
    final userType = user.userType.toLowerCase();
    if (userType == 'doctor') {
      Get.offAllNamed(AppRoutes.doctorHome);
    } else if (userType == 'receptionist') {
      Get.offAllNamed(AppRoutes.receptionHome);
    } else if (userType == 'call_center') {
      Get.offAllNamed(AppRoutes.callCenterHome);
    } else {
      Get.offAllNamed(AppRoutes.userSelection);
    }
  }

  Future<void> _clearSessionLocal() async {
    // لا نمسح الـ Outbox أبداً — البيانات المهمة تبقى حتى تُرفع
    SyncWorker.instance.stop();
    if (Get.isRegistered<PresenceController>()) {
      Get.find<PresenceController>().disconnect();
    }
    await _authService.logout();
    await _cacheService.deleteUser();
    currentUser.value = null;
    patientProfileId.value = null;
  }

  void _startConnectivityMonitor() {
    // Probe quickly on startup, then keep polling in the background.
    unawaited(_probeConnectivityAndSync());
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_probeConnectivityAndSync()),
    );
  }

  Future<void> _probeConnectivityAndSync() async {
    final connected = await NetworkUtils.hasInternetConnection();
    final wasOnline = isOnline.value;
    isOnline.value = connected;

    if (connected && !wasOnline) {
      print('🌐 [AuthController] Internet restored. Syncing session...');
      reconnectVersion.value++;
      await _syncSessionAfterReconnect();
    } else if (!connected && wasOnline) {
      print('⚠️ [AuthController] Internet connection lost.');
    }
  }

  Future<void> _syncSessionAfterReconnect() async {
    if (_isSessionSyncInProgress) return;
    _isSessionSyncInProgress = true;
    try {
      await checkLoggedInUser(navigate: false);
    } finally {
      _isSessionSyncInProgress = false;
    }
  }

  Future<void> _syncPresence(UserModel user) async {
    if (!Get.isRegistered<PresenceController>()) return;
    await Get.find<PresenceController>().connectForUser(user);
  }

  /// مزامنة خلفية للطبيب فقط — أوامر دائمة تُعاد بلا نهاية حتى تنجح.
  Future<void> _startDoctorSyncIfNeeded(UserModel user) async {
    if (user.userType.toLowerCase() != 'doctor') {
      SyncWorker.instance.stop();
      return;
    }
    await SyncWorker.instance.start();
  }

  Future<void> _resumeDoctorSyncIfNeeded(UserModel user) async {
    if (user.userType.toLowerCase() != 'doctor') return;
    print('🌐 [AuthController] Resuming doctor outbox sync...');
    await SyncWorker.instance.resumeNow();
  }
}
