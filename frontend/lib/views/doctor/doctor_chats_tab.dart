import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/controllers/doctor_chats_screen_controller.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_glass_card.dart';

class DoctorChatsTab extends GetView<DoctorChatsScreenController> {
  const DoctorChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F8FF),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
              child: Text(
                'المحادثات',
                style: AppFonts.lamaSans(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2A44),
                ),
                textDirection: ui.TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
            ),
            Obx(() {
              final unreadTotal = controller.chatList.fold<int>(
                0,
                (sum, item) => sum + ((item['unread_count'] as int?) ?? 0),
              );
              return Container(
                margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
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
                      color: const Color(0xFF2F5FA7).withValues(alpha: 0.22),
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
                              'محادثاتك مع المرضى',
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
              );
            }),
            Container(
              margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE4ECF6)),
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
              child: Obx(() {
                final chats = controller.filteredChatList;
                if (controller.isLoading.value && controller.chatList.isEmpty) {
                  return const LoadingWidget(message: 'جاري تحميل المحادثات...');
                }

                if (chats.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: controller.searchQuery.value.trim().isEmpty
                        ? 'لا توجد محادثات'
                        : 'لا توجد نتائج',
                    subtitle: controller.searchQuery.value.trim().isEmpty
                        ? 'لم يتم بدء أي محادثات بعد'
                        : 'جرّب كلمة بحث مختلفة',
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: controller.loadChatList,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
                    itemCount: chats.length,
                    itemBuilder: (_, index) {
                      final chat = chats[index];
                      return _ChatTile(
                        chat: chat,
                        onTap: () => controller.openChat(
                          chat['patient_id'],
                          patientName: chat['patient_name']?.toString(),
                          patientImageUrl: chat['patient_image_url']?.toString(),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});

  final Map<String, dynamic> chat;
  final VoidCallback onTap;

  String _formatTime(String? raw) {
    if (raw == null) return '';
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

  @override
  Widget build(BuildContext context) {
    final name = chat['patient_name'] ?? 'مريض';
    final rawLast = chat['last_message'] ?? 'لا توجد رسائل';
    final last = rawLast
        .toString()
        .replaceFirst(RegExp(r'^\[reply:[^:\]]+::[^\]]*\]\n'), '');
    final unread = chat['unread_count'] as int? ?? 0;
    final imageUrl = ImageUtils.convertToValidUrl(chat['patient_image_url']);
    final timeText = _formatTime(chat['last_message_time']?.toString());

    return DoctorGlassCard(
      onTap: onTap,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      borderRadius: 16.r,
      color: AppColors.white,
      child: Row(
        children: [
          if (unread > 0)
            Container(
              width: 28.w,
              height: 28.w,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unread > 9 ? '9+' : '$unread',
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
              color: AppColors.doctorNavInactive,
              size: 24.sp,
            ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: ui.TextDirection.rtl,
              children: [
                Row(
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    if (timeText.isNotEmpty)
                      Text(
                        timeText,
                        style: AppFonts.lamaSans(
                          fontSize: 11.sp,
                          color: AppColors.doctorLabel,
                        ),
                      ),
                    const Spacer(),
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: AppFonts.lamaSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  last,
                  style: AppFonts.lamaSans(
                    fontSize: 13.sp,
                    color: AppColors.doctorLabel,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          CircleAvatar(
            radius: 26.r,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: ClipOval(
              child: imageUrl != null && ImageUtils.isValidImageUrl(imageUrl)
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 52.w,
                      height: 52.w,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 24.sp,
                      ),
                    )
                  : Icon(Icons.person, color: AppColors.primary, size: 24.sp),
            ),
          ),
        ],
      ),
    );
  }
}
