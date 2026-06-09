import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:frontend_desktop/controllers/queue_controller.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';
import 'package:frontend_desktop/models/queue_entry_model.dart';
import 'package:frontend_desktop/services/queue_window_service.dart';
import 'package:window_manager/window_manager.dart';

Future<void> openQueueDisplayScreen(BuildContext context) async {
  if (Platform.isWindows) {
    await QueueWindowService.openOrFocusDisplayWindow();
    if (Get.isRegistered<QueueController>()) {
      final controller = Get.find<QueueController>();
      await QueueWindowService.notifyDisplayUpdateWithRetry(
        controller.toSyncPayload(),
      );
    }
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const QueueDisplayScreen(),
    ),
  );
}

class QueueDisplayApp extends StatelessWidget {
  const QueueDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.cairo().fontFamily,
        useMaterial3: true,
      ),
      home: const QueueDisplayScreen(standalone: true),
    );
  }
}

class QueueDisplayScreen extends StatefulWidget {
  final bool standalone;

  const QueueDisplayScreen({super.key, this.standalone = false});

  @override
  State<QueueDisplayScreen> createState() => _QueueDisplayScreenState();
}

class _QueueDisplayScreenState extends State<QueueDisplayScreen> {
  Timer? _clockTimer;
  late String _currentTime;

  static const _dailyTips = [
    'احرص على تنظيف أسنانك مرتين يومياً للحفاظ على صحة فمك وأسنانك',
    'قم بزيارة طبيب الأسنان كل ستة أشهر على الأقل',
    'قلل من المشروبات السكرية للحفاظ على أسنانك',
    'استخدم خيط الأسنان يومياً لتنظيف ما بين الأسنان',
  ];

  @override
  void initState() {
    super.initState();
    _currentTime = _formatNow();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _currentTime = _formatNow());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _formatNow() {
    return DateFormat('hh:mm a', 'en').format(DateTime.now());
  }

  String get _dailyTip {
    final index = DateTime.now().day % _dailyTips.length;
    return _dailyTips[index];
  }

