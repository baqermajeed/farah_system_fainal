import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF5B9FCC);
  static const Color primaryLight = Color(0xFFB8D9ED);
  static const Color secondary = Color(0xFF7EC8E3);

  static const Color background = Color(0xFFE8F4F8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textHint = Color(0xFFBDC3C7);

  static const Color cardBackground = Color(0xFFF8FCFD);
  static const Color divider = Color(0xFFECF0F1);

  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);

  // Onboarding Colors
  static const Color onboardingBackground = Color(0xFFF2FCFF); // very light blue
  static const Color onboardingDarkBlue = Color(0xFF3F6683); // rectangle behind illustration
  static const Color onboardingTitle = Color(0xFFF8B23C); // orange title
  static const Color onboardingButton = Color(0xFF4A88B8); // buttons and controls

  // Doctor dashboard — modern UI palette
  static const Color doctorSurface = Color(0xFFF8FAFC);
  static const Color doctorCard = Color(0xFFFFFFFF);
  static const Color doctorHeroStart = Color(0xFF4A90D9);
  static const Color doctorHeroEnd = Color(0xFF6BB5F0);
  static const Color doctorAccentGreen = Color(0xFF34C759);
  static const Color doctorAccentPurple = Color(0xFF8B5CF6);
  static const Color doctorAccentOrange = Color(0xFFFF9500);
  static const Color doctorNavInactive = Color(0xFF94A3B8);
  static const Color doctorLabel = Color(0xFF64748B);

  static List<BoxShadow> get doctorCardShadow => [
        BoxShadow(
          color: const Color(0xFF64748B).withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
}
