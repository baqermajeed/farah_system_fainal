import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';

enum AppointmentCardTone { upcoming, past, late }

class AppointmentListCard extends StatelessWidget {
  const AppointmentListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.time,
    this.footerText = 'الرجاء الحضور قبل الموعد ب نصف ساعة',
    this.tone = AppointmentCardTone.upcoming,
    this.avatarImageUrl,
    this.preferAvatar = false,
    this.onTap,
  });

  static const String calendarIcon = 'assets/icon/date23.png';

  final String title;
  final String subtitle;
  final DateTime date;
  final String time;
  final String footerText;
  final AppointmentCardTone tone;
  final String? avatarImageUrl;
  final bool preferAvatar;
  final VoidCallback? onTap;

  static const Color _navy = Color(0xFF1A3158);
  static const Color _emphasis = Color(0xFF111111);
  static const Color _muted = Color(0xFF788FA5);
  static const Color _accentBlue = Color(0xFF5A9BD5);
  static const Color _dateBg = Color(0xFFF0F4F8);
  static const Color _lateColor = Color(0xFFE74C3C);

  _CardPalette _palette() {
    switch (tone) {
      case AppointmentCardTone.late:
        return const _CardPalette(
          accent: _lateColor,
          title: _navy,
          emphasis: _emphasis,
          muted: _muted,
          dateBg: Color(0xFFFFF0F0),
          cardBg: Colors.white,
          border: Color(0xFFF5C6C6),
          tintFooterIcon: false,
        );
      case AppointmentCardTone.past:
        return const _CardPalette(
          accent: _accentBlue,
          title: _navy,
          emphasis: Color(0xFF1F2937),
          muted: _muted,
          dateBg: _dateBg,
          cardBg: Colors.white,
          border: Color(0xFFE2E8F0),
          tintFooterIcon: false,
        );
      case AppointmentCardTone.upcoming:
        return const _CardPalette(
          accent: _accentBlue,
          title: _navy,
          emphasis: _emphasis,
          muted: _muted,
          dateBg: _dateBg,
          cardBg: Colors.white,
          border: Color(0xFFCFE3F3),
          tintFooterIcon: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette();

    final weekDays = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final dayName = weekDays[date.weekday % 7];
    final dayNumber = date.day.toString();
    final monthYear = DateFormat('MMMM yyyy', 'ar').format(date);

    final timeParts = time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? timeParts[1] : '00';
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeText = '$displayHour:$minute';
    final periodText = isPM ? 'مساءً' : 'صباحاً';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          decoration: BoxDecoration(
            color: palette.cardBg,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Column(
              children: [
                Directionality(
                  textDirection: ui.TextDirection.rtl,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 5.w, color: palette.accent),
                        Container(
                          width: 78.w,
                          padding: EdgeInsets.symmetric(
                            vertical: 14.h,
                            horizontal: 8.w,
                          ),
                          decoration: BoxDecoration(
                            color: palette.dateBg,
                            border: Border(
                              left: BorderSide(
                                color: palette.accent.withValues(alpha: 0.28),
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dayName,
                                style: AppFonts.lamaSans(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: palette.muted,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                dayNumber,
                                style: AppFonts.lamaSans(
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w800,
                                  color: palette.emphasis,
                                  height: 1,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                monthYear,
                                textAlign: TextAlign.center,
                                style: AppFonts.lamaSans(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          child: Center(child: _buildLeadingAvatar(palette)),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4.w,
                              vertical: 16.h,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.lamaSans(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w800,
                                    color: palette.title,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.lamaSans(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 16.h,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                timeText,
                                style: AppFonts.lamaSans(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: palette.emphasis,
                                ),
                              ),
                              Text(
                                periodText,
                                style: AppFonts.lamaSans(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE8ECF0),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  child: Directionality(
                    textDirection: ui.TextDirection.rtl,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          calendarIcon,
                          width: 18.w,
                          height: 18.w,
                          fit: BoxFit.contain,
                          color: palette.tintFooterIcon ? palette.muted : null,
                          colorBlendMode:
                              palette.tintFooterIcon ? BlendMode.srcIn : null,
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            footerText,
                            textAlign: TextAlign.center,
                            style: AppFonts.lamaSans(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: palette.muted,
                            ),
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
      ),
    );
  }

  Widget _buildLeadingAvatar(_CardPalette palette) {
    if (!preferAvatar) {
      return _calendarFallback();
    }

    final validUrl = ImageUtils.convertToValidUrl(avatarImageUrl);
    final hasImage =
        validUrl != null && ImageUtils.isValidImageUrl(validUrl);

    return Container(
      width: 46.w,
      height: 46.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _accentBlue.withValues(alpha: 0.12),
        border: Border.all(
          color: _accentBlue.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: validUrl,
                width: 46.w,
                height: 46.w,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                memCacheWidth: 96,
                memCacheHeight: 96,
                errorWidget: (_, __, ___) => _personFallback(),
              )
            : _personFallback(),
      ),
    );
  }

  Widget _personFallback() {
    return Center(
      child: Icon(
        Icons.person_rounded,
        color: _accentBlue,
        size: 24.sp,
      ),
    );
  }

  Widget _calendarFallback() {
    return Image.asset(
      calendarIcon,
      width: 42.w,
      height: 42.w,
      fit: BoxFit.contain,
    );
  }
}

class _CardPalette {
  const _CardPalette({
    required this.accent,
    required this.title,
    required this.emphasis,
    required this.muted,
    required this.dateBg,
    required this.cardBg,
    required this.border,
    required this.tintFooterIcon,
  });

  final Color accent;
  final Color title;
  final Color emphasis;
  final Color muted;
  final Color dateBg;
  final Color cardBg;
  final Color border;
  final bool tintFooterIcon;
}