  Future<void> _closeDisplay() async {
    if (widget.standalone) {
      await windowManager.close();
      return;
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _closeDisplay();
        },
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final isCompact = constraints.maxHeight < 860;
            final designSize = isLandscape
                ? Size(constraints.maxWidth, constraints.maxHeight)
                : const Size(1080, 1920);

            return ScreenUtilInit(
              designSize: designSize,
              minTextAdapt: true,
              builder: (context, child) {
                return Scaffold(
                  backgroundColor: const Color(0xFFF4FBFD),
                  body: GetBuilder<QueueController>(
                    builder: (controller) {
                      final current = controller.currentEntry;
                      final next = controller.nextEntry;
                      final waiting = controller.displayWaitingList;

                      return Stack(
                        children: [
                          SafeArea(
                            child: Column(
                              children: [
                                _buildHeader(compact: isCompact),
                                Expanded(
                                  child: isLandscape
                                      ? _buildLandscapeBody(
                                          current: current,
                                          next: next,
                                          waiting: waiting,
                                        )
                                      : _buildPortraitBody(
                                          current: current,
                                          next: next,
                                          waiting: waiting,
                                          compact: isCompact,
                                        ),
                                ),
                                if (!isCompact) _buildDailyTip(),
                                _buildFooter(compact: isCompact),
                              ],
                            ),
                          ),
                          if (!widget.standalone)
                            Positioned(
                              top: 8.h,
                              left: 8.w,
                              child: IconButton(
                                tooltip: 'إغلاق شاشة العرض (Esc)',
                                onPressed: _closeDisplay,
                              icon: Icon(
                                Icons.close,
                                color: Colors.black.withValues(alpha: 0.25),
                                size: 22.sp,
                              ),
                            ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortraitBody({
    required QueueEntry? current,
    required QueueEntry? next,
    required List<QueueEntry> waiting,
    required bool compact,
  }) {
    return Column(
      children: [
        Expanded(
          flex: compact ? 4 : 5,
          child: _buildNowServing(current, compact: compact),
        ),
        Expanded(
          flex: compact ? 2 : 2,
          child: _buildNextUp(next, compact: compact),
        ),
        Expanded(
          flex: compact ? 2 : 3,
          child: _buildWaitingList(waiting, compact: compact),
        ),
      ],
    );
  }

  Widget _buildLandscapeBody({
    required QueueEntry? current,
    required QueueEntry? next,
    required List<QueueEntry> waiting,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _buildNowServing(current, compact: true),
          ),
          SizedBox(width: 16.w),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildNextUp(next, compact: true),
                ),
                SizedBox(height: 12.h),
                Expanded(
                  flex: 3,
                  child: _buildWaitingList(waiting, compact: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        40.w,
        compact ? 12.h : 24.h,
        40.w,
        compact ? 8.h : 16.h,
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/tooth_logo.png',
            width: compact ? 52.w : 72.w,
            height: compact ? 52.w : 72.w,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.medical_services_outlined,
              size: compact ? 40.sp : 56.sp,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.appName} لطب الأسنان',
                  textDirection: ui.TextDirection.rtl,
                  style: GoogleFonts.cairo(
                    fontSize: compact ? 26.sp : 34.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F4E67),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'نعتني بابتسامتك',
                  textDirection: ui.TextDirection.rtl,
                  style: GoogleFonts.cairo(
                    fontSize: compact ? 16.sp : 22.sp,
                    color: const Color(0xFF5F7F96),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowServing(QueueEntry? current, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 20.w : 36.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الآن',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: compact ? 28.sp : 42.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F4E67),
            ),
          ),
          SizedBox(height: compact ? 8.h : 16.h),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F9DBF), Color(0xFF3D86A8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(compact ? 24.r : 36.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: current == null
                  ? _buildEmptyCurrent(compact: compact)
                  : _buildCurrentContent(current, compact: compact),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCurrent({required bool compact}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: compact ? 48.sp : 72.sp,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          SizedBox(height: compact ? 8.h : 16.h),
          Text(
            'بانتظار الاستدعاء',
            style: GoogleFonts.cairo(
              fontSize: compact ? 24.sp : 34.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentContent(QueueEntry current, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16.w : 28.w,
        vertical: compact ? 12.h : 24.h,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${current.number}',
              style: GoogleFonts.cairo(
                fontSize: compact ? 90.sp : 150.sp,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: compact ? 10.h : 18.h),
          Text(
            current.name,
            textAlign: TextAlign.center,
            textDirection: ui.TextDirection.rtl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: compact ? 28.sp : 46.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (!compact) ...[
            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(40.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 28.sp,
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'يرجى التوجه إلى الاستقبال',
                    textDirection: ui.TextDirection.rtl,
                    style: GoogleFonts.cairo(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextUp(QueueEntry? next, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 20.w : 36.w,
        compact ? 6.h : 12.h,
        compact ? 20.w : 36.w,
        compact ? 6.h : 12.h,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16.w : 24.w,
          vertical: compact ? 12.h : 18.h,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 18.r : 24.r),
          border: Border.all(color: const Color(0xFFD7E8F2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x143F6683),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (!compact)
              Image.asset(
                'assets/images/clean_teeth.png',
                width: compact ? 56.w : 90.w,
                height: compact ? 56.w : 90.w,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.event_seat_outlined,
                  size: compact ? 40.sp : 64.sp,
                  color: AppColors.primary,
                ),
              ),
            if (!compact) SizedBox(width: 20.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'القادم',
                    style: GoogleFonts.cairo(
                      fontSize: compact ? 20.sp : 28.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F4E67),
                    ),
                  ),
                  SizedBox(height: compact ? 4.h : 8.h),
                  if (next == null)
                    Text(
                      '—',
                      style: GoogleFonts.cairo(
                        fontSize: compact ? 24.sp : 34.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHint,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          '${next.number}',
                          style: GoogleFonts.cairo(
                            fontSize: compact ? 28.sp : 42.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Text(
                            next.name,
                            textDirection: ui.TextDirection.rtl,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: compact ? 22.sp : 30.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F4E67),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingList(List<QueueEntry> waiting, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 20.w : 36.w,
        compact ? 4.h : 8.h,
        compact ? 20.w : 36.w,
        compact ? 4.h : 8.h,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 18.r : 24.r),
          border: Border.all(color: const Color(0xFFD7E8F2)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16.w : 24.w,
                compact ? 10.h : 18.h,
                compact ? 16.w : 24.w,
                compact ? 8.h : 12.h,
              ),
              child: Row(
                children: [
                  if (!compact)
                    Image.asset(
                      'assets/images/tooth-whitening.png',
                      width: 56.w,
                      height: 56.w,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.people_outline,
                        size: 40.sp,
                        color: AppColors.primary,
                      ),
                    ),
                  if (!compact) SizedBox(width: 12.w),
                  Text(
                    'قائمة الانتظار',
                    style: GoogleFonts.cairo(
                      fontSize: compact ? 22.sp : 30.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F4E67),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[200]),
            Expanded(
              child: waiting.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد مرضى بالانتظار',
                        style: GoogleFonts.cairo(
                          fontSize: compact ? 18.sp : 24.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: compact ? 4.h : 8.h),
                      itemCount: waiting.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey[100],
                        indent: 24.w,
                        endIndent: 24.w,
                      ),
                      itemBuilder: (context, index) {
                        final entry = waiting[index];
                        final isEven = index.isEven;
                        return Container(
                          color: isEven
                              ? const Color(0xFFF8FCFD)
                              : Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 16.w : 28.w,
                            vertical: compact ? 8.h : 14.h,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: compact ? 48.w : 72.w,
                                child: Text(
                                  '${entry.number}',
                                  style: GoogleFonts.cairo(
                                    fontSize: compact ? 22.sp : 30.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.name,
                                  textAlign: TextAlign.right,
                                  textDirection: ui.TextDirection.rtl,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: compact ? 20.sp : 26.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1F4E67),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTip() {
    return Padding(
      padding: EdgeInsets.fromLTRB(36.w, 8.h, 36.w, 8.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FB),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.primary,
                size: 28.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نصيحة اليوم',
                    style: GoogleFonts.cairo(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F4E67),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _dailyTip,
                    textDirection: ui.TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 18.sp,
                      color: const Color(0xFF4F6D82),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 36.w,
        vertical: compact ? 10.h : 18.h,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1F4E67),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'شكراً لاختياركم عيادتنا، نتمنى لكم يوماً صحياً وسعيداً',
              textDirection: ui.TextDirection.rtl,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: compact ? 14.sp : 20.sp,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Icon(Icons.access_time_rounded, color: Colors.white, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            _currentTime,
            style: GoogleFonts.cairo(
              fontSize: compact ? 18.sp : 24.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
