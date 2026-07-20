import 'package:farah_sys_final/views/working_hours_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:farah_sys_final/core/theme/app_theme.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/views/splash_screen.dart';
import 'package:farah_sys_final/views/onboarding_screen.dart';
import 'package:farah_sys_final/views/user_selection_screen.dart';
import 'package:farah_sys_final/views/patient_login_screen.dart';
import 'package:farah_sys_final/views/doctor_login_screen.dart';
import 'package:farah_sys_final/views/add_patient_screen.dart';
import 'package:farah_sys_final/views/patient_home_screen.dart';
import 'package:farah_sys_final/views/patient_welcome_screen.dart';
import 'package:farah_sys_final/views/patient_browse_screen.dart';
import 'package:farah_sys_final/views/appointments_screen.dart';
import 'package:farah_sys_final/views/appointments_by_date_screen.dart';
import 'package:farah_sys_final/views/patient_appointments_screen.dart';
import 'package:farah_sys_final/views/chat_screen.dart';
import 'package:farah_sys_final/views/patient_profile_screen.dart';
import 'package:farah_sys_final/views/edit_patient_profile_screen.dart';
import 'package:farah_sys_final/views/qr_code_screen.dart';
import 'package:farah_sys_final/views/doctor_patients_list_screen.dart';
import 'package:farah_sys_final/views/doctor_home_screen.dart';
import 'package:farah_sys_final/views/patient_details_screen.dart';
import 'package:farah_sys_final/views/medical_records_screen.dart';
import 'package:farah_sys_final/views/doctor_chats_screen.dart';
import 'package:farah_sys_final/views/doctor_profile_screen.dart';
import 'package:farah_sys_final/views/edit_doctor_profile_screen.dart';
import 'package:farah_sys_final/views/notifications_screen.dart';
import 'package:farah_sys_final/views/dental_implant_timeline_screen.dart';
import 'package:farah_sys_final/views/reception_login_screen.dart';
import 'package:farah_sys_final/views/reception_home_screen.dart';
import 'package:farah_sys_final/views/reception_profile_screen.dart';
import 'package:farah_sys_final/views/edit_reception_profile_screen.dart';
import 'package:farah_sys_final/views/qr_scanner_screen.dart';
import 'package:farah_sys_final/views/otp_verification_screen.dart';
import 'package:farah_sys_final/views/patient_registration_screen.dart';
import 'package:farah_sys_final/views/family_member_selection_screen.dart';
import 'package:farah_sys_final/views/select_doctor_screen.dart';
import 'package:farah_sys_final/views/edit_implant_stage_date_screen.dart';
import 'package:farah_sys_final/models/user_model.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/models/medical_record_model.dart';
import 'package:farah_sys_final/models/message_model.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/chat_controller.dart';
import 'package:farah_sys_final/controllers/splash_controller.dart';
import 'package:farah_sys_final/controllers/patient_login_controller.dart';
import 'package:farah_sys_final/controllers/doctor_login_controller.dart';
import 'package:farah_sys_final/controllers/reception_login_controller.dart';
import 'package:farah_sys_final/controllers/otp_verification_controller.dart';
import 'package:farah_sys_final/controllers/appointments_by_date_controller.dart';
import 'package:farah_sys_final/controllers/doctor_profile_controller.dart';
import 'package:farah_sys_final/controllers/reception_profile_controller.dart';
import 'package:farah_sys_final/controllers/patient_profile_controller.dart';
import 'package:farah_sys_final/controllers/patient_home_controller.dart';
import 'package:farah_sys_final/controllers/appointments_screen_controller.dart';
import 'package:farah_sys_final/controllers/edit_patient_profile_controller.dart';
import 'package:farah_sys_final/controllers/reception_home_controller.dart';
import 'package:farah_sys_final/controllers/doctor_home_controller.dart';
import 'package:farah_sys_final/controllers/patient_welcome_controller.dart';
import 'package:farah_sys_final/controllers/edit_doctor_profile_controller.dart';
import 'package:farah_sys_final/controllers/edit_reception_profile_controller.dart';
import 'package:farah_sys_final/controllers/user_selection_controller.dart';
import 'package:farah_sys_final/controllers/onboarding_controller.dart';
import 'package:farah_sys_final/controllers/patient_registration_controller.dart';
import 'package:farah_sys_final/controllers/select_doctor_controller.dart';
import 'package:farah_sys_final/controllers/edit_implant_stage_date_controller.dart';
import 'package:farah_sys_final/controllers/qr_scanner_controller.dart';
import 'package:farah_sys_final/controllers/add_patient_controller.dart';
import 'package:farah_sys_final/controllers/doctor_patients_list_controller.dart';
import 'package:farah_sys_final/controllers/doctor_chats_screen_controller.dart';
import 'package:farah_sys_final/controllers/notifications_screen_controller.dart';
import 'package:farah_sys_final/controllers/medical_records_screen_controller.dart';
import 'package:farah_sys_final/controllers/dental_implant_timeline_controller.dart';
import 'package:farah_sys_final/controllers/chat_screen_controller.dart';
import 'package:farah_sys_final/controllers/patient_details_controller.dart';
import 'package:farah_sys_final/services/fcm_service.dart';
import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/services/token_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase 1
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Arabic locale for DateFormat
  await initializeDateFormatting('ar', null);

  await Hive.initFlutter();

  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(PatientModelAdapter());
  Hive.registerAdapter(AppointmentModelAdapter());
  Hive.registerAdapter(MedicalRecordModelAdapter());
  Hive.registerAdapter(MessageModelAdapter());

  await Hive.openBox('users');
  await Hive.openBox('patients');
  await Hive.openBox('appointments');
  await Hive.openBox('medicalRecords');
  await Hive.openBox('messages');
  await Hive.openBox('gallery');

  // Initialize Services (TokenStorage أولاً مثل قريب)
  final tokenStorage = TokenStorage();
  Get.put(tokenStorage, permanent: true);
  Get.put(ApiService());

  // Initialize shared Controllers
  Get.put(AuthController.withStorage(tokenStorage), permanent: true);
  Get.put(PatientController());
  Get.put(AppointmentController());
  Get.put(ChatController());

  // Screen controllers (lazy + fenix مثل قريب)
  Get.lazyPut<SplashController>(() => SplashController(), fenix: true);
  Get.lazyPut<PatientLoginController>(() => PatientLoginController(), fenix: true);
  Get.lazyPut<DoctorLoginController>(() => DoctorLoginController(), fenix: true);
  Get.lazyPut<ReceptionLoginController>(
    () => ReceptionLoginController(),
    fenix: true,
  );
  Get.lazyPut<OtpVerificationController>(
    () => OtpVerificationController(),
    fenix: true,
  );
  Get.lazyPut<ReceptionHomeController>(
    () => ReceptionHomeController(),
    fenix: true,
  );
  Get.lazyPut<DoctorHomeController>(
    () => DoctorHomeController(),
    fenix: true,
  );
  Get.lazyPut<PatientWelcomeController>(
    () => PatientWelcomeController(),
    fenix: true,
  );
  Get.lazyPut<EditDoctorProfileController>(
    () => EditDoctorProfileController(),
    fenix: true,
  );
  Get.lazyPut<EditReceptionProfileController>(
    () => EditReceptionProfileController(),
    fenix: true,
  );
  Get.lazyPut<UserSelectionController>(
    () => UserSelectionController(),
    fenix: true,
  );
  Get.lazyPut<OnboardingController>(
    () => OnboardingController(),
    fenix: true,
  );
  // الشاشات التي تعتمد على Get.arguments أو حالة لكل زيارة
  // تُسجَّل عبر BindingsBuilder + Get.put في GetPage أدناه.

  // Initialize FCM Service
  final fcmService = Get.put(FcmService());
  await fcmService.initialize();

  // استعادة الجلسة عند الفتح: توكن → getCurrentUser → currentUser.obs
  Get.find<AuthController>().loadStoredAuth();

  runApp(const MyApp());
}

