import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend_desktop/controllers/queue_controller.dart';
import 'package:frontend_desktop/models/queue_entry_model.dart';
import 'package:frontend_desktop/services/queue_window_service.dart';
import 'package:window_manager/window_manager.dart';

Future<void> openQueueDisplayScreen(BuildContext context) async {
  if (Platform.isWindows) {
    try {
      await QueueWindowService.openOrFocusDisplayWindow();
      if (Get.isRegistered<QueueController>()) {
        final controller = Get.find<QueueController>();
        await QueueWindowService.notifyDisplayUpdateWithRetry(
          controller.toSyncPayload(),
        );
      }
    } catch (e, st) {
      debugPrint('❌ [QueueDisplay] Failed to open display window: $e\n$st');
      rethrow;
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
  static const _bgTop = Color(0xFFE4EEF4);
  static const _bgBottom = Color(0xFFD5E4ED);
  static const _blob = Color(0xFFC5D6E3);
  static const _titleBlue = Color(0xFF2F6F95);
  static const _subBlue = Color(0xFF6FA3C0);
  static const _nowTop = Color(0xFF5BA9CB);
  static const _nowBottom = Color(0xFF2E5F7C);
  static const _lineBlue = Color(0xFF8BBAD3);
  static const _accentYellow = Color(0xFFF0C93B);

  static const _designSize = Size(1080, 1920);

  Future<void> _closeDisplay() async {
    if (widget.standalone) {
      await windowManager.close();
      return;
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildDisplayBody(QueueController controller) {
    final current = controller.displayCurrentEntry;
    final next = controller.displayNextEntry;
    final waiting = controller.displayWaitingList;

    return Stack(
      children: [
        const Positioned.fill(child: _QueueBackdrop()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 48.w),
          // تخطيط مرن داخل مساحة التصميم 1080×1920 — يمنع القص/التراكب
          // عند اختلاف DPI أو مقاس النافذة المنطقي بين الأجهزة.
          child: Column(
            children: [
              SizedBox(height: 8.h),
              _buildHeader(),
              SizedBox(height: 12.h),
              Expanded(flex: 551, child: _buildNowServing(current)),
              SizedBox(height: 14.h),
              Expanded(flex: 280, child: _buildNextUp(next)),
              SizedBox(height: 14.h),
              Expanded(flex: 577, child: _buildWaitingList(waiting)),
              SizedBox(height: 10.h),
              _buildFooter(),
              SizedBox(height: 14.h),
            ],
          ),
        ),
        if (!widget.standalone)
          Positioned(
            top: 12.h,
            left: 12.w,
            child: IconButton(
              tooltip: 'إغلاق شاشة العرض (Esc)',
              onPressed: _closeDisplay,
              icon: Icon(
                Icons.close,
                color: Colors.black.withValues(alpha: 0.22),
                size: 24.sp,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _closeDisplay,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth;
            final viewportHeight = constraints.maxHeight;

            // Canvas ثابت 1080×1920 (نسبة 9:16 = شاشة Hikvision العمودية).
            // FittedBox وحده يكبّر/يصغّر للنافذة.
            // مهم: ScreenUtilInit افتراضياً يقرأ حجم الشاشة الحقيقي (fromView)،
            // فيصير 707.w أكبر من عرض الـ canvas على شاشات 2K/4K وكلا
            // الكونتينرين (707 و 953) يفيضان لنفس العرض الظاهري.
            // enableScale* = false ⇒ .w/.h/.sp = قيم التصميم 1:1 داخل الـ canvas.
            return ColoredBox(
              color: _bgBottom,
              child: SizedBox(
                width: viewportWidth,
                height: viewportHeight,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _designSize.width,
                    height: _designSize.height,
                    child: MediaQuery(
                      data: const MediaQueryData(
                        size: _designSize,
                        devicePixelRatio: 1.0,
                        textScaler: TextScaler.noScaling,
                      ),
                      child: ScreenUtilInit(
                        designSize: _designSize,
                        minTextAdapt: true,
                        splitScreenMode: false,
                        enableScaleWH: () => false,
                        enableScaleText: () => false,
                        builder: (context, child) {
                          return Scaffold(
                            backgroundColor: _bgTop,
                            body: GetBuilder<QueueController>(
                              builder: _buildDisplayBody,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 150.w,
          height: 150.w,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.medical_services_outlined,
            size: 110.sp,
            color: _titleBlue,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'عيادة فرح',
          textDirection: ui.TextDirection.rtl,
          style: GoogleFonts.cairo(
            fontSize: 52.sp,
            fontWeight: FontWeight.w800,
            color: _titleBlue,
            height: 1.2,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'زراعة وتجميل وتقويم الاسنان',
          textDirection: ui.TextDirection.rtl,
          style: GoogleFonts.cairo(
            fontSize: 26.sp,
            fontWeight: FontWeight.w500,
            color: _subBlue,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildNowServing(QueueEntry? current) {
    // عرض Figma ثابت 707 — أضيق من كونتينري القادم/الانتظار (953)
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: 707.w,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_nowTop, _nowBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(40.r),
            boxShadow: [
              BoxShadow(
                color: _nowBottom.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: current == null
              ? _buildEmptyNow()
              : _buildNowContent(current),
        ),
      ),
    );
  }

  Widget _buildEmptyNow() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _sectionTitle(
          'الآن',
          color: Colors.white,
          lineColor: Colors.white54,
          fontSize: 40.sp,
        ),
        SizedBox(height: 24.h),
        Icon(
          Icons.hourglass_empty_rounded,
          size: 72.sp,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        SizedBox(height: 16.h),
        Text(
          'بانتظار الاستدعاء',
          style: GoogleFonts.cairo(
            fontSize: 36.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildNowContent(QueueEntry current) {
    return Padding(
      padding: EdgeInsets.fromLTRB(40.w, 28.h, 40.w, 24.h),
      child: Column(
        children: [
          _sectionTitle(
            'الآن',
            color: Colors.white,
            lineColor: Colors.white54,
            fontSize: 40.sp,
          ),
          // الرقم + الاسم يتقلّصان معاً حسب المساحة المتبقية فوق شريط التوجيه
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final linesSize = math.min(72.w, constraints.maxHeight * 0.28);
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _MotionLines(mirror: true, size: linesSize),
                            SizedBox(width: 16.w),
                            Text(
                              '${current.number}',
                              style: GoogleFonts.cairo(
                                fontSize: 160.sp,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            _MotionLines(mirror: false, size: linesSize),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        _NameDivider(),
                        SizedBox(height: 12.h),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.92,
                          ),
                          child: Text(
                            current.name,
                            textAlign: TextAlign.center,
                            textDirection: ui.TextDirection.rtl,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 38.sp,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            width: 536.w,
            height: 63.h,
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            decoration: BoxDecoration(
              color: const Color(0xFF639ECB).withValues(alpha: 0.53),
              borderRadius: BorderRadius.circular(50.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'يرجى التوجه الى مكتب الاستعلامات',
                    textAlign: TextAlign.center,
                    textDirection: ui.TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Image.asset(
                  'assets/images/Group 33665.png',
                  width: 53.w,
                  height: 53.w,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 28.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextUp(QueueEntry? next) {
    return Center(
      child: SizedBox(
        width: 953.w,
        height: double.infinity,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25.4,
                spreadRadius: -2,
                offset: Offset.zero,
              ),
            ],
          ),
          child: Column(
            children: [
              _sectionTitle(
                'القادم',
                color: Colors.black,
                lineColor: _lineBlue,
                fontSize: 40.sp,
                useAlmarai: true,
                lineWidth: 180.w,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final iconSize =
                        math.min(170.w, constraints.maxHeight * 0.95);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCEDEEA)
                                  .withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/chair.png',
                              width: iconSize * 0.94,
                              height: iconSize * 0.94,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.event_seat_outlined,
                                size: iconSize * 0.5,
                                color: _titleBlue,
                              ),
                            ),
                          ),
                        ),
                        next == null
                            ? Text(
                                '—',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 42.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _subBlue,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${next.number}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.almarai(
                                      fontSize: 85.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF639DCA),
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 120.w),
                                    child: Text(
                                      next.name,
                                      textAlign: TextAlign.center,
                                      textDirection: ui.TextDirection.rtl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.almarai(
                                        fontSize: 28.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF649ECB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingList(List<QueueEntry> waiting) {
    // العمود الأول: حتى 9، الثاني: حتى 9 — الباقي مخفي ويصعد عند الاستدعاء
    const perColumn = 9;
    final visible = waiting.take(perColumn * 2).toList();
    final firstCol = visible.take(perColumn).toList();
    final secondCol = visible.skip(perColumn).toList();

    return Center(
      child: SizedBox(
        width: 953.w,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25.4,
                spreadRadius: -2,
                offset: Offset.zero,
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(28.w, 18.h, 28.w, 18.h),
                child: Column(
                  children: [
                    _sectionTitle(
                      'قائمة الانتظار',
                      color: _titleBlue,
                      lineColor: _lineBlue,
                    ),
                    SizedBox(height: 12.h),
                    Expanded(
                      child: waiting.isEmpty
                          ? Center(
                              child: Text(
                                'لا يوجد مرضى بالانتظار',
                                style: GoogleFonts.cairo(
                                  fontSize: 26.sp,
                                  color: _subBlue,
                                ),
                              ),
                            )
                          : ClipRect(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 8.w),
                                      child: _waitingColumn(secondCol),
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(child: _waitingColumn(firstCol)),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              // طبقة فوق القائمة — لا تؤثر على تخطيط أسماء المرضى
              Positioned(
                left: 8.w,
                bottom: 4.h,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/plant.png',
                    width: 180.w,
                    height: 240.h,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _waitingColumn(List<QueueEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        // دائماً نحسب على أساس 9 صفوف حتى لو العمود فيه أقل —
        // يضمن أن 9 أسماء تتسع داخل كونتينر قائمة الانتظار بدون خروج.
        const maxSlots = 9;
        final count = entries.length;
        final available = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : 40.h * maxSlots;

        final maxGap = 10.h;
        final maxItemH = 40.h;
        final minItemH = 26.h;
        final slotGaps = maxSlots - 1;

        // ارتفاع صف = المساحة ÷ 9، ثم الفجوات من المتبقي فقط
        var itemH = math.min(maxItemH, available / maxSlots);
        itemH = math.max(minItemH, itemH);

        // إن تجاوز المجموع المساحة (عند الضغط الشديد) نلغي الفجوات ونقلّص الصف
        var gap = 0.0;
        if (itemH * maxSlots <= available) {
          final leftover = available - itemH * maxSlots;
          gap = slotGaps > 0
              ? math.min(maxGap, leftover / slotGaps)
              : 0.0;
          // متبقي بعد الـ gap → زد ارتفاع الصف قليلاً إن أمكن
          final afterGaps = available - (itemH * maxSlots + gap * slotGaps);
          if (afterGaps > 0 && itemH < maxItemH) {
            itemH = math.min(maxItemH, itemH + afterGaps / maxSlots);
          }
        } else {
          itemH = available / maxSlots;
          gap = 0.0;
        }

        final numberSize = (itemH * 0.52).clamp(12.0, 22.sp);
        final nameSize = (itemH * 0.46).clamp(12.0, 20.sp);
        final dividerH = (itemH * 0.42).clamp(8.0, 18.h);

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(height: gap),
              SizedBox(
                width: double.infinity,
                height: itemH,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF649FCC).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    textDirection: ui.TextDirection.rtl,
                    children: [
                      Text(
                        '${entries[i].number}',
                        style: GoogleFonts.cairo(
                          fontSize: numberSize,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          color: _titleBlue,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Container(
                          width: 2.w,
                          height: dividerH,
                          color: _lineBlue.withValues(alpha: 0.7),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entries[i].name,
                          textDirection: ui.TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: nameSize,
                            height: 1.0,
                            fontWeight: FontWeight.w600,
                            color: _titleBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFooter() {
    return Text(
      'شكراً لاختياركم عيادتنا نتمنى لكم يوماً صحياً وسعيداً',
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.rtl,
      style: GoogleFonts.almarai(
        fontSize: 30.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF29465C),
      ),
    );
  }

  Widget _sectionTitle(
    String title, {
    required Color color,
    required Color lineColor,
    double? fontSize,
    bool useAlmarai = false,
    double? lineWidth,
  }) {
    final size = fontSize ?? 30.sp;
    final style = useAlmarai
        ? GoogleFonts.almarai(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: color,
          )
        : GoogleFonts.cairo(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: color,
          );

    Widget line() {
      if (lineWidth != null) {
        return Container(
          width: lineWidth,
          height: 1.5,
          color: lineColor.withValues(alpha: 0.55),
        );
      }
      return Expanded(
        child: Container(
          height: 1.5,
          color: lineColor.withValues(alpha: 0.55),
        ),
      );
    }

    return Row(
      mainAxisAlignment: lineWidth != null
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        line(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
        line(),
      ],
    );
  }
}

class _NameDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280.w,
      height: 14.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          Container(
            width: 10.w,
            height: 10.w,
            decoration: const BoxDecoration(
              color: _QueueDisplayScreenState._accentYellow,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _MotionLines extends StatelessWidget {
  final bool mirror;
  final double size;

  const _MotionLines({required this.mirror, required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(mirror ? -1.0 : 1.0, 1.0, 1.0),
      child: CustomPaint(
        size: Size(size, size * 1.35),
        painter: _MotionLinesPainter(),
      ),
    );
  }
}

class _MotionLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _QueueDisplayScreenState._accentYellow
      ..strokeWidth = math.max(5.0, size.width * 0.14)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paths = <List<Offset>>[
      [Offset(size.width * 0.15, size.height * 0.18), Offset(size.width * 0.85, size.height * 0.28)],
      [Offset(size.width * 0.05, size.height * 0.48), Offset(size.width * 0.95, size.height * 0.52)],
      [Offset(size.width * 0.15, size.height * 0.78), Offset(size.width * 0.85, size.height * 0.70)],
    ];

    for (final pts in paths) {
      canvas.drawLine(pts[0], pts[1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QueueBackdrop extends StatelessWidget {
  const _QueueBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _QueueDisplayScreenState._bgTop,
            _QueueDisplayScreenState._bgBottom,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _BackdropPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 1080;
    final scaleY = size.height / 1920;

    final blobPaint = Paint()
      ..color = _QueueDisplayScreenState._blob.withValues(alpha: 0.55);
    final starPaint = Paint()
      ..color = const Color(0xFFF2B45A).withValues(alpha: 0.85);

    // Top-right organic blob
    final topBlob = Path()
      ..moveTo(size.width * 0.55, 0)
      ..quadraticBezierTo(
        size.width * 1.05,
        size.height * 0.08,
        size.width,
        size.height * 0.28,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(topBlob, blobPaint);

    // Bottom-center blob
    final bottomBlob = Path()
      ..moveTo(size.width * 0.15, size.height)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.78,
        size.width * 0.88,
        size.height,
      )
      ..close();
    canvas.drawPath(bottomBlob, blobPaint);

    // شبكة دوائر أعلى يسار الكونتينر الأزرق — 4 أعمدة × 8 صفوف
    // Figma: 35×35، اللون #649FCC بشفافية 27%
    final dotPaint = Paint()
      ..color = const Color(0xFF649FCC).withValues(alpha: 0.27);
    const cols = 4;
    const rows = 8;
    final diameter = 35 * scaleX;
    final radius = diameter / 2;
    final gapX = 52 * scaleX;
    final gapY = 52 * scaleY;
    final startX = 82 * scaleX;
    final startY = 250 * scaleY;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(startX + c * gapX, startY + r * gapY),
          radius,
          dotPaint,
        );
      }
    }

    // Vertical dots on the right
    final rightX = size.width * 0.93;
    final rightStartY = size.height * 0.38;
    final rightGap = 52 * scaleY;
    for (var i = 0; i < 8; i++) {
      canvas.drawCircle(
        Offset(rightX, rightStartY + i * rightGap),
        radius,
        dotPaint,
      );
    }

    void drawSpark(Offset center, double s) {
      final path = Path()
        ..moveTo(center.dx, center.dy - s)
        ..lineTo(center.dx + s * 0.22, center.dy - s * 0.22)
        ..lineTo(center.dx + s, center.dy)
        ..lineTo(center.dx + s * 0.22, center.dy + s * 0.22)
        ..lineTo(center.dx, center.dy + s)
        ..lineTo(center.dx - s * 0.22, center.dy + s * 0.22)
        ..lineTo(center.dx - s, center.dy)
        ..lineTo(center.dx - s * 0.22, center.dy - s * 0.22)
        ..close();
      canvas.drawPath(path, starPaint);
    }

    drawSpark(Offset(size.width * 0.18, size.height * 0.16), size.width * 0.018);
    drawSpark(Offset(size.width * 0.88, size.height * 0.42), size.width * 0.014);
    drawSpark(Offset(size.width * 0.12, size.height * 0.48), size.width * 0.012);

    // نجوم إضافية أعلى يمين الشاشة
    drawSpark(Offset(size.width * 0.82, size.height * 0.06), size.width * 0.016);
    drawSpark(Offset(size.width * 0.92, size.height * 0.10), size.width * 0.011);
    drawSpark(Offset(size.width * 0.78, size.height * 0.12), size.width * 0.009);
    drawSpark(Offset(size.width * 0.88, size.height * 0.16), size.width * 0.014);
    drawSpark(Offset(size.width * 0.95, size.height * 0.20), size.width * 0.008);
    drawSpark(Offset(size.width * 0.84, size.height * 0.24), size.width * 0.012);
    drawSpark(Offset(size.width * 0.91, size.height * 0.28), size.width * 0.010);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
