import 'dart:io';
import 'dart:math' show pi;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/controllers/chat_screen_controller.dart';
import 'package:farah_sys_final/core/widgets/app_skeleton.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_back_button.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/models/message_model.dart';
import 'package:intl/intl.dart';

class _ChatAssets {
  static const back = 'assets/icon/backblack.png';
  static const chatIcon = 'assets/icon/chatddd.png';
}

class ChatScreen extends GetView<ChatScreenController> {
  const ChatScreen({super.key});

  static const Color _navy = Color(0xFF1A3263);
  static const Color _grayText = Color(0xFF8A97A8);

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final theme = baseTheme.copyWith(
      textTheme: AppFonts.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppFonts.textTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F7FF),
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF9FCFF),
                    Color(0xFFF2F7FF),
                    Color(0xFFEDF3FD),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -70.h,
              right: -35.w,
              child: _decorCircle(220.w, const Color(0x1A4A90D9)),
            ),
            Positioned(
              top: 140.h,
              left: -55.w,
              child: _decorCircle(160.w, const Color(0x144A90D9)),
            ),
            Positioned(
              bottom: 80.h,
              right: -45.w,
              child: _decorCircle(170.w, const Color(0x124A90D9)),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildMessagesArea()),
                  _buildTypingIndicator(),
                  _buildInputBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final imageUrl = controller.doctorImageUrl();
    final userType =
        Get.find<AuthController>().currentUser.value?.userType?.toLowerCase();
    final isDoctor = userType == 'doctor';

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 10.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          textDirection: ui.TextDirection.ltr,
          children: [
            isDoctor
                ? const DoctorBackButton()
                : const BackButtonWidget(assetPath: _ChatAssets.back),
            Expanded(
              child: Directionality(
                textDirection: ui.TextDirection.rtl,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildHeaderAvatar(imageUrl, isDoctor),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Obx(
                        () => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.displayName(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.lamaSans(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              controller.showsDoctorPresence
                                  ? (controller.isDoctorOnline
                                      ? 'متصل الآن'
                                      : 'آخر ظهور مؤخراً')
                                  : 'محادثة مباشرة',
                              style: AppFonts.lamaSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: _grayText,
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar(String? imageUrl, bool isDoctor) {
    final avatar = _buildDoctorAvatar(imageUrl);
    if (!isDoctor) return avatar;

    return GestureDetector(
      onTap: controller.openPatientFile,
      behavior: HitTestBehavior.opaque,
      child: avatar,
    );
  }

  Widget _buildDoctorAvatar(String? imageUrl) {
    final hasImage = imageUrl != null && ImageUtils.isValidImageUrl(imageUrl);

    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: 48.w,
                height: 48.w,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                errorWidget: (_, __, ___) => _avatarPlaceholder(),
                placeholder: (_, __) => Container(color: const Color(0xFFE8ECF0)),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: const Color(0xFFE8ECF0),
      child: Icon(Icons.person_rounded, color: _grayText, size: 24.sp),
    );
  }

  Widget _buildMessagesArea() {
    return Obx(() {
      // Always show loader while fetching so old chat / empty flash never appears.
      if (controller.chatController.isLoading.value &&
          controller.chatController.messages.isEmpty) {
        return const SkeletonChatMessages();
      }

      if (controller.chatController.messages.isEmpty) {
        return _buildEmptyState();
      }

      return Obx(() {
        final loadingMore = controller.chatController.isLoadingMore.value;
        final count = controller.chatController.messages.length;
        final itemCount = count + (loadingMore ? 1 : 0);

        return ListView.builder(
          controller: controller.scrollController,
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
          reverse: true,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // مع reverse: آخر عنصر في القائمة = أعلى الشاشة (رسائل أقدم)
            if (loadingMore && index == itemCount - 1) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final currentUserId =
                controller.authController.currentUser.value?.id ?? '';
            final messages = controller.chatController.messages;
            final message = messages[messages.length - 1 - index];
            final olderActualIndex = messages.length - 2 - index;
            final olderMessage = olderActualIndex >= 0
                ? messages[olderActualIndex]
                : null;
            final showDateChip = olderMessage == null ||
                !_isSameDay(message.timestamp, olderMessage.timestamp);

            controller.onMessagesRendered();

            final isSent = message.senderId.trim() == currentUserId.trim();
            final time = controller.formatMessageTime(message.timestamp);

            controller.cleanupMessageKeys(messages.map((m) => m.id));
            return KeyedSubtree(
              key: controller.messageKey(message.id),
              child: _buildMessageBubble(
                message: message,
                isSent: isSent,
                time: time,
                dateLabel: showDateChip ? _formatDateLabel(message.timestamp) : null,
              ),
            );
          },
        );
      });
    });
  }

  Widget _buildEmptyState() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 80.h,
          right: 30.w,
          child: _decorCircle(120.w, const Color(0xFF649FCC).withValues(alpha: 0.12)),
        ),
        Positioned(
          bottom: 120.h,
          left: 20.w,
          child: _decorCircle(90.w, _navy.withValues(alpha: 0.06)),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110.w,
              height: 110.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    const Color(0xFFE8F0FA),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  _ChatAssets.chatIcon,
                  width: 48.w,
                  height: 48.w,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: 22.h),
            Text(
              'لا توجد رسائل بعد',
              style: AppFonts.lamaSans(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 48.w),
              child: Text(
                'راسل طبيبك مباشرة وتابع ردوده من هنا',
                textAlign: TextAlign.center,
                style: AppFonts.lamaSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: _grayText,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildDateChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: AppFonts.lamaSans(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: _grayText,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Obx(() {
      if (!controller.chatController.isPeerTyping.value) {
        return SizedBox(height: 2.h);
      }
      return Padding(
        padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 4.h),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Text(
              'يكتب الآن...',
              style: AppFonts.lamaSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5D7696),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildInputBar() {
    return Obx(() {
      final reply = controller.replyingTo.value;
      final editing = controller.editingMessage.value;
      final pendingImage = controller.pendingImage.value;
      final parsedReply = reply == null ? null : controller.parseMessage(reply.message);
      final replyImage = (reply?.imageUrl ?? '').trim();
      final editingParsed = editing == null
          ? null
          : controller.parseMessage(editing.message);

      return Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (editing != null)
                Container(
                  margin: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 8.h),
                  padding: EdgeInsets.fromLTRB(10.w, 8.h, 8.w, 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFF6DEB4)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'تعديل الرسالة',
                              style: AppFonts.lamaSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8A5A00),
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              (editingParsed?.text ?? '').trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: AppFonts.lamaSans(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF9A6E23),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: controller.cancelEditing,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18.sp,
                          color: const Color(0xFFB18544),
                        ),
                      ),
                    ],
                  ),
                ),
              if (reply != null)
                Container(
                  margin: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 8.h),
                  padding: EdgeInsets.fromLTRB(10.w, 8.h, 8.w, 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F6FD),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFD7E5F7)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'رد على رسالة',
                              style: AppFonts.lamaSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2D4D76),
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              (parsedReply?.text ?? '').trim().isEmpty
                                  ? (replyImage.isNotEmpty ? 'صورة' : 'رسالة')
                                  : (parsedReply!.text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: AppFonts.lamaSans(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF607A99),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (replyImage.isNotEmpty) ...[
                        SizedBox(width: 8.w),
                        _buildReplyImagePreview(replyImage),
                      ],
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: controller.clearReply,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18.sp,
                          color: const Color(0xFF8AA1BC),
                        ),
                      ),
                    ],
                  ),
                ),
              if (pendingImage != null && editing == null)
                Container(
                  margin: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 8.h),
                  padding: EdgeInsets.fromLTRB(10.w, 8.h, 8.w, 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFD7E5F7)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'صورة جاهزة للإرسال',
                          textAlign: TextAlign.right,
                          style: AppFonts.lamaSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D4D76),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.file(
                          pendingImage,
                          width: 44.w,
                          height: 44.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: controller.clearPendingImage,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18.sp,
                          color: const Color(0xFF8AA1BC),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  _buildCircleAction(
                    icon: Icons.image_outlined,
                    color: editing == null
                        ? _navy.withValues(alpha: 0.08)
                        : const Color(0xFFE4E8EF),
                    iconColor: editing == null ? _navy : const Color(0xFF9EA8B7),
                    onTap: editing == null ? controller.pickImage : () {},
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: TextField(
                      controller: controller.messageController,
                      textAlign: TextAlign.right,
                      textInputAction: TextInputAction.send,
                      onChanged: controller.onComposerChanged,
                      onSubmitted: (_) => controller.sendMessage(),
                      maxLines: 4,
                      minLines: 1,
                      style: AppFonts.lamaSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: _navy,
                      ),
                      decoration: InputDecoration(
                        hintText: editing != null
                            ? 'عدّل الرسالة ثم اضغط إرسال'
                            : AppStrings.writeMessage,
                        hintStyle: AppFonts.lamaSans(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: _grayText.withValues(alpha: 0.65),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 10.h,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller.messageController,
                    builder: (context, value, _) {
                      final canSend = editing != null
                          ? value.text.trim().isNotEmpty
                          : value.text.trim().isNotEmpty ||
                              pendingImage != null;
                      return _buildCircleAction(
                        icon: Icons.send_rounded,
                        color: canSend ? _navy : const Color(0xFFD3DCE8),
                        iconColor: Colors.white,
                        onTap: canSend ? controller.sendMessage : () {},
                        rotateIcon: false,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCircleAction({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    bool rotateIcon = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42.w,
        height: 42.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: rotateIcon
              ? Transform.rotate(
                  angle: pi,
                  child: Icon(icon, color: iconColor, size: 20.sp),
                )
              : Icon(icon, color: iconColor, size: 20.sp),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required MessageModel message,
    required bool isSent,
    required String time,
    String? dateLabel,
  }) {
    final parsed = controller.parseMessage(message.message);
    final repliedMessage = parsed.replyMessageId == null
        ? null
        : controller.findMessageById(parsed.replyMessageId!);
    final replyImagePath = (parsed.replyImageUrl != null &&
            parsed.replyImageUrl!.trim().isNotEmpty)
        ? parsed.replyImageUrl!.trim()
        : (repliedMessage?.imageUrl ?? '').trim();
    final replyText = (parsed.replySnippet != null && parsed.replySnippet!.trim().isNotEmpty)
        ? parsed.replySnippet!.trim()
        : (repliedMessage != null
            ? controller.extractForwardText(repliedMessage)
            : (replyImagePath.isNotEmpty ? 'صورة' : 'رسالة'));
    final hasReplyPreview = parsed.replyMessageId != null;
    final imageUrl = message.imageUrl;
    final validImageUrl = imageUrl != null && imageUrl.isNotEmpty
        ? ImageUtils.convertToValidUrl(imageUrl)
        : null;
    final hasImage =
        validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl);
    final hasText = parsed.text.trim().isNotEmpty;

    final bubbleColor = isSent ? null : Colors.white;
    final textColor = isSent ? Colors.white : _navy;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(20.r),
      topRight: Radius.circular(20.r),
      bottomLeft: Radius.circular(isSent ? 6.r : 20.r),
      bottomRight: Radius.circular(isSent ? 20.r : 6.r),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        crossAxisAlignment:
            isSent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (dateLabel != null) ...[
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: _buildDateChip(dateLabel),
            ),
          ],
          _SwipeReplyWrapper(
            onReply: () {
              HapticFeedback.selectionClick();
              controller.setReply(message);
            },
            child: GestureDetector(
              onLongPress: () => _showMessageActions(
                message,
                canEdit: isSent && parsed.text.trim().isNotEmpty,
              ),
              child: Obx(() {
                final highlighted = controller.highlightedMessageId.value == message.id;
                return Container(
                  constraints: BoxConstraints(maxWidth: 260.w),
                  decoration: BoxDecoration(
                    gradient: isSent && !hasImage
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A3263), Color(0xFF254A82)],
                          )
                        : null,
                    color: hasImage ? Colors.transparent : bubbleColor,
                    borderRadius: borderRadius,
                    border: highlighted
                        ? Border.all(
                            color: const Color(0xFF5DA8FF),
                            width: 1.6,
                          )
                        : (isSent || hasImage
                              ? null
                              : Border.all(color: Colors.white)),
                    boxShadow: [
                      BoxShadow(
                        color: highlighted
                            ? const Color(0xFF5DA8FF).withValues(alpha: 0.28)
                            : (isSent ? _navy : Colors.black)
                                .withValues(alpha: isSent ? 0.18 : 0.06),
                        blurRadius: highlighted ? 18 : 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasReplyPreview)
                        InkWell(
                          onTap: parsed.replyMessageId == null
                              ? null
                              : () async {
                                  final ok = await controller.scrollToReplyTarget(
                                    messageId: parsed.replyMessageId,
                                    replySnippet: parsed.replySnippet,
                                    replyImageUrl: replyImagePath,
                                  );
                                  if (!ok) {
                                    Get.snackbar(
                                      'تنبيه',
                                      'الرسالة الأصلية غير ظاهرة حالياً',
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(10.r),
                          child: Container(
                            width: hasImage ? 260.w : null,
                            margin: EdgeInsets.fromLTRB(
                              8.w,
                              8.h,
                              8.w,
                              hasImage ? 6.h : 2.h,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: isSent
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : const Color(0xFFEFF5FE),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              textDirection: ui.TextDirection.rtl,
                              children: [
                                if (replyImagePath.isNotEmpty) ...[
                                  _buildReplyImagePreview(replyImagePath),
                                  SizedBox(width: 8.w),
                                ],
                                Expanded(
                                  child: Text(
                                    replyText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: AppFonts.lamaSans(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: isSent
                                          ? Colors.white
                                          : const Color(0xFF4F6787),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: CachedNetworkImage(
                        imageUrl: validImageUrl,
                        width: 280.w,
                        height: 200.h,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        memCacheWidth: 560,
                        memCacheHeight: 400,
                        placeholder: (context, url) => Container(
                          width: 280.w,
                          height: 200.h,
                          color: const Color(0xFFF4F7FC),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _navy,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 280.w,
                          height: 200.h,
                          color: const Color(0xFFF4F7FC),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: _grayText,
                          ),
                        ),
                      ),
                    ),
                  if (hasImage && hasText) SizedBox(height: 8.h),
                  if (hasText)
                    Container(
                      width: hasImage ? 260.w : null,
                      padding: EdgeInsets.symmetric(
                        horizontal: hasImage ? 14.w : 16.w,
                        vertical: hasImage ? 12.h : 14.h,
                      ),
                      decoration: hasImage
                          ? BoxDecoration(
                              gradient: isSent
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF1A3263),
                                        Color(0xFF254A82),
                                      ],
                                    )
                                  : null,
                              color: isSent ? null : Colors.white,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(16.r),
                              ),
                            )
                          : null,
                      child: Text(
                        parsed.text,
                        textAlign: TextAlign.right,
                        style: AppFonts.lamaSans(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    ],
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: AppFonts.lamaSans(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: _grayText,
                  ),
                ),
                if (isSent) ...[
                  SizedBox(width: 4.w),
                  Obx(() {
                    final isSending = controller.chatController
                        .sendingMessageIds
                        .contains(message.id);
                    if (isSending) {
                      return SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _navy,
                        ),
                      );
                    }
                    if (message.isRead) {
                      return Icon(
                        Icons.done_all_rounded,
                        size: 15.sp,
                        color: const Color(0xFF3A86FF),
                      );
                    }
                    return Icon(
                      Icons.done_all_rounded,
                      size: 15.sp,
                      color: const Color(0xFF9FB0C6),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyImagePreview(String imagePath) {
    final validUrl = ImageUtils.convertToValidUrl(imagePath);
    if (validUrl != null && ImageUtils.isValidImageUrl(validUrl)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7.r),
        child: CachedNetworkImage(
          imageUrl: validUrl,
          width: 34.w,
          height: 34.w,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: 34.w,
            height: 34.w,
            color: const Color(0xFFDCE7F6),
            child: Icon(Icons.image, size: 14.sp, color: const Color(0xFF607A99)),
          ),
        ),
      );
    }

    final file = File(imagePath);
    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7.r),
        child: Image.file(
          file,
          width: 34.w,
          height: 34.w,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 34.w,
      height: 34.w,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE7F6),
        borderRadius: BorderRadius.circular(7.r),
      ),
      child: Icon(Icons.image, size: 14.sp, color: const Color(0xFF607A99)),
    );
  }

  void _showMessageActions(MessageModel message, {required bool canEdit}) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: Text(
                  'رد على الرسالة',
                  textAlign: TextAlign.right,
                  style: AppFonts.lamaSans(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Get.back();
                  controller.setReply(message);
                },
              ),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: Text(
                    'تعديل الرسالة',
                    textAlign: TextAlign.right,
                    style: AppFonts.lamaSans(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Get.back();
                    controller.startEditing(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(
                  'نسخ النص',
                  textAlign: TextAlign.right,
                  style: AppFonts.lamaSans(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  final text = controller.parseMessage(message.message).text.trim();
                  if (text.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: text));
                    Get.snackbar('تم', 'تم نسخ الرسالة');
                  }
                  Get.back();
                },
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: false,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return controller.todayLabel();
    if (diff == 1) return 'أمس';
    return DateFormat('EEEE، dd/MM/yyyy', 'ar').format(date);
  }
}

class _SwipeReplyWrapper extends StatefulWidget {
  const _SwipeReplyWrapper({
    required this.child,
    required this.onReply,
  });

  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeReplyWrapper> createState() => _SwipeReplyWrapperState();
}

class _SwipeReplyWrapperState extends State<_SwipeReplyWrapper> {
  double _dx = 0;
  bool _fired = false;
  static const double _maxDx = 72;
  static const double _triggerDx = 44;

  void _handleUpdate(DragUpdateDetails details) {
    final next = (_dx + details.delta.dx).clamp(0, _maxDx).toDouble();
    setState(() => _dx = next);
    if (!_fired && _dx >= _triggerDx) {
      _fired = true;
      widget.onReply();
    }
  }

  void _handleEnd([DragEndDetails? _]) {
    _fired = false;
    setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleUpdate,
      onHorizontalDragEnd: _handleEnd,
      onHorizontalDragCancel: _handleEnd,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: (_dx / _triggerDx).clamp(0, 1),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDEE9FA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.reply_rounded,
                      size: 18,
                      color: Color(0xFF325F99),
                    ),
                  ),
                ),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 360),
            curve: Curves.elasticOut,
            tween: Tween<double>(begin: 0, end: _dx),
            builder: (_, value, child) {
              return Transform.translate(
                offset: Offset(value, 0),
                child: child,
              );
            },
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
