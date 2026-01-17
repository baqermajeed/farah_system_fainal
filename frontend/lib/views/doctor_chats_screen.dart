import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/services/chat_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class DoctorChatsScreen extends StatefulWidget {
  const DoctorChatsScreen({super.key});

  @override
  State<DoctorChatsScreen> createState() => _DoctorChatsScreenState();
}

class _DoctorChatsScreenState extends State<DoctorChatsScreen> {
  final ChatService _chatService = ChatService();
  final RxList<Map<String, dynamic>> _chatList = <Map<String, dynamic>>[].obs;
  final RxBool _isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _loadChatList();
  }

  Future<void> _loadChatList() async {
    try {
      _isLoading.value = true;
      final list = await _chatService.getChatList();
      _chatList.value = list;
    } on ApiException catch (e) {
      Get.snackbar('خطأ', e.message);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المحادثات');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final cairoTheme = baseTheme.copyWith(
      textTheme: GoogleFonts.cairoTextTheme(baseTheme.textTheme),
      primaryTextTheme: GoogleFonts.cairoTextTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: cairoTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4FEFF),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: ui.TextDirection.ltr, // keep back button on LEFT always
            child: AppBar(
              backgroundColor: const Color(0xFFF4FEFF),
              elevation: 0,
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
                    style: GoogleFonts.cairo(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              centerTitle: true,
            ),
          ),
        ),
        body: Obx(() {
        // Show loading widget when loading and list is empty
        if (_isLoading.value && _chatList.isEmpty) {
          return const LoadingWidget(message: 'جاري تحميل المحادثات...');
        }

        if (_chatList.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.chat_bubble_outline,
            title: 'لا توجد محادثات',
            subtitle: 'لم يتم بدء أي محادثات بعد',
          );
        }

        return RefreshIndicator(
          onRefresh: _loadChatList,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            itemBuilder: (_, i) {
              final chatItem = _chatList[i];

              // Get patient name
              String name = chatItem['patient_name'] ?? 'مريض';

              // Get last message
              String last = chatItem['last_message'] ?? 'لا توجد رسائل';

              // Get unread count
              int unread = chatItem['unread_count'] ?? 0;

              // Get patient image
              String? userImageUrl = chatItem['patient_image_url'];

              // Format time
              String timeText = '';
              if (chatItem['last_message_time'] != null) {
                try {
                  // Parse UTC time and convert to local
                  final dateTime = DateTime.parse(
                    chatItem['last_message_time'],
                  ).toLocal();
                  final now = DateTime.now();
                  final difference = now.difference(dateTime);

                  if (difference.inDays == 0) {
                    // Today - show time in 12-hour format
                    final hour = dateTime.hour;
                    final minute = dateTime.minute.toString().padLeft(2, '0');

                    String period;
                    int displayHour;

                    if (hour == 0) {
                      displayHour = 12;
                      period = 'ص';
                    } else if (hour < 12) {
                      displayHour = hour;
                      period = 'ص';
                    } else if (hour == 12) {
                      displayHour = 12;
                      period = 'م';
                    } else {
                      displayHour = hour - 12;
                      period = 'م';
                    }

                    timeText = '$displayHour:$minute $period';
                  } else if (difference.inDays == 1) {
                    timeText = 'أمس';
                  } else if (difference.inDays < 7) {
                    timeText = DateFormat('EEEE', 'ar').format(dateTime);
                  } else {
                    timeText = DateFormat('dd/MM/yyyy', 'ar').format(dateTime);
                  }
                } catch (e) {
                  timeText = '';
                }
              }

              return InkWell(
                borderRadius: BorderRadius.circular(16.r),
                onTap: () async {
                  await Get.toNamed(
                    AppRoutes.chat,
                    arguments: {'patientId': chatItem['patient_id']},
                  );
                  // Reload chat list when returning from chat
                  // Add small delay to ensure messages are marked as read
                  await Future.delayed(const Duration(milliseconds: 300));
                  _loadChatList();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // image at the right (في RTL)
                      Builder(
                        builder: (context) {
                          final validImageUrl = ImageUtils.convertToValidUrl(
                            userImageUrl,
                          );
                          final hasImage =
                              validImageUrl != null &&
                              ImageUtils.isValidImageUrl(validImageUrl);

                          return CircleAvatar(
                            radius: 28.r,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child: hasImage
                                  ? CachedNetworkImage(
                                      imageUrl: validImageUrl,
                                      width: 50.w,
                                      height: 50.w,
                                      fit: BoxFit.cover,
                                      fadeInDuration: Duration.zero,
                                      fadeOutDuration: Duration.zero,
                                      memCacheWidth: 112,
                                      memCacheHeight: 112,
                                      placeholder: (context, url) => Container(
                                        width: 50.w,
                                        height: 50.w,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.secondary,
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: AppColors.white,
                                          size: 28.sp,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            width: 50.w,
                                            height: 50.w,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.primary,
                                                  AppColors.secondary,
                                                ],
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              color: AppColors.white,
                                              size: 28.sp,
                                            ),
                                          ),
                                    )
                                  : Container(
                                      width: 56.w,
                                      height: 56.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.secondary,
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: AppColors.white,
                                        size: 28.sp,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 12.w),
                      // name + last message
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                if (timeText.isNotEmpty) ...[
                                  SizedBox(width: 8.w),
                                  Text(
                                    timeText,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              last,
                              style: GoogleFonts.cairo(
                                fontSize: 16.sp,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // arrow + unread badge at the end (left in RTL)
                      Column(
                        children: [
                          Icon(
                            Icons.keyboard_arrow_left,
                            color: AppColors.textSecondary,
                          ),
                          if (unread > 0)
                            Container(
                              width: 30.w,
                              height: 30.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7CC7D0),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$unread',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) =>
                Divider(color: AppColors.divider, height: 1),
            itemCount: _chatList.length,
          ),
        );
        }),
      ),
    );
  }
}
