import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/call_center_staff_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/doctor_card.dart';
import 'create_call_center_staff_screen.dart';

class CallCenterStaffScreen extends StatefulWidget {
  const CallCenterStaffScreen({super.key});

  @override
  State<CallCenterStaffScreen> createState() => _CallCenterStaffScreenState();
}

class _CallCenterStaffScreenState extends State<CallCenterStaffScreen> {
  late final CallCenterStaffController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(CallCenterStaffController());
    // ignore: discarded_futures
    _c.loadStaff();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Obx(() {
          if (_c.loading.value && _c.staff.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final err = _c.error.value;
          if (err != null && _c.staff.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      'تعذر تحميل موظفي مركز الاتصالات',
                      style: GoogleFonts.cairo(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _c.loadStaff(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _c.loadStaff,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  collapsedHeight: 120,
                  toolbarHeight: 120,
                  backgroundColor: AppColors.background,
                  elevation: 0,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  leadingWidth: 140,
                  leading: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'إضافة موظف',
                          onPressed: () async {
                            final created = await Get.to<bool>(
                                () => const CreateCallCenterStaffScreen());
                            if (created == true) {
                              // ignore: discarded_futures
                              _c.loadStaff();
                            }
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: AppColors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding:
                        const EdgeInsets.only(right: 20, left: 70, bottom: 16),
                    title: Transform.translate(
                      offset: const Offset(0, 20),
                      child: Text(
                        'موظفو مركز الاتصالات',
                        style: GoogleFonts.cairo(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    centerTitle: false,
                  ),
                  actions: const [
                    Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: AppBackButton(),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final s = _c.staff[index];
                        return DoctorCard(
                          imageUrl: s.imageUrl,
                          name: s.name ?? 'موظف',
                          phone: s.phone ?? '',
                        );
                      },
                      childCount: _c.staff.length,
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

