import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

/// Standard back button for doctor account screens.
class DoctorBackButton extends StatelessWidget {
  const DoctorBackButton({
    super.key,
    this.onTap,
    this.size = 50,
  });

  static const String assetPath = 'assets/icon/Frame 2609219.png';

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return BackButtonWidget(
      assetPath: assetPath,
      size: size,
      onTap: onTap,
    );
  }
}
