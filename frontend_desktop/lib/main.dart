import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';
import 'package:frontend_desktop/core/routes/app_routes.dart';
import 'package:frontend_desktop/views/splash_screen.dart';
import 'package:frontend_desktop/views/user_selection_screen.dart';
import 'package:frontend_desktop/views/doctor_login_screen.dart';
import 'package:frontend_desktop/views/reception_login_screen.dart';
import 'package:frontend_desktop/views/doctor_home_screen.dart';
import 'package:frontend_desktop/views/add_patient_screen.dart';
import 'package:frontend_desktop/views/doctor_profile_screen.dart';
import 'package:frontend_desktop/views/edit_doctor_profile_screen.dart';
import 'package:frontend_desktop/views/reception_home_screen.dart';
import 'package:frontend_desktop/views/working_hours_page.dart';
import 'package:frontend_desktop/views/appointments_screen.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Arabic locale for DateFormat
  await initializeDateFormatting('ar', null);

  // Initialize Hive for local cache
  await Hive.initFlutter();
  await Hive.openBox('patients');
  await Hive.openBox('appointments');
  await Hive.openBox('medicalRecords');
  await Hive.openBox('gallery');

  // Initialize AuthController to load persisted session
  Get.put(AuthController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1366, 768), // Laptop size - أكبر قليلاً
      minTextAdapt: true,
      splitScreenMode: false,
      builder: (context, child) {
        return GetMaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: AppColors.background,
            // Global font: Cairo (Google Fonts)
            fontFamily: GoogleFonts.cairo().fontFamily,
            textTheme: GoogleFonts.cairoTextTheme(),
            primaryTextTheme: GoogleFonts.cairoTextTheme(),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              secondary: AppColors.secondary,
            ),
            useMaterial3: true,
            // Input decoration theme
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: AppColors.error, width: 2),
              ),
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14.sp),
            ),
          ),
          // Routes
          initialRoute: AppRoutes.splash,
          getPages: [
            GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
            GetPage(
              name: AppRoutes.userSelection,
              page: () => const UserSelectionScreen(),
            ),
            GetPage(
              name: AppRoutes.doctorLogin,
              page: () => const DoctorLoginScreen(),
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
              name: AppRoutes.doctorHome,
              page: () => const DoctorHomeScreen(),
            ),
            GetPage(
              name: AppRoutes.addPatient,
              page: () => const AddPatientScreen(),
            ),
            GetPage(
              name: AppRoutes.doctorProfile,
              page: () => const DoctorProfileScreen(),
            ),
            GetPage(
              name: AppRoutes.workingHours,
              page: () => WorkingHoursPage(),
            ),
            GetPage(
              name: AppRoutes.editDoctorProfile,
              page: () => const EditDoctorProfileScreen(),
            ),
            GetPage(
              name: AppRoutes.appointments,
              page: () => const AppointmentsScreen(),
            ),
          ],
        );
      },
    );
  }
}
