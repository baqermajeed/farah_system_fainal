import 'dart:async';
import 'dart:ui';
import 'package:desktop_multi_window/desktop_multi_window.dart';
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
import 'package:frontend_desktop/views/call_center_login_screen.dart';
import 'package:frontend_desktop/views/doctor_home_screen.dart';
import 'package:frontend_desktop/views/add_patient_screen.dart';
import 'package:frontend_desktop/views/doctor_profile_screen.dart';
import 'package:frontend_desktop/views/edit_doctor_profile_screen.dart';
import 'package:frontend_desktop/views/reception_home_screen.dart';
import 'package:frontend_desktop/views/call_center_home_screen.dart';
import 'package:frontend_desktop/views/working_hours_page.dart';
import 'package:frontend_desktop/views/appointments_screen.dart';
import 'package:frontend_desktop/views/queue_display_screen.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/controllers/queue_controller.dart';
import 'package:frontend_desktop/controllers/presence_controller.dart';
import 'package:frontend_desktop/services/cache_service.dart';
import 'package:frontend_desktop/services/queue_announcement_service.dart';
import 'package:frontend_desktop/services/queue_window_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:camera/camera.dart';
import 'package:window_manager/window_manager.dart';

// متغير عام لتخزين الكاميرات المتاحة
List<CameraDescription>? availableCamerasList;

void main(List<String> args) async {
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ [PlatformError] $error\n$stack');
    return true; // prevent hard crash
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final windowController = await WindowController.fromCurrentEngine();
    final windowConfig =
        QueueWindowService.parseArguments(windowController.arguments);

    if (windowConfig['type'] == QueueWindowService.queueDisplayType) {
      await _bootstrapQueueDisplayWindow(windowConfig);
      return;
    }

    await _bootstrapMainApp();
  }, (error, stack) {
    debugPrint('❌ [ZoneError] $error\n$stack');
  });
}

Future<void> _bootstrapMainApp() async {
  availableCamerasList = null;

  await initializeDateFormatting('ar', null);
  await CacheService().init();

  try {
    final cacheService = CacheService();
    final totalCached = cacheService.totalCachedItems;
    if (totalCached > 500) {
      print(
        '⚠️ [Main] Large cache detected ($totalCached items), clearing old cache...',
      );
      await cacheService.clearAll();
      print('✅ [Main] Old cache cleared');
    }
  } catch (e) {
    print('⚠️ [Main] Error checking cache size: $e');
  }

  await Hive.openBox('metaData');
  await QueueAnnouncementService.instance.init();

  Get.put(PresenceController());
  Get.put(AuthController());
  Get.put(QueueController());

  runApp(const MyApp());
}

Future<void> _bootstrapQueueDisplayWindow(
  Map<String, dynamic> config,
) async {
  final width = _readDouble(config['width'], 1080);
  final height = _readDouble(config['height'], 1920);
  final x = _readDouble(config['x'], 0);
  final y = _readDouble(config['y'], 0);

  await initializeDateFormatting('ar', null);

  final queueController = Get.put(QueueController(remoteMode: true));
  await QueueWindowService.setupDisplayChannel(queueController.applyRemoteState);

  runApp(const QueueDisplayApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_configureDisplayWindow(x, y, width, height));
  });
}

Future<void> _configureDisplayWindow(
  double x,
  double y,
  double width,
  double height,
) async {
  try {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('شاشة الطابور - عيادة فرح');
    await windowManager.setPosition(Offset(x, y));
    await windowManager.setSize(Size(width, height));
    await windowManager.setFullScreen(true);
    await windowManager.show();
  } catch (e) {
    debugPrint('⚠️ [QueueDisplay] Window setup failed: $e');
  }
}

double _readDouble(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
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
              name: AppRoutes.callCenterLogin,
              page: () => const CallCenterLoginScreen(),
            ),
            GetPage(
              name: AppRoutes.receptionHome,
              page: () => const ReceptionHomeScreen(),
            ),
            GetPage(
              name: AppRoutes.callCenterHome,
              page: () => const CallCenterHomeScreen(),
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
