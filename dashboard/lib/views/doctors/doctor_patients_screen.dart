import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/doctor_patients_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/patient_card.dart';

class DoctorPatientsScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorPatientsScreen(
      {super.key, required this.doctorId, required this.doctorName});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  late final DoctorPatientsController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(DoctorPatientsController(doctorId: widget.doctorId),
        tag: widget.doctorId);
    // ignore: discarded_futures
    _c.load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_c.from.value != null && _c.to.value != null)
          ? DateTimeRange(
              start: _c.from.value!,
              end: _c.to.value!.subtract(const Duration(days: 1)),
            )
          : null,
    );
    if (range == null) return;
    if (!mounted) return;
    _c.from.value = DateTime(range.start.year, range.start.month, range.start.day);
    // date_to exclusive for backend
    _c.to.value = DateTime(range.end.year, range.end.month, range.end.day)
        .add(const Duration(days: 1));
    // ignore: discarded_futures
    _c.load();
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDate: _c.from.value ?? now,
    );
    if (d != null) {
      _c.from.value = DateTime(d.year, d.month, d.day);
      // ignore: discarded_futures
      _c.load();
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDate: _c.to.value ?? now,
    );
    if (d != null) {
      _c.to.value = DateTime(d.year, d.month, d.day).add(const Duration(days: 1));
      // ignore: discarded_futures
      _c.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Obx(() {
          if (_c.loading.value && _c.patients.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final err = _c.error.value;
          if (err != null && _c.patients.isEmpty) {
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
                      'تعذر تحميل المرضى',
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
                      onPressed: () => _c.load(),
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
            onRefresh: () => _c.load(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                expandedHeight: 120,
                collapsedHeight: 120,
                toolbarHeight: 120,
                pinned: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsets.only(right: 20, left: 60, bottom: 16),
                  title: Text(
                    'مرضى ${widget.doctorName}',
                    style: GoogleFonts.cairo(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  centerTitle: false,
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: AppBackButton(),
                  ),
                ],
              ),
              // Filter Header
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.divider.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فلترة العرض',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Obx(() {
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChip(
                              label: 'يومي',
                              selected:
                                  _c.mode.value == PatientsFilterMode.daily,
                              onSelected: (_) {
                                _c.mode.value = PatientsFilterMode.daily;
                                // ignore: discarded_futures
                                _c.load();
                              },
                            ),
                            _FilterChip(
                              label: 'شهري',
                              selected:
                                  _c.mode.value == PatientsFilterMode.monthly,
                              onSelected: (_) {
                                _c.mode.value = PatientsFilterMode.monthly;
                                // ignore: discarded_futures
                                _c.load();
                              },
                            ),
                            _FilterChip(
                              label: 'مخصص',
                              selected:
                                  _c.mode.value == PatientsFilterMode.custom,
                              onSelected: (_) {
                                _c.mode.value = PatientsFilterMode.custom;
                                // Custom must select a range first
                                // ignore: discarded_futures
                                _pickRange();
                              },
                            ),
                          ],
                        );
                      }),
                      Obx(() {
                        if (_c.mode.value != PatientsFilterMode.custom) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _DateButton(
                                label: _c.from.value == null
                                    ? 'من'
                                    : '${_c.from.value!.year}-${_c.from.value!.month}-${_c.from.value!.day}',
                                onTap: _pickFrom,
                              ),
                              _DateButton(
                                label: _c.to.value == null
                                    ? 'إلى'
                                    : (() {
                                        final s = _c.to.value!
                                            .subtract(const Duration(days: 1));
                                        return '${s.year}-${s.month}-${s.day}';
                                      })(),
                                onTap: _pickTo,
                              ),
                              IconButton(
                                onPressed: () {
                                  _c.from.value = null;
                                  _c.to.value = null;
                                  // ignore: discarded_futures
                                  _c.load();
                                },
                                icon: const Icon(Icons.clear_rounded,
                                    color: AppColors.error),
                                tooltip: 'مسح',
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Count Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'قائمة المرضى',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_c.patients.length} مريض',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Patients List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final p = _c.patients[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PatientCard(
                          imageUrl: p.imageUrl,
                          name: p.name ?? 'مريض',
                          phone: p.phone,
                          treatmentType: p.treatmentType,
                          onTap: () {},
                        ),
                      );
                    },
                    childCount: _c.patients.length,
                  ),
                ),
              ),

              // Empty State
              if (_c.patients.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Obx(() {
                      final isCustom = _c.mode.value == PatientsFilterMode.custom;
                      final needsRange = isCustom && (_c.from.value == null || _c.to.value == null);
                      return Column(
                        children: [
                          Icon(
                            needsRange ? Icons.date_range_rounded : Icons.people_outline_rounded,
                            size: 64,
                            color: AppColors.textHint.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            needsRange
                                ? 'اختر فترة (من / إلى) لعرض المرضى'
                                : 'لا يوجد مرضى في هذه الفترة',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    }),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? AppColors.white : AppColors.textPrimary,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
