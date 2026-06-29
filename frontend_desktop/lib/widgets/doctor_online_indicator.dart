import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/controllers/presence_controller.dart';

/// Small circle next to a doctor name: green = online, gray = offline.
class DoctorOnlineIndicator extends StatelessWidget {
  final String userId;
  final double? size;

  const DoctorOnlineIndicator({
    super.key,
    required this.userId,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final presence = Get.find<PresenceController>();
    final dotSize = size ?? 8.r;

    return Obx(() {
      final online = presence.isDoctorOnline(userId);
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: online ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
      );
    });
  }
}
