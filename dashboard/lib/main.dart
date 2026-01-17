import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'core/theme/app_theme.dart';
import 'controllers/auth_controller.dart';
import 'views/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(AuthController(), permanent: true);
  runApp(const FarahDashboardApp());
}

class FarahDashboardApp extends StatelessWidget {
  const FarahDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Farah Admin Dashboard',
          theme: AppTheme.light(),
          scrollBehavior: const _NoGlowNoBounceScrollBehavior(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthGate(),
        );
      },
    );
  }
}

class _NoGlowNoBounceScrollBehavior extends MaterialScrollBehavior {
  const _NoGlowNoBounceScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Removes glow/stretch overscroll indicator across platforms.
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Makes scroll "fixed" (no iOS bounce).
    return const ClampingScrollPhysics();
  }
}
