import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/doctor_transfers_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/section_header.dart';

class DoctorTransfersScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorTransfersScreen(
      {super.key, required this.doctorId, required this.doctorName});

  @override
  State<DoctorTransfersScreen> createState() => _DoctorTransfersScreenState();
}

class _DoctorTransfersScreenState extends State<DoctorTransfersScreen> {
  late final DoctorTransfersController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(DoctorTransfersController(doctorId: widget.doctorId),
        tag: widget.doctorId);
    // ignore: discarded_futures
    _c.refresh();
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
      _c.refresh();
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
      _c.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('تحويلات: ${widget.doctorName}'),
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: AppBackButton(),
          ),
        ],
        ),
        body: Obx(() {
          if (_c.loading.value && _c.transfers.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final err = _c.error.value;
          if (err != null && _c.transfers.value == null) {
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
                      'تعذر تحميل التحويلات',
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
                      onPressed: () => _c.refresh(),
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

          final t = _c.transfers.value;
          if (t == null) return const SizedBox.shrink();

          return RefreshIndicator(
            onRefresh: _c.refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SectionHeader(
                  title: 'إحصائيات التحويل',
                  subtitle: 'الإجمالي: ${t.totalTransfers} تحويل',
                ),
                const SizedBox(height: 16),

                // Filters
                Container(
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
                        'خيارات العرض',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        runSpacing: 10,
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _c.group.value,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.primary),
                                style: GoogleFonts.cairo(
                                    color: AppColors.textPrimary, fontSize: 13),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'day', child: Text('تجميع يومي')),
                                  DropdownMenuItem(
                                      value: 'month', child: Text('تجميع شهري')),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  _c.group.value = v;
                                  // ignore: discarded_futures
                                  _c.refresh();
                                },
                              ),
                            ),
                          ),
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
                              _c.refresh();
                            },
                            icon: const Icon(Icons.clear_rounded,
                                color: AppColors.error),
                            tooltip: 'مسح',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Results
                if (t.byPeriod.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.bar_chart_rounded,
                              size: 48,
                              color: AppColors.textHint.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد بيانات للفترة المحددة',
                            style: GoogleFonts.cairo(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...t.byPeriod.map((p) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.divider.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_today_rounded,
                                size: 18, color: AppColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              p.period,
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${p.count} مريض',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        }),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded,
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
