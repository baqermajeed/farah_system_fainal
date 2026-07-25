import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/doctor_chats_screen_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class DoctorChatsScreen extends GetView<DoctorChatsScreenController> {
  const DoctorChatsScreen({super.key});

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
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: ui.TextDirection.ltr, // keep back button on LEFT always
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: EdgeInsets.only(left: 16.w),
                child: const BackButtonWidget(),
              ),
              leadingWidth: 56.w,
              title: Padding(
                padding: EdgeInsets.only(top: 30.h),
                child: Directionality(
                  textDirection: ui.TextDirection.rtl,
                  child: Text(
                    'المحادثات',
                    style: AppFonts.lamaSans(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2A44),
                    ),
                  ),
                ),
              ),
              centerTitle: true,
            ),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value && controller.chatList.isEmpty) {
            return const LoadingWidget(message: 'جاري تحميل المحادثات...');
          }

          final unreadTotal = controller.chatList.fold<int>(
            0,
            (sum, item) => sum + ((item['unread_count'] as int?) ?? 0),
          );
          final chats = controller.filteredChatList;

          return Column(
            children: [
              Container(
                margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A90D9), Color(0xFF2F5FA7)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(22.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F5FA7).withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Directionality(
                  textDirection: ui.TextDirection.rtl,
                  child: Row(
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Icon(
                          Icons.chat_rounded,
                          color: AppColors.white,
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تواصل مع مرضاك بسهولة',
                              style: AppFonts.lamaSans(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                            SizedBox(height: 5.h),
                            Text(
                              '${controller.chatList.length} محادثة • $unreadTotal غير مقروءة',
                              style: AppFonts.lamaSans(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE4ECF6)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F2A44).withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  textDirection: ui.TextDirection.rtl,
                  onChanged: (value) => controller.searchQuery.value = value,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المريض أو آخر رسالة',
                    hintStyle: AppFonts.lamaSans(
                      fontSize: 13.sp,
                      color: const Color(0xFF9BA9BC),
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: const Color(0xFF7D8FA8),
                      size: 20.sp,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: chats.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: controller.searchQuery.value.trim().isEmpty
                            ? 'لا توجد محادثات'
                            : 'لا توجد نتائج',
                        subtitle: controller.searchQuery.value.trim().isEmpty
                            ? 'لم يتم بدء أي محادثات بعد'
                            : 'جرّب كلمة بحث مختلفة',
                      )
                    : RefreshIndicator(
                        onRefresh: controller.loadChatList,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                          itemCount: chats.length,
                          separatorBuilder: (_, __) => SizedBox(height: 10.h),
                          itemBuilder: (_, i) => _buildChatCard(chats[i]),
                        ),
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chatItem) {
    final name = (chatItem['patient_name'] as String?) ?? 'مريض';
    final rawLast = (chatItem['last_message'] as String?) ?? 'لا توجد رسائل';
    final last = _stripReplyMeta(rawLast);
    final unread = (chatItem['unread_count'] as int?) ?? 0;
    final timeText = _formatTime(chatItem['last_message_time']?.toString());
    final imageUrl = ImageUtils.convertToValidUrl(chatItem['patient_image_url']);
    final hasImage = imageUrl != null && ImageUtils.isValidImageUrl(imageUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => controller.openChat(
          chatItem['patient_id'],
          patientName: chatItem['patient_name']?.toString(),
          patientImageUrl: chatItem['patient_image_url']?.toString(),
        ),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: const Color(0xFFE4ECF6)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F2A44).withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27.r,
                  backgroundColor: const Color(0xFFE9F3FF),
                  child: ClipOval(
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 54.w,
                            height: 54.w,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            memCacheWidth: 120,
                            memCacheHeight: 120,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 24.sp,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 24.sp,
                          ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppFonts.lamaSans(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2A44),
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        last,
                        style: AppFonts.lamaSans(
                          fontSize: 14.sp,
                          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                          color: unread > 0
                              ? const Color(0xFF2E486A)
                              : const Color(0xFF8193A9),
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeText,
                      style: AppFonts.lamaSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF93A4BA),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    if (unread > 0)
                      Container(
                        constraints: BoxConstraints(minWidth: 24.w),
                        height: 24.w,
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
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_left_rounded,
                        color: const Color(0xFFB7C3D3),
                        size: 22.sp,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(raw).toLocal();
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
    return value.replaceFirst(RegExp(r'^\[reply:[^:\]]+::[^\]]*\]\n'), '');
  }
}
