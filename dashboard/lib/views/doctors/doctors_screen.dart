import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/doctors_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/doctor_card.dart';
import 'create_doctor_screen.dart';
import 'doctor_profile_screen.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  late final DoctorsController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(DoctorsController());
    // ignore: discarded_futures
    _c.loadDoctors();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Obx(() {
          if (_c.loading.value && _c.doctors.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final err = _c.error.value;
          if (err != null && _c.doctors.isEmpty) {
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
                      'تعذر تحميل الأطباء',
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
                      onPressed: () => _c.loadDoctors(),
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
            onRefresh: _c.loadDoctors,
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
                        tooltip: 'إضافة طبيب',
                        onPressed: () async {
                          final created = await Get.to<bool>(
                              () => const CreateDoctorScreen());
                          if (created == true) {
                            // ignore: discarded_futures
                            _c.loadDoctors();
                          }
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
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
                      const EdgeInsets.only(right: 20, left: 70, bottom: 16,),
                  title: Transform.translate(
                    offset: const Offset(0, 20),
                    child: Text(
                      'قائمة الأطباء',
                      style: GoogleFonts.cairo(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  centerTitle: false,
                ),
                actions: [
                  const Padding(
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
                    childAspectRatio: 0.85, // جعل الكارت أقصر قليلاً (أصغر)
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final d = _c.doctors[index];
                      return DoctorCard(
                        imageUrl: d.imageUrl,
                        name: d.name ?? 'طبيب',
                        phone: d.phone ?? '',
                        onTap: () => Get.to(
                          () => DoctorProfileScreen(
                            doctorId: d.doctorId,
                            doctorName: d.name ?? 'طبيب',
                          ),
                        ),
                      );
                    },
                    childCount: _c.doctors.length,
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
