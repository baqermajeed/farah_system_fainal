import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/models/user_model.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/services/auth_service.dart';
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/fcm_service.dart';
import 'package:farah_sys_final/services/token_storage.dart';
import 'package:farah_sys_final/controllers/chat_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/notifications_screen_controller.dart';
import 'package:farah_sys_final/controllers/presence_controller.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';

class AuthController extends GetxController {
  final AuthService _authService;
  final TokenStorage _tokenStorage;

  /// بيانات المستخدم في الذاكرة فقط (مثل قريب) — لا تُحفظ في Secure Storage.
  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final RxnString patientProfileId = RxnString(null);
  final RxBool isLoading = false.obs;
  /// true أثناء استعادة الجلسة عند فتح التطبيق (مثل قريب).
  final RxBool isRestoringSession = true.obs;
  final RxString otpCode = ''.obs;

  void _logError(Object e, [String? context]) {
    if (kDebugMode) {
      final prefix = context != null ? ' $context' : '';
      debugPrint('[AuthController]$prefix: $e');
    }
  }

  Future<void>? _loadStoredAuthInFlight;

  AuthController({AuthService? authService, TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ??
            (Get.isRegistered<TokenStorage>()
                ? Get.find<TokenStorage>()
                : TokenStorage()),
        _authService = authService ??
            AuthService(
              tokenStorage: tokenStorage ??
                  (Get.isRegistered<TokenStorage>()
                      ? Get.find<TokenStorage>()
                      : null),
              dio: Get.isRegistered<ApiService>()
                  ? Get.find<ApiService>().client
                  : null,
            );

  /// يُنشأ مع حقن TokenStorage + Dio الموحّد (نمط قريب).
  factory AuthController.withStorage(TokenStorage tokenStorage) {
    return AuthController(
      tokenStorage: tokenStorage,
      authService: AuthService(
        tokenStorage: tokenStorage,
        dio: Get.isRegistered<ApiService>()
            ? Get.find<ApiService>().client
            : null,
      ),
    );
  }

  bool get isAuthenticated => currentUser.value != null;

  /// استعادة الجلسة: توكن → getCurrentUser (getMe) → currentUser.obs
  Future<void> loadStoredAuth() {
    return _loadStoredAuthInFlight ??= _doLoadStoredAuth().whenComplete(() {
      _loadStoredAuthInFlight = null;
    });
  }

  Future<void> _doLoadStoredAuth() async {
    isRestoringSession.value = true;
    try {
      final hasTokens = await _tokenStorage.hasTokens();
      if (!hasTokens) {
        currentUser.value = null;
        patientProfileId.value = null;
        isRestoringSession.value = false;
        return;
      }

      final res = await _authService.getCurrentUser();
      if (res['ok'] == true) {
        final userData = res['data'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);
        currentUser.value = user;
        await _syncPatientProfileId();
        _connectSocketAfterSession();
        _syncFcmAfterSession();
        _syncPresenceAfterSession();
      } else {
        await _tokenStorage.clearSession();
        currentUser.value = null;
        patientProfileId.value = null;
      }
      isRestoringSession.value = false;
    } catch (e) {
      _logError(e, 'loadStoredAuth');
      await _tokenStorage.clearSession();
      currentUser.value = null;
      patientProfileId.value = null;
      isRestoringSession.value = false;
    }
  }

  void _connectSocketAfterSession() {
    try {
      final chatController = Get.find<ChatController>();
      chatController.connectOnLogin();
    } catch (e) {
      _logError(e);
    }
  }

  void _syncFcmAfterSession() {
    try {
      if (Get.isRegistered<FcmService>()) {
        Get.find<FcmService>().reRegisterToken();
      }
    } catch (e) {
      _logError(e);
    }
  }

  void _syncPresenceAfterSession() {
    try {
      final user = currentUser.value;
      if (user == null) return;
      if (Get.isRegistered<PresenceController>()) {
        Get.find<PresenceController>().connectForUser(user);
      }
    } catch (e) {
      _logError(e);
    }
  }

  Future<void> _syncPatientProfileId() async {
    final userType = currentUser.value?.userType.toLowerCase();
    if (userType != 'patient') {
      patientProfileId.value = null;
      return;
    }

    try {
      final stored = await _authService.getActivePatientId();
      if (stored != null && stored.isNotEmpty) {
        patientProfileId.value = stored;
        return;
      }

      final patientService = PatientService();
      final members = await patientService.getFamilyProfiles();
      if (members.length == 1) {
        patientProfileId.value = members.first.id;
        await _authService.saveActivePatientId(members.first.id);
      }
    } catch (e) {
      _logError(e);
    }
  }

  Future<void> _afterPatientAuthSetup({bool showSuccessSnackbar = false}) async {
    try {
      final fcmService = Get.find<FcmService>();
      await fcmService.reRegisterToken();
    } catch (e) {
      _logError(e);
    }

    try {
      final chatController = Get.find<ChatController>();
      chatController.connectOnLogin();
    } catch (e) {
      _logError(e);
    }

    _syncPresenceAfterSession();

    if (showSuccessSnackbar) {
      Get.snackbar('نجح', 'تم تسجيل الدخول بنجاح');
    }
  }

  Future<void> resolveFamilyAndNavigate({
    bool showSuccessSnackbar = false,
  }) async {
    final patientService = PatientService();
    final members = await patientService.getFamilyProfiles();

    if (members.isEmpty) {
      Get.offAllNamed(AppRoutes.patientWelcome);
      return;
    }

    if (members.length == 1) {
      await selectFamilyMember(
        members.first.id,
        showSuccessSnackbar: showSuccessSnackbar,
      );
      return;
    }

    final stored = await _authService.getActivePatientId();
    if (stored != null && members.any((m) => m.id == stored)) {
      await selectFamilyMember(stored, showSuccessSnackbar: showSuccessSnackbar);
      return;
    }

    Get.offAllNamed(
      AppRoutes.familyMemberSelection,
      arguments: {'members': members},
    );
  }

  Future<void> selectFamilyMember(
    String patientId, {
    bool showSuccessSnackbar = false,
  }) async {
    patientProfileId.value = patientId;
    await _authService.saveActivePatientId(patientId);

    final patientService = PatientService();
    final profile = await patientService.getMyProfile(patientId: patientId);
    final hasDoctor = profile.doctorIds.isNotEmpty;

    // حدّث الملف الطبي النشط فوراً حتى لا تبقى بيانات/صورة فرد سابق في الـ UI
    try {
      final patientController = Get.find<PatientController>();
      patientController.applyActiveFamilyProfile(profile);
    } catch (e) {
      _logError(e, 'selectFamilyMember/applyActiveFamilyProfile');
    }

    // امسح مواعيد الفرد السابق من الذاكرة (الكاش الآن مفصول حسب patient_id)
    try {
      final appointmentController = Get.find<AppointmentController>();
      appointmentController.appointments.clear();
      appointmentController.primaryAppointments.clear();
      appointmentController.secondaryAppointments.clear();
    } catch (e) {
      _logError(e, 'selectFamilyMember/clearAppointments');
    }

    // امسح إشعارات الفرد السابق من الذاكرة إن كانت شاشة الإشعارات محمّلة
    try {
      if (Get.isRegistered<NotificationsScreenController>()) {
        final n = Get.find<NotificationsScreenController>();
        n.notifications.clear();
        n.hasMore.value = true;
      }
    } catch (e) {
      _logError(e, 'selectFamilyMember/clearNotifications');
    }

    await _afterPatientAuthSetup(showSuccessSnackbar: showSuccessSnackbar);

    if (hasDoctor) {
      Get.offAllNamed(AppRoutes.patientHome);
    } else {
      Get.offAllNamed(AppRoutes.patientWelcome);
    }
  }

  Future<void> switchFamilyMember() async {
    try {
      isLoading.value = true;
      final patientService = PatientService();
      final members = await patientService.getFamilyProfiles();
      if (members.length <= 1) {
        Get.snackbar('تنبيه', 'لا يوجد أكثر من فرد في العائلة');
        return;
      }
      Get.toNamed(
        AppRoutes.familyMemberSelection,
        arguments: {'members': members},
      );
    } catch (e) {
      await NetworkUtils.showError(
        e,
        fallbackMessage: 'فشل تحميل أفراد العائلة',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> checkLoggedInUser({bool navigate = true}) async {
    await loadStoredAuth();

    if (!navigate || !isAuthenticated) {
      return;
    }

    final user = currentUser.value!;
    if (user.userType == 'patient') {
      await resolveFamilyAndNavigate();
    } else if (user.userType == 'doctor') {
      Get.offAllNamed(AppRoutes.doctorHome);
    } else if (user.userType == 'receptionist') {
      Get.offAllNamed(AppRoutes.receptionHome);
    } else {
      Get.offAllNamed(AppRoutes.userSelection);
    }
  }

  // طلب إرسال OTP
  Future<void> requestOtp(String phoneNumber) async {

    if (phoneNumber.trim().isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال رقم الهاتف');
      return;
    }

    try {
      isLoading.value = true;

      final res = await _authService.requestOtp(phoneNumber.trim());

      if (res['ok'] == true) {
        Get.snackbar('نجح', 'تم إرسال رمز التحقق');
      } else {
        await NetworkUtils.showError(
          res['error']?.toString() ?? 'فشل إرسال رمز التحقق',
        );
      }
    } catch (e) {
      _logError(e, 'requestOtp');
      await NetworkUtils.showError(
        e,
        fallbackMessage: 'حدث خطأ أثناء إرسال رمز التحقق',
      );
    } finally {
      isLoading.value = false;
    }
  }

  // التحقق من OTP وتسجيل الدخول
  Future<void> verifyOtpAndLogin({
    required String phoneNumber,
    required String code,
  }) async {

    if (phoneNumber.trim().isEmpty || code.trim().isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال رقم الهاتف والرمز');
      return;
    }

    try {
      isLoading.value = true;


      final res = await _authService.verifyOtp(
        phone: phoneNumber.trim(),
        code: code.trim(),
      );

      if (res['ok'] == true) {
        final accountExists = res['accountExists'] as bool? ?? false;

        if (!accountExists) {
          // الحساب غير موجود - الانتقال إلى صفحة إنشاء الحساب
          Get.offNamed(
            AppRoutes.patientRegistration,
            arguments: {'phoneNumber': phoneNumber},
          );
          return;
        }


        // جلب معلومات المستخدم بعد التحقق من OTP
        final userRes = await _authService.getCurrentUser();
        if (userRes['ok'] == true) {
          final userData = userRes['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);

          currentUser.value = user;

          try {
            await resolveFamilyAndNavigate(showSuccessSnackbar: true);
          } catch (e) {
            Get.offAllNamed(AppRoutes.patientWelcome);
          }
        } else {
          Get.snackbar(
            'خطأ',
            userRes['error']?.toString() ?? 'فشل جلب معلومات المستخدم',
          );
        }
      } else {
        Get.snackbar(
          'خطأ',
          res['error']?.toString() ?? 'فشل التحقق من رمز OTP',
        );
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل التحقق من رمز OTP');
    } finally {
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

        // جلب معلومات المستخدم بعد إنشاء الحساب
        final userRes = await _authService.getCurrentUser();
        if (userRes['ok'] == true) {
          final userData = userRes['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);

          currentUser.value = user;
          await _syncPatientProfileId();

          // Register FCM token after account creation
          try {
            final fcmService = Get.find<FcmService>();
            await fcmService.reRegisterToken();
          } catch (e) {
            _logError(e);
          }

          // بعد إنشاء الحساب، الانتقال إلى صفحة الترحيب (لأنه ليس له طبيب بعد)
          Get.offAllNamed(AppRoutes.patientWelcome);
          Get.snackbar('نجح', 'تم إنشاء الحساب بنجاح');
        } else {
          await NetworkUtils.showError(
            userRes['error']?.toString() ?? 'فشل جلب معلومات المستخدم',
          );
        }
      } else {
        await NetworkUtils.showError(
          res['error']?.toString() ?? 'فشل إنشاء الحساب',
        );
      }
    } catch (e) {
      await NetworkUtils.showError(e, fallbackMessage: 'فشل إنشاء الحساب');
    } finally {
      isLoading.value = false;
    }
  }

  // تسجيل دخول المريض (مع OTP)
  Future<void> loginPatient(String phoneNumber) async {
    await requestOtp(phoneNumber);
  }

  // تسجيل دخول الطاقم (username/password)
  /// يعيد `null` عند النجاح، أو رسالة الخطأ عند الفشل.
  /// عند [showErrorUi]=false لا تُعرض Snackbar (ما عدا أخطاء الشبكة).
  Future<String?> loginDoctor({
    required String username,
    required String password,
    bool showErrorUi = true,
  }) async {

    if (username.trim().isEmpty || password.trim().isEmpty) {
      const msg = 'يرجى إدخال اسم المستخدم وكلمة المرور';
      if (showErrorUi) {
        Get.snackbar('خطأ', msg);
      }
      return msg;
    }

    try {
      isLoading.value = true;

      final res = await _authService.staffLogin(
        username: username.trim(),
        password: password,
      );

      if (res['ok'] == true) {

        // جلب معلومات المستخدم بعد تسجيل الدخول
        final userRes = await _authService.getCurrentUser();
        if (userRes['ok'] == true) {
          final userData = userRes['data'] as Map<String, dynamic>;
          final user = UserModel.fromJson(userData);

          currentUser.value = user;
          await _syncPatientProfileId();

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
              targetRoute = AppRoutes.userSelection;
          }

          // Register FCM token after successful login
          try {
            final fcmService = Get.find<FcmService>();
            await fcmService.reRegisterToken();
          } catch (e) {
            _logError(e);
          }

          // Connect to Socket.IO after successful login
          try {
            final chatController = Get.find<ChatController>();
            chatController.connectOnLogin();
          } catch (e) {
            _logError(e);
          }

          _syncPresenceAfterSession();

          Get.offAllNamed(targetRoute);
          // انتظار قليلاً حتى تكتمل عملية التنقل قبل عرض Snackbar
          await Future.delayed(const Duration(milliseconds: 300));
          if (Get.context != null && Get.context!.mounted) {
            try {
              Get.snackbar('نجح', 'تم تسجيل الدخول بنجاح');
            } catch (e) {
              _logError(e);
            }
          }
          return null;
        } else {
          final errorMsg = userRes['error']?.toString() ?? 'فشل جلب معلومات المستخدم';
          if (showErrorUi) {
            await NetworkUtils.showError(errorMsg);
          }
          return errorMsg;
        }
      } else {
        final errorMsg = _staffLoginErrorMessage(res);
        if (showErrorUi || NetworkUtils.isNetworkError(errorMsg) ||
            NetworkUtils.hasForbiddenConnectionText(errorMsg)) {
          await NetworkUtils.showError(errorMsg);
        }
        return errorMsg;
      }
    } catch (e) {
      final errorMsg = _staffLoginErrorMessage({'error': e.toString(), 'statusCode': null});
      if (showErrorUi || NetworkUtils.isNetworkError(e) ||
          NetworkUtils.hasForbiddenConnectionText(errorMsg)) {
        await NetworkUtils.showError(errorMsg, fallbackMessage: errorMsg);
      }
      return errorMsg;
    } finally {
      isLoading.value = false;
    }
  }

  /// رسالة مناسبة لخطأ بيانات الدخول (بدل «فشل تسجيل الدخول» العامة).
  String _staffLoginErrorMessage(Map<String, dynamic> res) {
    const credentialsMsg = 'اسم المستخدم أو كلمة المرور غير صحيحة';
    final statusCode = res['statusCode'];
    final raw = res['error']?.toString() ?? '';
    final lower = raw.toLowerCase();

    if (statusCode == 401 || statusCode == 400 || statusCode == 422) {
      return credentialsMsg;
    }
    if (lower.contains('incorrect') ||
        lower.contains('invalid') ||
        lower.contains('unauthorized') ||
        lower.contains('credential') ||
        lower.contains('password') ||
        raw.contains('غير صحيح') ||
        raw.contains('غير صحيحة') ||
        raw.contains('فشل تسجيل الدخول')) {
      return credentialsMsg;
    }
    if (raw.trim().isEmpty) return credentialsMsg;
    return raw;
  }

  // تسجيل مريض جديد (مع OTP)
  Future<bool> registerPatient({
    required String name,
    required String phoneNumber,
    required String gender,
    required int age,
    required String city,
  }) async {

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
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    try {
      if (Get.isRegistered<PresenceController>()) {
        Get.find<PresenceController>().disconnect();
      }
      await _authService.logout();
      currentUser.value = null;
      patientProfileId.value = null;
      Get.offAllNamed(AppRoutes.userSelection);
    } catch (e) {
      final errorMsg = e.toString();
      await NetworkUtils.showError(errorMsg, fallbackMessage: 'حدث خطأ أثناء تسجيل الخروج');
    }
  }
}
