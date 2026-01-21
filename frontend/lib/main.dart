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
import 'package:farah_sys_final/services/fcm_service.dart';
import 'package:farah_sys_final/services/api_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase 1
  await Firebase.initializeApp();

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

  // Initialize Services
  Get.put(ApiService());

  // Initialize Controllers
  Get.put(AuthController());
  Get.put(PatientController());
  Get.put(AppointmentController());
  Get.put(ChatController());

  // Initialize FCM Service
  Get.put(FcmService());

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
              page: () {
                final args = Get.arguments as Map<String, dynamic>?;
                return OtpVerificationScreen(
                  phoneNumber: args?['phoneNumber'] ?? '',
                );
              },
            ),
            GetPage(
              name: AppRoutes.patientRegistration,
              page: () {
                final args = Get.arguments as Map<String, dynamic>?;
                return PatientRegistrationScreen(
                  phoneNumber: args?['phoneNumber'] ?? '',
                );
              },
            ),
            GetPage(
              name: AppRoutes.addPatient,
              page: () => const AddPatientScreen(),
            ),
            GetPage(
              name: AppRoutes.patientHome,
              page: () => const PatientHomeScreen(),
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
            ),
            GetPage(
              name: AppRoutes.patientDetails,
              page: () => const PatientDetailsScreen(),
            ),
            GetPage(
              name: AppRoutes.appointments,
              page: () => const AppointmentsScreen(),
            ),
            GetPage(
              name: AppRoutes.patientAppointments,
              page: () => const PatientAppointmentsScreen(),
            ),
            GetPage(
              name: AppRoutes.appointmentsByDate,
              page: () => const AppointmentsByDateScreen(),
            ),
            GetPage(name: AppRoutes.chat, page: () => const ChatScreen()),
            GetPage(
              name: AppRoutes.patientProfile,
              page: () => const PatientProfileScreen(),
            ),
            GetPage(
              name: AppRoutes.editPatientProfile,
              page: () => const EditPatientProfileScreen(),
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
            ),
            GetPage(
              name: AppRoutes.doctorChats,
              page: () => const DoctorChatsScreen(),
            ),
            GetPage(
              name: AppRoutes.doctorProfile,
              page: () => const DoctorProfileScreen(),
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
            ),
            GetPage(
              name: AppRoutes.dentalImplantTimeline,
              page: () => const DentalImplantTimelineScreen(),
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
              page: () {
                final args = Get.arguments as Map<String, dynamic>?;
                return SelectDoctorScreen(
                  patientId: args?['patientId'] ?? '',
                  currentDoctorIds:
                      (args?['currentDoctorIds'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [],
                );
              },
            ),
            GetPage(
              name: AppRoutes.receptionProfile,
              page: () => const ReceptionProfileScreen(),
            ),
            GetPage(
              name: AppRoutes.editReceptionProfile,
              page: () => const EditReceptionProfileScreen(),
            ),
            GetPage(
              name: AppRoutes.qrScanner,
              page: () => const QrScannerScreen(),
            ),
            GetPage(
              name: AppRoutes.editImplantStageDate,
              page: () => const EditImplantStageDateScreen(),
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
