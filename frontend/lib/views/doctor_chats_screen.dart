import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/utils/date_time_utils.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_back_button.dart';
import 'package:farah_sys_final/controllers/doctor_chats_screen_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class DoctorChatsScreen extends GetView<DoctorChatsScreenController> {
  const DoctorChatsScreen({super.key});

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _searchBg = Color(0xFFF0F2F5);
  static const Color _titleColor = Color(0xFF111B21);
  static const Color _subtitleColor = Color(0xFF667781);
  static const Color _dividerColor = Color(0xFFE9EDEF);

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final cairoTheme = baseTheme.copyWith(
      textTheme: AppFonts.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppFonts.textTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: cairoTheme,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: AppBar(
              backgroundColor: _bg,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: EdgeInsets.only(left: 16.w),
                child: Center(child: const DoctorBackButton()),
              ),
              leadingWidth: 64.w,
              title: Directionality(
                textDirection: ui.TextDirection.rtl,
                child: Text(
                  'المحادثات',
                  style: AppFonts.lamaSans(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
              ),
              titleSpacing: 0,
              centerTitle: true,
            ),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value && controller.chatList.isEmpty) {
            return const LoadingWidget(message: 'جاري تحميل المحادثات...');
          }

          final chats = controller.filteredChatList;

          return Column(
            children: [
              _buildSearchBar(),
              _buildFilterRow(),
              Expanded(
                child: chats.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: _emptyTitle(),
                        subtitle: _emptySubtitle(),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: controller.loadChatList,
                        child: ListView.separated(
                          padding: EdgeInsets.only(bottom: 16.h),
                          itemCount: chats.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 0.6,
                            color: _dividerColor,
                            indent: 78.w,
                          ),
                          itemBuilder: (_, i) => _buildChatTile(chats[i]),
                        ),
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _emptyTitle() {
    if (controller.searchQuery.value.trim().isNotEmpty) return 'لا توجد نتائج';
    if (controller.readFilter.value == ChatReadFilter.unread) {
      return 'لا توجد محادثات غير مقروءة';
    }
    if (controller.readFilter.value == ChatReadFilter.read) {
      return 'لا توجد محادثات مقروءة';
    }
    return 'لا توجد محادثات';
  }

  String _emptySubtitle() {
    if (controller.searchQuery.value.trim().isNotEmpty) {
      return 'جرّب كلمة بحث مختلفة';
    }
    if (controller.readFilter.value != ChatReadFilter.all) {
      return 'غيّر الفلتر لعرض جميع المحادثات';
    }
    return 'لم يتم بدء أي محادثات بعد';
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 10.h),
      child: Container(
        height: 44.h,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F2A44).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          textDirection: ui.TextDirection.rtl,
          onChanged: (value) => controller.searchQuery.value = value,
          style: AppFonts.lamaSans(
            fontSize: 15.sp,
            color: _titleColor,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث باسم المريض أو آخر رسالة',
            hintStyle: AppFonts.lamaSans(
              fontSize: 14.sp,
              color: _subtitleColor,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10.h),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 22.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'الكل',
              filter: ChatReadFilter.all,
            ),
            SizedBox(width: 8.w),
            _buildFilterChip(
              label: 'غير مقروءة',
              filter: ChatReadFilter.unread,
              count: controller.unreadChatsCount,
            ),
            SizedBox(width: 8.w),
            _buildFilterChip(
              label: 'مقروءة',
              filter: ChatReadFilter.read,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required ChatReadFilter filter,
    int? count,
  }) {
    final isActive = controller.readFilter.value == filter;
    final showCount = count != null && count > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.setReadFilter(filter),
        borderRadius: BorderRadius.circular(20.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : _searchBg,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppFonts.lamaSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.white : _subtitleColor,
                ),
              ),
              if (showCount) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.white.withValues(alpha: 0.25)
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: AppFonts.lamaSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: isActive ? AppColors.white : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chatItem) {
    final name = (chatItem['patient_name'] as String?) ?? 'مريض';
    final rawLast = (chatItem['last_message'] as String?) ?? 'لا توجد رسائل';
    final last = _stripReplyMeta(rawLast);
    final unread = (chatItem['unread_count'] as int?) ?? 0;
    final hasUnread = unread > 0;
    final timeText = _formatTime(chatItem['last_message_time']?.toString());
    final imageUrl = ImageUtils.convertToValidUrl(chatItem['patient_image_url']);
    final hasImage = imageUrl != null && ImageUtils.isValidImageUrl(imageUrl);

    return Material(
      color: _bg,
      child: InkWell(
        onTap: () => controller.openChat(
          chatItem['patient_id'],
          patientName: chatItem['patient_name']?.toString(),
          patientImageUrl: chatItem['patient_image_url']?.toString(),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
          child: Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28.r,
                  backgroundColor: const Color(0xFFE9F3FF),
                  child: ClipOval(
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 56.w,
                            height: 56.w,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            memCacheWidth: 120,
                            memCacheHeight: 120,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                              size: 28.sp,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 28.sp,
                          ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: AppFonts.lamaSans(
                                fontSize: 16.sp,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _titleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeText.isNotEmpty) ...[
                            SizedBox(width: 8.w),
                            Text(
                              timeText,
                              style: AppFonts.lamaSans(
                                fontSize: 12.sp,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: hasUnread
                                    ? AppColors.primary
                                    : _subtitleColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              last,
                              style: AppFonts.lamaSans(
                                fontSize: 14.sp,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: hasUnread
                                    ? const Color(0xFF3B4A54)
                                    : _subtitleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            SizedBox(width: 8.w),
                            Container(
                              constraints: BoxConstraints(minWidth: 22.w),
                              height: 22.w,
                              padding: EdgeInsets.symmetric(horizontal: 6.w),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(99.r),
                              ),
                              child: Center(
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  style: AppFonts.lamaSans(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String? raw) {
    final dateTime = DateTimeUtils.parseApiToLocal(raw);
    if (dateTime == null) return '';
    try {
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      if (diff.inDays == 0) {
        final hour = dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = hour < 12 ? 'ص' : 'م';
        final displayHour = hour == 0
            ? 12
            : hour > 12
                ? hour - 12
                : hour;
        return '$displayHour:$minute $period';
      }
      if (diff.inDays == 1) return 'أمس';
      if (diff.inDays < 7) return DateFormat('EEEE', 'ar').format(dateTime);
      return DateFormat('dd/MM/yyyy', 'ar').format(dateTime);
    } catch (_) {
      return '';
    }
  }

  String _stripReplyMeta(String value) {
    var text = value.replaceFirst(
      RegExp(r'^\[reply:[^:\]]+::[^\]]*\]\n'),
      '',
    );
    text = text.replaceFirst(RegExp(r'^\[reply_image:[^\]]*\]\n'), '');
    return text.trim().isEmpty ? 'صورة' : text;
  }
}
