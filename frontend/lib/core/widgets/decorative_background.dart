import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/decorative_dot_grid.dart';
import 'package:farah_sys_final/core/widgets/sparkle_icon.dart';

enum AuthDecorScene { splash, onboarding, login }

/// Scaffold بخلفية زخرفية موحدة لصفحات السبلاش والـ onboarding وتسجيل الدخول.
class AuthDecoratedScaffold extends StatelessWidget {
  const AuthDecoratedScaffold({
    super.key,
    required this.body,
    this.scene = AuthDecorScene.login,
    this.useSafeArea = true,
  });

  final Widget body;
  final AuthDecorScene scene;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      body: DecorativeBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(child: _SceneDecorations(scene: scene)),
            useSafeArea ? SafeArea(child: body) : body,
          ],
        ),
      ),
    );
  }
}

/// أشكال عضوية + توهج ناعم خلف المحتوى.
class DecorativeBackground extends StatelessWidget {
  const DecorativeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.onboardingBackground),
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -70.h,
                right: -90.w,
                child: _Blob(size: 240.w, color: AppColors.blobTop),
              ),
              Positioned(
                top: 180.h,
                left: -110.w,
                child: _Blob(
                  size: 170.w,
                  color: AppColors.blobAccent.withValues(alpha: 0.55),
                ),
              ),
              Positioned(
                bottom: -50.h,
                left: -70.w,
                child: _Blob(size: 200.w, color: AppColors.blobBottom),
              ),
              Positioned(
                bottom: 120.h,
                right: -80.w,
                child: _Blob(
                  size: 150.w,
                  color: AppColors.blobAccent.withValues(alpha: 0.45),
                ),
              ),
              Positioned(
                top: 90.h,
                right: 36.w,
                child: _GlowOrb(
                  size: 90.w,
                  color: AppColors.glowOrb.withValues(alpha: 0.22),
                ),
              ),
              Positioned(
                bottom: 70.h,
                left: 28.w,
                child: _GlowOrb(
                  size: 70.w,
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
              ),
              Positioned(
                top: 260.h,
                right: 48.w,
                child: _OutlineRing(
                  size: 56.w,
                  color: AppColors.onboardingButton.withValues(alpha: 0.28),
                ),
              ),
              Positioned(
                bottom: 210.h,
                left: 42.w,
                child: _OutlineRing(
                  size: 38.w,
                  color: AppColors.sparkleGold.withValues(alpha: 0.35),
                ),
              ),
              Positioned(
                top: 40.h,
                left: 18.w,
                child: _GlowOrb(
                  size: 26.w,
                  color: AppColors.sparkleGold.withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                bottom: 40.h,
                right: 24.w,
                child: _GlowOrb(
                  size: 22.w,
                  color: AppColors.secondary.withValues(alpha: 0.28),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _SceneDecorations extends StatelessWidget {
  const _SceneDecorations({required this.scene});

  final AuthDecorScene scene;

  @override
  Widget build(BuildContext context) {
    switch (scene) {
      case AuthDecorScene.splash:
        return const Stack(
          fit: StackFit.expand,
          children: [
            DecorativeDotGrid(
              alignment: Alignment.topLeft,
              padding: EdgeInsets.only(top: 48, left: 28),
            ),
            DecorativeDotGrid(
              alignment: Alignment.bottomRight,
              rows: 3,
              columns: 4,
              padding: EdgeInsets.only(bottom: 56, right: 20),
            ),
            _SparkleAt(
              top: 120,
              left: 60,
              size: 14,
              delayMs: 200,
            ),
            _SparkleAt(
              top: 200,
              right: 50,
              size: 18,
              filled: false,
              delayMs: 400,
            ),
            _SparkleAt(
              bottom: 180,
              left: 40,
              size: 12,
              delayMs: 600,
            ),
            _SparkleAt(
              bottom: 220,
              right: 70,
              size: 16,
              color: AppColors.sparkleGold,
              delayMs: 300,
            ),
            _SparkleAt(
              top: 320,
              right: 28,
              size: 10,
              filled: false,
              color: AppColors.onboardingButton,
              delayMs: 500,
            ),
          ],
        );
      case AuthDecorScene.onboarding:
        return const Stack(
          fit: StackFit.expand,
          children: [
            DecorativeDotGrid(
              alignment: Alignment.topRight,
              rows: 3,
              columns: 5,
              padding: EdgeInsets.only(top: 72, right: 18),
            ),
            DecorativeDotGrid(
              alignment: Alignment.bottomLeft,
              rows: 3,
              columns: 4,
              padding: EdgeInsets.only(bottom: 88, left: 16),
            ),
            _SparkleAt(
              top: 40,
              left: 20,
              size: 14,
              delayMs: 300,
            ),
            _SparkleAt(
              top: 86,
              right: 22,
              size: 16,
              color: AppColors.sparkleGold,
              delayMs: 100,
            ),
            _SparkleAt(
              bottom: 100,
              right: 30,
              size: 12,
              filled: false,
              delayMs: 500,
            ),
            _SparkleAt(
              bottom: 160,
              left: 36,
              size: 11,
              color: AppColors.onboardingButton,
              delayMs: 450,
            ),
          ],
        );
      case AuthDecorScene.login:
        return const Stack(
          fit: StackFit.expand,
          children: [
            DecorativeDotGrid(
              alignment: Alignment.topRight,
              rows: 3,
              columns: 5,
              padding: EdgeInsets.only(top: 56, right: 24),
            ),
            DecorativeDotGrid(
              alignment: Alignment.centerLeft,
              rows: 4,
              columns: 3,
              padding: EdgeInsets.only(left: 16),
            ),
            _SparkleAt(
              top: 88,
              left: 28,
              size: 13,
              delayMs: 180,
            ),
            _SparkleAt(
              top: 150,
              right: 32,
              size: 16,
              filled: false,
              color: AppColors.sparkleGold,
              delayMs: 360,
            ),
            _SparkleAt(
              bottom: 140,
              right: 40,
              size: 12,
              delayMs: 520,
            ),
            _SparkleAt(
              bottom: 88,
              left: 48,
              size: 10,
              filled: false,
              color: AppColors.onboardingButton,
              delayMs: 280,
            ),
          ],
        );
    }
  }
}

class _SparkleAt extends StatelessWidget {
  const _SparkleAt({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    this.filled = true,
    this.color = AppColors.primary,
    required this.delayMs,
  });

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final bool filled;
  final Color color;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top?.h,
      bottom: bottom?.h,
      left: left?.w,
      right: right?.w,
      child: SparkleIcon(
        size: size.w,
        filled: filled,
        color: color,
        delay: Duration(milliseconds: delayMs),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size * 0.6),
            topRight: Radius.circular(size * 0.3),
            bottomLeft: Radius.circular(size * 0.4),
            bottomRight: Radius.circular(size * 0.7),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1.08, 1.08),
          duration: 2400.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _OutlineRing extends StatelessWidget {
  const _OutlineRing({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1.06, 1.06),
          duration: 2800.ms,
          curve: Curves.easeInOut,
        )
        .fade(begin: 0.55, end: 1, duration: 2800.ms);
  }
}
