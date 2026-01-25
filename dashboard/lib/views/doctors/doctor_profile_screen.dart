import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/doctor_profile_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../enums/patient_activity_filter_mode.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/avatar_network.dart';
import '../../widgets/patient_activity_filter_menu.dart';
import '../../widgets/section_header.dart';
import 'doctor_patients_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorProfileScreen(
      {super.key, required this.doctorId, required this.doctorName});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  late final DoctorProfileController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(DoctorProfileController(doctorId: widget.doctorId),
        tag: widget.doctorId);
    // ignore: discarded_futures
    _c.load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Obx(() {
          if (_c.loading.value && _c.profile.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final err = _c.error.value;
          if (err != null && _c.profile.value == null) {
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
                      'تعذر تحميل بيانات الطبيب',
                      style: GoogleFonts.cairo(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(err,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(color: AppColors.textSecondary)),
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

          final p = _c.profile.value;
          if (p == null) return const SizedBox.shrink();

          return RefreshIndicator(
            onRefresh: _c.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                expandedHeight: 220,
                collapsedHeight: 220,
                toolbarHeight: 220,
                pinned: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient Background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primaryLight.withValues(alpha: 0.3),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                      // Header (always above the image)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            textDirection: TextDirection.ltr,
                            children: const [
                              AppBackButton(),
                              Spacer(),
                            ],
                          ),
                        ),
                      ),
                      ),
                      // Doctor Info
                      Padding(
                        padding: const EdgeInsets.only(top: 78),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AvatarNetwork(
                                imageUrl: p.doctor.imageUrl,
                                size: 100,
                                radius: 30,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                p.doctor.name ?? widget.doctorName,
                                style: GoogleFonts.cairo(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                p.doctor.phone ?? '',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Manager Status Toggle
                    Obx(() {
                      final currentProfile = _c.profile.value;
                      if (currentProfile == null) return const SizedBox.shrink();
                      return Center(
                        child: _ManagerToggle(
                          doctorId: widget.doctorId,
                          isManager: currentProfile.doctor.isManager,
                          onChanged: (value) async {
                            await _c.setManagerStatus(value);
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'نظرة عامة',
                      subtitle: 'إحصائيات المرضى والمواعيد والرسائل',
                    ),
                    const SizedBox(height: 16),

                    // Bento Grid-like Layout
                    Row(
                      children: [
                        Expanded(
                          child: _BentoStatCard(
                            title: 'إجمالي المرضى',
                            value: p.counts.totalPatients.toString(),
                            icon: Icons.people_alt_rounded,
                            color: AppColors.primary,
                            onTap: () {
                              Get.to(
                                () => DoctorPatientsScreen(
                                  doctorId: widget.doctorId,
                                  doctorName: widget.doctorName,
                                ),
                              );
                            },
                            showArrow: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Obx(() {
                            final mode = _c.appointmentMode.value;
                            final value = switch (mode) {
                              AppointmentFilterMode.daily => p.appointments.today,
                              AppointmentFilterMode.monthly => p.appointments.thisMonth,
                              AppointmentFilterMode.custom => p.appointments.rangeCount,
                              AppointmentFilterMode.total => p.counts.totalAppointments,
                            };

                            return _BentoStatCard(
                              title: 'إجمالي المواعيد',
                              value: value.toString(),
                              icon: Icons.calendar_today_rounded,
                              color: AppColors.info,
                              trailing: _AppointmentFilterMenu(
                                mode: mode,
                                onChanged: (m) async {
                                  if (m == AppointmentFilterMode.custom) {
                                    await _showAppointmentsRangePicker(context);
                                    if (!mounted) return;
                                    _c.appointmentMode.value =
                                        AppointmentFilterMode.custom;
                                    return;
                                  }
                                  _c.appointmentMode.value = m;
                                },
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _BentoStatCard(
                      title: 'الرسائل',
                      value: (() {
                        final mode = _c.messageMode.value;
                        return switch (mode) {
                          MessageFilterMode.daily => p.messages.today,
                          MessageFilterMode.monthly => p.messages.thisMonth,
                          MessageFilterMode.custom => p.messages.rangeCount,
                          MessageFilterMode.total => p.messages.total,
                        }.toString();
                      })(),
                      icon: Icons.mark_chat_unread_rounded,
                      color: AppColors.success,
                      height: 100,
                      isHorizontal: true,
                      trailing: _MessageFilterMenu(
                        mode: _c.messageMode.value,
                        onChanged: (m) async {
                          if (m == MessageFilterMode.custom) {
                            await _showMessagesRangePicker(context);
                            if (!mounted) return;
                            _c.messageMode.value = MessageFilterMode.custom;
                            return;
                          }
                          _c.messageMode.value = m;
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    Obx(() {
                      final stats = _c.patientActivityStats.value;
                      final active = stats?.active ?? 0;
                      final inactive = stats?.inactive ?? 0;
                      final rangeLabel = (() {
                        if (stats?.rangeFrom != null && stats?.rangeTo != null) {
                          return 'من ${stats!.rangeFrom} إلى ${stats.rangeTo}';
                        }
                        return '';
                      })();

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'مرضى نشطين',
                                        style: GoogleFonts.cairo(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        active.toString(),
                                        style: GoogleFonts.cairo(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'مرضى غير نشطين',
                                        style: GoogleFonts.cairo(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        inactive.toString(),
                                        style: GoogleFonts.cairo(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PatientActivityFilterMenu(
                                  mode: _c.patientActivityMode.value,
                                  onChanged: (mode) async {
                                    if (mode == PatientActivityFilterMode.custom) {
                                      await _showPatientActivityRangePicker(context);
                                      return;
                                    }
                                    await _c.setPatientActivityMode(mode);
                                  },
                                ),
                              ],
                            ),
                            if (rangeLabel.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  rangeLabel,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height:16),
                    SectionHeader(
                      title: 'التحويلات',
                      subtitle: 'حركة تحويل المرضى لهذا الطبيب',
                      trailing: TextButton.icon(
                        onPressed: () => _showRangePicker(context),
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: const Text('تحديد فترة'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Transfer Stats
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _TransferRow(
                            label: 'تحويلات اليوم',
                            value: p.transfers.today.toString(),
                            icon: Icons.today_rounded,
                            color: AppColors.secondary,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          _TransferRow(
                            label: 'تحويلات الشهر',
                            value: p.transfers.thisMonth.toString(),
                            icon: Icons.calendar_view_month_rounded,
                            color: AppColors.info,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          _TransferRow(
                            label: 'ضمن الفترة المحددة',
                            value: p.transfers.rangeCount.toString(),
                            icon: Icons.date_range_rounded,
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _showRangePicker(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: now, end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range == null) return;
    if (!context.mounted) return;

    // date_to exclusive in backend usually, so add 1 day to end
    await _c.setRange(
      from: range.start,
      to: range.end.add(const Duration(days: 1)),
    );
  }

  Future<void> _showAppointmentsRangePicker(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: now, end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range == null) return;
    if (!context.mounted) return;

    await _c.setRange(
      from: range.start,
      to: range.end.add(const Duration(days: 1)),
    );
  }

  Future<void> _showMessagesRangePicker(BuildContext context) async {
    // Same range mechanism as transfers/appointments (shared backend date_from/date_to)
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: now, end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range == null) return;
    if (!context.mounted) return;

    await _c.setRange(
      from: range.start,
      to: range.end.add(const Duration(days: 1)),
    );
  }

  Future<void> _showPatientActivityRangePicker(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: now, end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range == null) return;
    if (!context.mounted) return;

    await _c.setPatientActivityCustomRange(
      from: range.start,
      to: range.end,
    );
  }
}

class _BentoStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? height;
  final bool isHorizontal;
  final VoidCallback? onTap;
  final bool showArrow;
  final Widget? trailing;

  const _BentoStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.height,
    this.isHorizontal = false,
    this.onTap,
    this.showArrow = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height ?? 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isHorizontal
            ? Row(
                children: [
                  _IconBox(icon: icon, color: color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.cairo(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          title,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _IconBox(icon: icon, color: color),
                      const Spacer(),
                      if (trailing != null) trailing!,
                      if (showArrow)
                        Icon(Icons.arrow_outward_rounded,
                            color: AppColors.textHint, size: 20),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.cairo(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _AppointmentFilterMenu extends StatelessWidget {
  final AppointmentFilterMode mode;
  final ValueChanged<AppointmentFilterMode> onChanged;

  const _AppointmentFilterMenu({required this.mode, required this.onChanged});

  String get _label {
    switch (mode) {
      case AppointmentFilterMode.daily:
        return 'يومي';
      case AppointmentFilterMode.monthly:
        return 'شهري';
      case AppointmentFilterMode.custom:
        return 'مخصص';
      case AppointmentFilterMode.total:
        return 'الكل';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppointmentFilterMode>(
      tooltip: 'فلترة المواعيد',
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AppointmentFilterMode.daily,
          child: Text('يومي'),
        ),
        PopupMenuItem(
          value: AppointmentFilterMode.monthly,
          child: Text('شهري'),
        ),
        PopupMenuItem(
          value: AppointmentFilterMode.custom,
          child: Text('فترة محددة'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: AppointmentFilterMode.total,
          child: Text('الكل'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 18, color: AppColors.info),
          ],
        ),
      ),
    );
  }
}

class _MessageFilterMenu extends StatelessWidget {
  final MessageFilterMode mode;
  final ValueChanged<MessageFilterMode> onChanged;

  const _MessageFilterMenu({required this.mode, required this.onChanged});

  String get _label {
    switch (mode) {
      case MessageFilterMode.daily:
        return 'يومي';
      case MessageFilterMode.monthly:
        return 'شهري';
      case MessageFilterMode.custom:
        return 'مخصص';
      case MessageFilterMode.total:
        return 'الكل';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MessageFilterMode>(
      tooltip: 'فلترة الرسائل',
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: MessageFilterMode.daily,
          child: Text('يومي'),
        ),
        PopupMenuItem(
          value: MessageFilterMode.monthly,
          child: Text('شهري'),
        ),
        PopupMenuItem(
          value: MessageFilterMode.custom,
          child: Text('فترة محددة'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: MessageFilterMode.total,
          child: Text('الكل'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 18, color: AppColors.success),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _TransferRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TransferRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ManagerToggle extends StatelessWidget {
  final String doctorId;
  final bool isManager;
  final ValueChanged<bool> onChanged;

  const _ManagerToggle({
    required this.doctorId,
    required this.isManager,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isManager
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isManager
              ? AppColors.primary
              : AppColors.textHint.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isManager ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
            size: 18,
            color: isManager ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            isManager ? 'طبيب مدير' : 'طبيب عادي',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isManager ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isManager,
            onChanged: (value) {
              // استدعاء callback فقط - الـ controller سيتولى عرض الرسائل والتحديث
              onChanged(value);
            },
            activeColor: AppColors.primary,
            inactiveThumbColor: AppColors.textHint,
            inactiveTrackColor: AppColors.textHint.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
