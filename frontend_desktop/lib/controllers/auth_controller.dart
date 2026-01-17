import 'package:get/get.dart';
import 'package:frontend_desktop/models/user_model.dart';
// import 'package:frontend_desktop/core/routes/app_routes.dart'; // Will fix routes manually or assume AppRoutes class exists and matches
import 'package:frontend_desktop/services/auth_service.dart';

import 'package:frontend_desktop/services/patient_service.dart';

import 'package:frontend_desktop/core/routes/app_routes.dart';

class AuthController extends GetxController {
  final _authService = AuthService();
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
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        print('✅ [AuthController] Token found, loading user info...');
        final res = await _authService.getCurrentUser();
        if (res['ok'] == true) {
          final userData = res['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);
          currentUser.value = user;
          await _syncPatientProfileId();
          print(
            '✅ [AuthController] User loaded from session: ${user.name} (${user.userType})',
          );
        } else {
          print(
            '⚠️ [AuthController] Failed to load user info, clearing session',
          );
          await _authService.logout();
          currentUser.value = null;
        }
      } else {
        print('ℹ️ [AuthController] No saved session found');
      }
    } catch (e) {
      print('❌ [AuthController] Error loading persisted session: $e');
      currentUser.value = null;
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
          await _syncPatientProfileId();
          print(
            '✅ [AuthController] User loaded: ${user.name} (${user.userType})',
          );

          if (!navigate) return;

          if (user.userType == 'doctor') {
            Get.offAllNamed(AppRoutes.doctorHome);
          } else if (user.userType == 'receptionist') {
            // Get.offAllNamed(AppRoutes.receptionHome); // Not implemented yet
            Get.snackbar('Alert', 'Receptionist home not ready yet');
          } else {
            Get.offAllNamed(AppRoutes.userSelection);
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
      currentUser.value = null;
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
          await _syncPatientProfileId();

          String targetRoute;
          switch (user.userType.toLowerCase()) {
            case 'doctor':
              targetRoute = AppRoutes.doctorHome;
              break;
            default:
              targetRoute = AppRoutes.userSelection;
          }

          print('🔀 [AuthController] Navigating to: $targetRoute');
          Get.offAllNamed(targetRoute);
          Get.snackbar('نجح', 'تم تسجيل الدخول بنجاح');
        } else {
          Get.snackbar(
            'خطأ',
            userRes['error']?.toString() ?? 'فشل جلب معلومات المستخدم',
          );
        }
      } else {
        Get.snackbar('خطأ', res['error']?.toString() ?? 'فشل تسجيل الدخول');
      }
    } catch (e) {
      print('❌ [AuthController] General error: $e');
      Get.snackbar('خطأ', 'فشل تسجيل الدخول');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      currentUser.value = null;
      patientProfileId.value = null;
      print('✅ [AuthController] Logged out successfully');
      Get.offAllNamed(AppRoutes.userSelection);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تسجيل الخروج');
    }
  }
}
