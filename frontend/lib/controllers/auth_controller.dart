import 'package:get/get.dart';
import 'package:farah_sys_final/models/user_model.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/fcm_service.dart';
import 'package:farah_sys_final/controllers/chat_controller.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';

class AuthController extends GetxController {
  final _authService = AuthService();
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxnString patientProfileId = RxnString(null);
  final RxBool isLoading = false.obs;
  final RxString otpCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // تحميل التوكن والمستخدم المحفوظين عند بدء التطبيق
    _loadPersistedSession();
  }

  // تحميل التوكن والمستخدم من الـ storage
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

          // Connect to Socket.IO after loading user from session
          try {
            final chatController = Get.find<ChatController>();
            chatController.connectOnLogin();
          } catch (e) {
            print(
              '⚠️ [AuthController] Error connecting Socket.IO on session load: $e',
            );
          }
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
        print('✅ [AuthController] User is logged in, fetching user info...');
        final res = await _authService.getCurrentUser();
        if (res['ok'] == true) {
          final userData = res['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);
          currentUser.value = user;
          await _syncPatientProfileId();
          print(
            '✅ [AuthController] User loaded: ${user.name} (${user.userType})',
          );

          // Connect to Socket.IO after loading user
          try {
            final chatController = Get.find<ChatController>();
            chatController.connectOnLogin();
          } catch (e) {
            print(
              '⚠️ [AuthController] Error connecting Socket.IO on checkLoggedInUser: $e',
            );
          }

          if (!navigate) {
            return;
          }

          if (user.userType == 'patient') {
            Get.offAllNamed(AppRoutes.patientHome);
          } else if (user.userType == 'doctor') {
            Get.offAllNamed(AppRoutes.doctorHome);
          } else if (user.userType == 'receptionist') {
            Get.offAllNamed(AppRoutes.receptionHome);
          } else {
            Get.offAllNamed(AppRoutes.userSelection);
          }
        }
      } else {
        print('ℹ️ [AuthController] User is not logged in');
      }
    } catch (e) {
      print('❌ [AuthController] Error checking logged in user: $e');
      currentUser.value = null;
    }
  }

  // طلب إرسال OTP
  Future<void> requestOtp(String phoneNumber) async {
    print('🎯 [AuthController] requestOtp called');
    print('   📱 Phone: $phoneNumber');

    if (phoneNumber.trim().isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال رقم الهاتف');
      return;
    }

    try {
      print('⏳ [AuthController] Setting loading to true');
      isLoading.value = true;
      print('📞 [AuthController] Calling authService.requestOtp...');

      final res = await _authService.requestOtp(phoneNumber.trim());

      if (res['ok'] == true) {
        print('✅ [AuthController] OTP request completed successfully');
        Get.snackbar('نجح', 'تم إرسال رمز التحقق');
      } else {
        print('❌ [AuthController] OTP request failed: ${res['error']}');
        Get.snackbar('خطأ', res['error']?.toString() ?? 'فشل إرسال رمز التحقق');
      }
    } catch (e) {
      print('❌ [AuthController] General error: $e');
      Get.snackbar('خطأ', 'حدث خطأ أثناء إرسال رمز التحقق');
    } finally {
      print('🏁 [AuthController] Setting loading to false');
      isLoading.value = false;
    }
  }

  // التحقق من OTP وتسجيل الدخول
  Future<void> verifyOtpAndLogin({
    required String phoneNumber,
    required String code,
  }) async {
    print('🎯 [AuthController] verifyOtpAndLogin called');
    print('   📱 Phone: $phoneNumber');
    print('   🔑 Code: $code');

    if (phoneNumber.trim().isEmpty || code.trim().isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال رقم الهاتف والرمز');
      return;
    }

    try {
      print('⏳ [AuthController] Setting loading to true');
      isLoading.value = true;

      print('🔐 [AuthController] Calling authService.verifyOtp...');

      final res = await _authService.verifyOtp(
        phone: phoneNumber.trim(),
        code: code.trim(),
      );

      if (res['ok'] == true) {
        final accountExists = res['accountExists'] as bool? ?? false;

        if (!accountExists) {
          // الحساب غير موجود - الانتقال إلى صفحة إنشاء الحساب
          print(
            '⚠️ [AuthController] Account does not exist, navigating to registration',
          );
          Get.offNamed(
            AppRoutes.patientRegistration,
            arguments: {'phoneNumber': phoneNumber},
          );
          return;
        }

        print('✅ [AuthController] OTP verified successfully, account exists');

        // جلب معلومات المستخدم بعد التحقق من OTP
        final userRes = await _authService.getCurrentUser();
        if (userRes['ok'] == true) {
          final userData = userRes['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);

          print(
            '✅ [AuthController] User loaded: ${user.name} (${user.userType})',
          );
          currentUser.value = user;
          print('💾 [AuthController] Current user updated in controller');

          // التحقق من وجود طبيب مرتبط
          print('🔍 [AuthController] Checking doctor assignment...');
          final patientService = PatientService();
          try {
            final patientProfile = await patientService.getMyProfile();
            print('📋 [AuthController] Patient profile loaded:');
            print('   - Patient ID: ${patientProfile.id}');
            print('   - Doctor IDs: ${patientProfile.doctorIds}');
          patientProfileId.value = patientProfile.id;

            final hasDoctor = patientProfile.doctorIds.isNotEmpty;

            print('🔍 [AuthController] Has doctor: $hasDoctor');

            // Register FCM token after successful login
            try {
              final fcmService = Get.find<FcmService>();
              await fcmService.reRegisterToken();
            } catch (e) {
              print('⚠️ [AuthController] Error re-registering FCM token: $e');
            }

            // Connect to Socket.IO after successful login
            try {
              final chatController = Get.find<ChatController>();
              chatController.connectOnLogin();
            } catch (e) {
              print(
                '⚠️ [AuthController] Error connecting Socket.IO on login: $e',
              );
            }

            if (hasDoctor) {
              print(
                '✅ [AuthController] Patient has doctor assigned (IDs: ${patientProfile.doctorIds}), navigating to home',
              );
              Get.offAllNamed(AppRoutes.patientHome);
              Get.snackbar('نجح', 'تم تسجيل الدخول بنجاح');
            } else {
              print(
                '⚠️ [AuthController] Patient has no doctor assigned, navigating to welcome screen',
              );
              Get.offAllNamed(AppRoutes.patientWelcome);
            }
          } catch (e) {
            print('❌ [AuthController] Error checking doctor assignment: $e');
            print(
              '❌ [AuthController] Error stack trace: ${StackTrace.current}',
            );
            // في حالة الخطأ، نذهب إلى واجهة الترحيب
            Get.offAllNamed(AppRoutes.patientWelcome);
          }
        } else {
          print(
            '❌ [AuthController] Failed to get user info: ${userRes['error']}',
          );
          Get.snackbar(
            'خطأ',
            userRes['error']?.toString() ?? 'فشل جلب معلومات المستخدم',
          );
        }
      } else {
        print('❌ [AuthController] OTP verification failed: ${res['error']}');
        Get.snackbar(
          'خطأ',
          res['error']?.toString() ?? 'فشل التحقق من رمز OTP',
        );
      }
    } catch (e) {
      print('❌ [AuthController] General error: $e');
      Get.snackbar('خطأ', 'فشل التحقق من رمز OTP');
    } finally {
      print('🏁 [AuthController] Setting loading to false');
      isLoading.value = false;
    }
  }

  // إنشاء حساب مريض جديد
  Future<void> createPatientAccount({
    required String phoneNumber,
    required String name,
    String? gender,
    int? age,
    String? city,
  }) async {
    print('🎯 [AuthController] createPatientAccount called');
    print('   📱 Phone: $phoneNumber');
    print('   👤 Name: $name');

    try {
      isLoading.value = true;

      final res = await _authService.createPatientAccount(
        phone: phoneNumber.trim(),
        name: name,
        gender: gender,
        age: age,
        city: city,
      );

      if (res['ok'] == true) {
        print('✅ [AuthController] Account created successfully');

        // جلب معلومات المستخدم بعد إنشاء الحساب
        final userRes = await _authService.getCurrentUser();
        if (userRes['ok'] == true) {
          final userData = userRes['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);

          print(
            '✅ [AuthController] User loaded: ${user.name} (${user.userType})',
          );
          currentUser.value = user;
          await _syncPatientProfileId();

          // Register FCM token after account creation
          try {
            final fcmService = Get.find<FcmService>();
            await fcmService.reRegisterToken();
          } catch (e) {
            print('⚠️ [AuthController] Error re-registering FCM token: $e');
          }

          // بعد إنشاء الحساب، الانتقال إلى صفحة الترحيب (لأنه ليس له طبيب بعد)
          print('🔀 [AuthController] Navigating to welcome screen');
          Get.offAllNamed(AppRoutes.patientWelcome);
          Get.snackbar('نجح', 'تم إنشاء الحساب بنجاح');
        } else {
          Get.snackbar(
            'خطأ',
            userRes['error']?.toString() ?? 'فشل جلب معلومات المستخدم',
          );
        }
      } else {
        print('❌ [AuthController] Account creation failed: ${res['error']}');
        Get.snackbar('خطأ', res['error']?.toString() ?? 'فشل إنشاء الحساب');
      }
    } catch (e) {
      print('❌ [AuthController] Error in createPatientAccount: $e');
      Get.snackbar('خطأ', 'فشل إنشاء الحساب');
    } finally {
      isLoading.value = false;
    }
  }

  // تسجيل دخول المريض (مع OTP)
  Future<void> loginPatient(String phoneNumber) async {
    await requestOtp(phoneNumber);
  }

  // تسجيل دخول الطاقم (username/password)
  Future<void> loginDoctor({
    required String username,
    required String password,
  }) async {
    print('🎯 [AuthController] loginDoctor called');
    print('   👤 Username: $username');
    print('   🔑 Password: ${'*' * password.length}');

    if (username.trim().isEmpty || password.trim().isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال اسم المستخدم وكلمة المرور');
      return;
    }

    try {
      print('⏳ [AuthController] Setting loading to true');
      isLoading.value = true;
      print('🔐 [AuthController] Calling authService.staffLogin...');

      final res = await _authService.staffLogin(
        username: username.trim(),
        password: password,
      );

      if (res['ok'] == true) {
        print('✅ [AuthController] Login successful');

        // جلب معلومات المستخدم بعد تسجيل الدخول
        final userRes = await _authService.getCurrentUser();
        if (userRes['ok'] == true) {
          final userData = userRes['data'] as Map<String, dynamic>;

          // Log raw data from backend
          print('📋 [AuthController] Raw user data from backend:');
          print('   Role: ${userData['role']}');
          print('   UserType: ${userData['userType']}');
          print('   Full data: $userData');

          final user = UserModel.fromJson(userData);

          print(
            '✅ [AuthController] User loaded: ${user.name} (${user.userType})',
          );
          print('   🔍 Mapped userType: ${user.userType}');
          currentUser.value = user;
          await _syncPatientProfileId();
          print('💾 [AuthController] Current user updated in controller');

          // توجيه حسب نوع المستخدم القادم من الـ Backend
          String targetRoute;
          switch (user.userType.toLowerCase()) {
            case 'doctor':
              targetRoute = AppRoutes.doctorHome;
              break;
            case 'receptionist':
              targetRoute = AppRoutes.receptionHome;
              break;
            case 'photographer':
              targetRoute =
                  AppRoutes.receptionHome; // أو صفحة خاصة بالـ photographer
              break;
            case 'admin':
              targetRoute = AppRoutes.userSelection;
              break;
            default:
              print(
                '⚠️ [AuthController] Unknown userType: ${user.userType}, defaulting to userSelection',
              );
              targetRoute = AppRoutes.userSelection;
          }

          // Register FCM token after successful login
          try {
            final fcmService = Get.find<FcmService>();
            await fcmService.reRegisterToken();
          } catch (e) {
            print('⚠️ [AuthController] Error re-registering FCM token: $e');
          }

          // Connect to Socket.IO after successful login
          try {
            final chatController = Get.find<ChatController>();
            chatController.connectOnLogin();
          } catch (e) {
            print(
              '⚠️ [AuthController] Error connecting Socket.IO on login: $e',
            );
          }

          print(
            '🔀 [AuthController] Navigating to: $targetRoute (userType: ${user.userType})',
          );
          Get.offAllNamed(targetRoute);
          // انتظار قليلاً حتى تكتمل عملية التنقل قبل عرض Snackbar
          await Future.delayed(const Duration(milliseconds: 300));
          if (Get.context != null && Get.context!.mounted) {
            try {
              Get.snackbar('نجح', 'تم تسجيل الدخول بنجاح');
            } catch (e) {
              print('⚠️ [AuthController] Error showing snackbar: $e');
            }
          }
        } else {
          print(
            '❌ [AuthController] Failed to get user info: ${userRes['error']}',
          );
          final errorMsg = userRes['error']?.toString() ?? 'فشل جلب معلومات المستخدم';
          if (NetworkUtils.isNetworkError(errorMsg)) {
            NetworkUtils.showNetworkErrorDialog();
          } else {
            Get.snackbar('خطأ', errorMsg);
          }
        }
      } else {
        print('❌ [AuthController] Login failed: ${res['error']}');
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
      print('🏁 [AuthController] Setting loading to false');
      isLoading.value = false;
    }
  }

  // تسجيل مريض جديد (مع OTP)
  Future<bool> registerPatient({
    required String name,
    required String phoneNumber,
    required String gender,
    required int age,
    required String city,
  }) async {
    print('🎯 [AuthController] registerPatient called');
    print('   📱 Phone: $phoneNumber');
    print('   👤 Name: $name');

    try {
      isLoading.value = true;
      // إضافة المريض وربطه بالطبيب مباشرة
      final doctorService = DoctorService();
      await doctorService.addPatient(
        name: name,
        phoneNumber: phoneNumber.trim(),
        gender: gender,
        age: age,
        city: city,
      );

      return true;
    } catch (e) {
      print('❌ [AuthController] Error in registerPatient: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    print('🎯 [AuthController] logout called');
    try {
      await _authService.logout();
      currentUser.value = null;
      patientProfileId.value = null;
      print('✅ [AuthController] Logged out successfully');
      Get.offAllNamed(AppRoutes.userSelection);
    } catch (e) {
      print('❌ [AuthController] Error during logout: $e');
      final errorMsg = e.toString();
      if (NetworkUtils.isNetworkError(errorMsg)) {
        NetworkUtils.showNetworkErrorDialog();
      } else {
        Get.snackbar('خطأ', 'حدث خطأ أثناء تسجيل الخروج');
      }
    }
  }
}
