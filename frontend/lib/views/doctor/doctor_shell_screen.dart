import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/views/doctor/doctor_home_tab.dart';

class DoctorShellScreen extends StatelessWidget {
  const DoctorShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.doctorSurface,
      body: DoctorHomeTab(),
    );
  }
}
