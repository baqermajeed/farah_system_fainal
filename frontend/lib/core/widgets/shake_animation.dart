import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// اهتزاز خفيف عند فشل التحقق، يُعاد تشغيله كلما زاد [tick].
extension ShakeAnimation on Widget {
  Widget shakeOnTick(int tick) {
    if (tick == 0) return this;

    return animate(key: ValueKey(tick))
        .shake(hz: 4, duration: 500.ms, curve: Curves.easeInOut)
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.04, 1.04),
          duration: 120.ms,
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          begin: const Offset(1.04, 1.04),
          end: const Offset(0.98, 0.98),
          duration: 120.ms,
        )
        .then()
        .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          duration: 120.ms,
          curve: Curves.easeInOut,
        );
  }
}
