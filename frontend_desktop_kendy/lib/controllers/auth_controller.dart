import 'package:get/get.dart';
import 'package:frontend_desktop/models/user_model.dart';
import 'package:frontend_desktop/services/auth_service.dart';
import 'package:frontend_desktop/services/patient_service.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/core/routes/app_routes.dart';
import 'package:frontend_desktop/core/utils/network_utils.dart';

class AuthController extends GetxController {
  final _authService = AuthService();
  final _cacheService = CacheService();
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxnString patientProfileId = RxnString(null);
  final RxBool isLoading = false.obs;
  final RxString otpCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadPersistedSession();
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
        } else {
          print(
            '⚠️ [AuthController] Failed to load user info, clearing session',
          );
          await _clearSession();
        }
      } else {
        print('ℹ️ [AuthController] No saved session found');
        // مسح الـ cache إذا لم يكن هناك token
        await _cacheService.deleteUser();
        currentUser.value = null;
      }
    } catch (e) {
      print('❌ [AuthController] Error loading persisted session: $e');
      // في حالة وجود خطأ (مثل 401 من refresh token)، نمسح الجلسة
      await _clearSession();
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
          // فشل جلب معلومات المستخدم - قد يكون بسبب انتهاء صلاحية الـ token
          print('⚠️ [AuthController] Failed to get user info, clearing session');
          await _clearSession();
          if (navigate) {
            Get.offAllNamed(AppRoutes.userSelection);
          }
        }
      } else {
        print('ℹ️ [AuthController] User is not logged in');
        await _clearSession();
        if (navigate) {
          Get.offAllNamed(AppRoutes.userSelection);
        }
      }
    } catch (e) {
      print('❌ [AuthController] Error checking logged in user: $e');
      // في حالة وجود خطأ (مثل 401 من refresh token)، نمسح الجلسة
      await _clearSession();
      if (navigate) {
        Get.offAllNamed(AppRoutes.userSelection);
      }
    }
  }

  // مسح الجلسة بشكل كامل
  Future<void> _clearSession() async {
    try {
      await _authService.logout();
      await _cacheService.deleteUser();
      currentUser.value = null;
      patientProfileId.value = null;
      print('✅ [AuthController] Session cleared');
    } catch (e) {
      print('⚠️ [AuthController] Error clearing session: $e');
    }
  }

  // تسجيل دخول الطاقم (username/password)
  Future<void> loginDoctor({
    required String username,
    required String password,
  }) async {
    print('🎯 [AuthController] loginDoctor called: $username');

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
          currentUser.value = user;
          
          // حفظ في Cache - بنفس طريقة eversheen
          await _cacheService.saveUser(user);
          
          await _syncPatientProfileId();

          String targetRoute;
          switch (user.userType.toLowerCase()) {
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
          Get.offAllNamed(targetRoute);
          // انتظار قليلاً حتى تكتمل عملية التنقل قبل عرض Snackbar
          await Future.delayed(const Duration(milliseconds: 300));
          if (Get.context != null) {
            try {
              Get.snackbar('نجح', 'تم تسجيل الدخول بنجاح');
            } catch (e) {
              print('⚠️ [AuthController] Error showing snackbar: $e');
            }
          }
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
}
