import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/controllers/doctor_home_controller.dart';
import 'package:farah_sys_final/controllers/doctor_shell_controller.dart';
import 'package:farah_sys_final/views/doctor/doctor_home_tab.dart';
import 'package:farah_sys_final/views/doctor/doctor_stats_tab.dart';
import 'package:farah_sys_final/views/doctor/doctor_more_tab.dart';
import 'package:farah_sys_final/views/doctor/doctor_chats_tab.dart';

class DoctorShellScreen extends GetView<DoctorShellController> {
  const DoctorShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.doctorSurface,
      body: Obx(() {
        final index = controller.currentIndex.value;
        final loaded = controller.loadedTabs;
        return IndexedStack(
          index: index,
          children: [
            loaded.contains(0)
                ? const DoctorHomeTab()
                : const SizedBox.shrink(),
            loaded.contains(1)
                ? const DoctorChatsTab()
                : const SizedBox.shrink(),
            const SizedBox.shrink(),
            loaded.contains(3)
                ? const DoctorStatsTab()
                : const SizedBox.shrink(),
            loaded.contains(4)
                ? const DoctorMoreTab()
                : const SizedBox.shrink(),
          ],
        );
      }),
      extendBody: true,
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFab() {
    return Container(
      width: 58.w,
      height: 58.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.doctorHeroStart, AppColors.doctorHeroEnd],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: controller.onAddPatient,
          customBorder: const CircleBorder(),
          child: Icon(Icons.add_rounded, color: AppColors.white, size: 30.sp),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Obx(() {
      final current = controller.currentIndex.value;
      final home = Get.find<DoctorHomeController>();
      final unread = home.unreadCounts.values.fold<int>(
        0,
        (sum, count) => sum + count,
      );

      return Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: AppColors.doctorCardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: BottomAppBar(
            color: AppColors.white,
            elevation: 0,
            height: 72.h,
            padding: EdgeInsets.zero,
            notchMargin: 8.w,
            shape: const CircularNotchedRectangle(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'الرئيسية',
                  isActive: current == 0,
                  onTap: () => controller.selectTab(0),
                ),
                _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'المحادثات',
                  isActive: current == 1,
                  badge: unread > 0 ? unread : null,
                  onTap: () => controller.selectTab(1),
                ),
                SizedBox(width: 48.w),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'التقارير',
                  isActive: current == 3,
                  onTap: () => controller.selectTab(3),
                ),
                _NavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'المزيد',
                  isActive: current == 4,
                  onTap: () => controller.selectTab(4),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.doctorNavInactive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22.sp),
                if (badge != null)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 14.w,
                        minHeight: 14.w,
                      ),
                      child: Text(
                        badge! > 9 ? '9+' : '$badge',
                        style: AppFonts.lamaSans(
                          fontSize: 7.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 1.h),
            Text(
              label,
              style: AppFonts.lamaSans(
                fontSize: 9.sp,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