/// Disable overscroll stretching/glow across the whole app.
/// Also forces clamping physics to avoid iOS bounce.
class NoOverscrollScrollBehavior extends MaterialScrollBehavior {
  const NoOverscrollScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          title: 'مركز فرح',
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          scrollBehavior: const NoOverscrollScrollBehavior(),
          // اجعل أول شاشة تظهر هي شاشة الـ Splash
          initialRoute: AppRoutes.splash,
          getPages: [
            GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
            GetPage(
              name: AppRoutes.onboarding,
              page: () => const OnboardingScreen(),
            ),
            GetPage(
              name: AppRoutes.userSelection,
              page: () => const UserSelectionScreen(),
            ),
            GetPage(
              name: AppRoutes.patientLogin,
              page: () => const PatientLoginScreen(),
            ),
            GetPage(
              name: AppRoutes.doctorLogin,
              page: () => const DoctorLoginScreen(),
            ),
            GetPage(
              name: AppRoutes.otpVerification,
              page: () => const OtpVerificationScreen(),
            ),
            GetPage(
              name: AppRoutes.patientRegistration,
              page: () => const PatientRegistrationScreen(),
              binding: BindingsBuilder(() {
                Get.put<PatientRegistrationController>(
                  PatientRegistrationController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.familyMemberSelection,
              page: () => const FamilyMemberSelectionScreen(),
            ),
            GetPage(
              name: AppRoutes.addPatient,
              page: () => const AddPatientScreen(),
              binding: BindingsBuilder(() {
                Get.put<AddPatientController>(AddPatientController());
              }),
            ),
            GetPage(
              name: AppRoutes.patientHome,
              page: () => const PatientHomeScreen(),
              binding: BindingsBuilder(() {
                Get.put<PatientHomeController>(PatientHomeController());
              }),
            ),
            GetPage(
              name: AppRoutes.patientWelcome,
              page: () => const PatientWelcomeScreen(),
            ),
            GetPage(
              name: AppRoutes.patientBrowse,
              page: () => const PatientBrowseScreen(),
            ),
            GetPage(
              name: AppRoutes.doctorHome,
              page: () => const DoctorHomeScreen(),
            ),
            GetPage(
              name: AppRoutes.doctorPatientsList,
              page: () => const DoctorPatientsListScreen(),
              binding: BindingsBuilder(() {
                Get.put<DoctorPatientsListController>(
                  DoctorPatientsListController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.patientDetails,
              page: () => const PatientDetailsScreen(),
              binding: BindingsBuilder(() {
                Get.put<PatientDetailsController>(PatientDetailsController());
              }),
            ),
            GetPage(
              name: AppRoutes.appointments,
              page: () => const AppointmentsScreen(),
              binding: BindingsBuilder(() {
                Get.put<AppointmentsScreenController>(
                  AppointmentsScreenController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.patientAppointments,
              page: () => const PatientAppointmentsScreen(),
            ),
            GetPage(
              name: AppRoutes.appointmentsByDate,
              page: () => const AppointmentsByDateScreen(),
              binding: BindingsBuilder(() {
                Get.put<AppointmentsByDateController>(
                  AppointmentsByDateController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.chat,
              page: () => const ChatScreen(),
              binding: BindingsBuilder(() {
                Get.put<ChatScreenController>(ChatScreenController());
              }),
            ),
            GetPage(
              name: AppRoutes.patientProfile,
              page: () => const PatientProfileScreen(),
              binding: BindingsBuilder(() {
                Get.put<PatientProfileController>(
                  PatientProfileController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.editPatientProfile,
              page: () => const EditPatientProfileScreen(),
              binding: BindingsBuilder(() {
                Get.put<EditPatientProfileController>(
                  EditPatientProfileController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.qrCode,
              page: () {
                final args = Get.arguments as Map<String, dynamic>?;
                final patientId = args?['patientId'] ?? '';
                final qrCodeData = args?['qrCodeData'] ?? patientId;
                return QrCodeScreen(
                  patientId: patientId,
                  patientName: args?['patientName'] ?? 'مريض',
                  qrCodeData: qrCodeData,
                );
              },
            ),
            GetPage(
              name: AppRoutes.medicalRecords,
              page: () => const MedicalRecordsScreen(),
              binding: BindingsBuilder(() {
                Get.put<MedicalRecordsScreenController>(
                  MedicalRecordsScreenController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.doctorChats,
              page: () => const DoctorChatsScreen(),
              binding: BindingsBuilder(() {
                Get.put<DoctorChatsScreenController>(
                  DoctorChatsScreenController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.doctorProfile,
              page: () => const DoctorProfileScreen(),
              binding: BindingsBuilder(() {
                Get.put<DoctorProfileController>(DoctorProfileController());
              }),
            ),
            GetPage(
              name: AppRoutes.editDoctorProfile,
              page: () => const EditDoctorProfileScreen(),
            ),
            GetPage(
              name: AppRoutes.workingHours,
              page: () => WorkingHoursPage(),
            ),
            GetPage(
              name: AppRoutes.notifications,
              page: () => const NotificationsScreen(),
              binding: BindingsBuilder(() {
                Get.put<NotificationsScreenController>(
                  NotificationsScreenController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.dentalImplantTimeline,
              page: () => const DentalImplantTimelineScreen(),
              binding: BindingsBuilder(() {
                Get.put<DentalImplantTimelineController>(
                  DentalImplantTimelineController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.receptionLogin,
              page: () => const ReceptionLoginScreen(),
            ),
            GetPage(
              name: AppRoutes.receptionHome,
              page: () => const ReceptionHomeScreen(),
            ),
            GetPage(
              name: AppRoutes.selectDoctor,
              page: () => const SelectDoctorScreen(),
              binding: BindingsBuilder(() {
                Get.put<SelectDoctorController>(SelectDoctorController());
              }),
            ),
            GetPage(
              name: AppRoutes.receptionProfile,
              page: () => const ReceptionProfileScreen(),
              binding: BindingsBuilder(() {
                Get.put<ReceptionProfileController>(
                  ReceptionProfileController(),
                );
              }),
            ),
            GetPage(
              name: AppRoutes.editReceptionProfile,
              page: () => const EditReceptionProfileScreen(),
            ),
            GetPage(
              name: AppRoutes.qrScanner,
              page: () => const QrScannerScreen(),
              binding: BindingsBuilder(() {
                Get.put<QrScannerController>(QrScannerController());
              }),
            ),
            GetPage(
              name: AppRoutes.editImplantStageDate,
              page: () => const EditImplantStageDateScreen(),
              binding: BindingsBuilder(() {
                Get.put<EditImplantStageDateController>(
                  EditImplantStageDateController(),
                );
              }),
            ),
          ],
          builder: (context, widget) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: widget!,
            );
          },
        );
      },
    );
  }
}
