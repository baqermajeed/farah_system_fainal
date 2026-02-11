import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../core/constants/app_colors.dart';
import '../enums/patient_activity_filter_mode.dart';
import '../widgets/avatar_network.dart';
import '../widgets/patient_activity_filter_menu.dart';
import 'doctors/doctors_screen.dart';
import 'call_center/call_center_staff_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthController _auth = Get.find<AuthController>();
  late final DashboardController _dash;

  @override
  void initState() {
    super.initState();
    _dash = Get.put(DashboardController());
    // ignore: discarded_futures
    _dash.refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Obx(() {
          if (_dash.loading.value && _dash.stats.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final err = _dash.error.value;
          if (err != null && _dash.stats.value == null) {
            return _buildErrorState(err);
          }

          final s = _dash.stats.value;
          if (s == null) return const SizedBox.shrink();

          return RefreshIndicator(
            onRefresh: () => _dash.refreshStats(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
              _buildModernAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'نظرة عامة',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              // Horizontal Highlights (KPIs)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _HighlightCard(
                        title: 'مرضى اليوم',
                        value: s.today.newPatients.toString(),
                        icon: Icons.assignment_ind_rounded,
                        color1: const Color(0xFFEF5350), // Red-ish
                        color2: const Color(0xFFE57373),
                      ),
                      const SizedBox(width: 12),
                      _HighlightCard(
                        title: 'المرضى',
                        value: s.overview.totalPatients.toString(),
                        icon: Icons.people_alt_rounded,
                        color1: const Color(0xFF5B9FCC),
                        color2: const Color(0xFF7EC8E3),
                      ),
                      const SizedBox(width: 12),
                      _HighlightCard(
                        title: 'الأطباء',
                        value: s.overview.totalDoctors.toString(),
                        icon: Icons.medical_services_rounded,
                        color1: const Color(0xFF3498DB),
                        color2: const Color(0xFF5DADE2),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Obx(() {
                    final stats = _dash.patientActivityStats.value;
                    final active = stats?.active ?? 0;
                    final inactive = stats?.inactive ?? 0;
                    final rangeLabel = (() {
                      if (stats?.rangeFrom != null && stats?.rangeTo != null) {
                        return 'من ${stats!.rangeFrom} إلى ${stats.rangeTo}';
                      }
                      return '';
                    })();

                    return _BentoCard(
                      title: 'نشاط المرضى',
                      icon: Icons.insights_rounded,
                      accent: AppColors.secondary,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _BentoRow('مرضى نشطين', active,
                              color: AppColors.success),
                          _BentoRow('مرضى غير نشطين', inactive,
                              color: AppColors.error),
                          if (rangeLabel.isNotEmpty)
                            Text(
                              rangeLabel,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      trailing: PatientActivityFilterMenu(
                        mode: _dash.patientActivityMode.value,
                        onChanged: (mode) async {
                          if (mode == PatientActivityFilterMode.custom) {
                            await _showPatientActivityRangePicker(context);
                            return;
                          }
                          await _dash.setPatientActivityMode(mode);
                        },
                      ),
                    );
                  }),
                ),
              ),

              // Detailed Stats Grid (Bento Style)
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _BentoCard(
                      title: 'إحصائيات اليوم',
                      icon: Icons.today_rounded,
                      accent: AppColors.primary,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _BentoRow('مرضى جدد', s.today.newPatients),
                          _BentoRow('مواعيد', s.today.appointments),
                          _BentoRow('رسائل', s.today.chatMessages),
                        ],
                      ),
                    ),
                    _BentoCard(
                      title: 'المواعيد',
                      icon: Icons.schedule_rounded,
                      accent: AppColors.warning,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _BentoRow('Scheduled', s.appointmentsByStatus.scheduled,
                              color: AppColors.warning),
                          _BentoRow('Completed', s.appointmentsByStatus.completed,
                              color: AppColors.success),
                          _BentoRow('Canceled', s.appointmentsByStatus.canceled,
                              color: AppColors.error),
                        ],
                      ),
                    ),
                    _BentoCard(
                      title: 'هذا الشهر',
                      icon: Icons.date_range_rounded,
                      accent: AppColors.success,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  s.thisMonth.newPatients.toString(),
                                  style: GoogleFonts.cairo(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    height: 1,
                                  ),
                                ),
                              ),
                              Text(
                                'مريض جديد',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  s.thisMonth.appointments.toString(),
                                  style: GoogleFonts.cairo(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    height: 1,
                                  ),
                                ),
                              ),
                              Text(
                                'موعد',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _BentoCard(
                      title: 'النظام',
                      icon: Icons.dns_rounded,
                      accent: AppColors.secondary,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _BentoRow('غرف شات', s.chat.totalRooms),
                          _BentoRow('إشعارات', s.notifications.totalSent),
                          _BentoRow('أجهزة', s.notifications.activeDevices),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: Text(
                      'آخر تحديث: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                      style: GoogleFonts.cairo(color: AppColors.textHint, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        }),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      collapsedHeight: 180,
      toolbarHeight: 180,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000), // very subtle shadow
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: FlexibleSpaceBar(
          background: Stack(
            children: [
              // Decorative background shape
              Positioned(
                left: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Logo (top-left)
              const Positioned(
                top: 30,
                left: 30,
                child: Image(
                  image: AssetImage('assets/images/logo.png'),
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary.withValues(alpha: 0.08),
                  ),
                ),
              ),
              // User Info
              Positioned(
                bottom: 30,
                right: 24,
                left: 24,
                child: Row(
                  children: [
                    AvatarNetwork(
                      imageUrl: _auth.me.value?.imageUrl,
                      size: 64,
                      radius: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'مرحبًا د.مهند',
                            style: GoogleFonts.cairo(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'في لوحة تحكم عيادة فرح',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Doctors Button
                    IconButton(
                      tooltip: 'قائمة الأطباء',
                      onPressed: () => Get.to(() => const DoctorsScreen()),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medical_services_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Call Center Staff Button
                    IconButton(
                      tooltip: 'موظفو مركز الاتصالات',
                      onPressed: () =>
                          Get.to(() => const CallCenterStaffScreen()),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.headset_mic_rounded,
                            color: AppColors.secondary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Logout Button
                    IconButton(
                      tooltip: 'تسجيل الخروج',
                      onPressed: () => _auth.logout(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: AppColors.error, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _dash.refreshStats(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
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

    await _dash.setPatientActivityCustomRange(
      from: range.start,
      to: range.end,
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color1;
  final Color color2;

  const _HighlightCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color1,
    required this.color2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color1.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class _BentoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget content;
  final Widget? trailing;

  const _BentoCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.content,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          Flexible(fit: FlexFit.loose, child: content),
        ],
      ),
    );
  }
}

class _BentoRow extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;

  const _BentoRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value.toString(),
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

