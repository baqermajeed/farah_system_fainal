import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  /// Size of the tappable button area (width/height).
  final double boxSize;

  const AppBackButton({
    super.key,
    this.onTap,
    this.boxSize = 50,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => Get.back(),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: boxSize,
        height: boxSize,
        child: Image.asset(
          'assets/images/arrow-square-up.png',
          width: boxSize,
          height: boxSize,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}


