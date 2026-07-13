import 'dart:io';
import 'dart:math' show pi;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/controllers/chat_controller.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/models/message_model.dart';

class _ChatAssets {
  static const back = 'assets/icon/backblack.png';
  static const chatIcon = 'assets/icon/chatddd.png';
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _navy = Color(0xFF1A3263);
  static const Color _grayText = Color(0xFF8A97A8);

  final ChatController _chatController = Get.find<ChatController>();
  final AuthController _authController = Get.find<AuthController>();
  final PatientController _patientController = Get.find<PatientController>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  String? patientId;
  String? doctorId;
  String? doctorName;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    patientId = args?['patientId'];
    doctorId = args?['doctorId'];
    doctorName = args?['doctorName'];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_authController.currentUser.value?.userType == 'patient') {
        if (_patientController.myDoctors.isEmpty) {
          await _patientController.loadMyDoctors();
        }
      }
      if (patientId != null) {
        try {
          await _chatController.openChat(
            patientId: patientId!,
            doctorId: doctorId,
          );
          _lastMessageCount = _chatController.messages.length;
          await Future.delayed(const Duration(milliseconds: 300));
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        } catch (e) {
          debugPrint('❌ [ChatScreen] Error initializing chat: $e');
          Get.snackbar(
            'خطأ',
            'حدث خطأ أثناء تحميل المحادثة',
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        Get.snackbar('خطأ', 'لم يتم تحديد المريض');
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatController.disconnect();
    super.dispose();
  }

  String _displayName() {
    final currentUser = _authController.currentUser.value;
    final currentUserType = currentUser?.userType.toLowerCase();

    if (currentUserType == 'patient') {
      final name = doctorName ?? 'طبيب';
      return name.startsWith('د.') ? name : 'د. $name';
    }
    if (patientId != null) {
      final patient = _patientController.getPatientById(patientId!);
      return patient?.name ?? 'مريض';
    }
    return 'محادثة';
  }

  String? _doctorImageUrl() {
    for (final doctor in _patientController.myDoctors) {
      final id = doctor['id']?.toString();
      if (doctorId != null && id == doctorId) {
        return ImageUtils.convertToValidUrl(doctor['imageUrl']);
      }
    }
    return ImageUtils.convertToValidUrl(
      _patientController.myDoctor.value?['imageUrl'],
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'مساءً' : 'صباحاً';
    return 'اليوم، $displayHour:$minute $period';
  }

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
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF4F7FC),
                Color(0xFFEEF3FA),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMessagesArea()),
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final imageUrl = _doctorImageUrl();

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 16.w, 12.h),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          const BackButtonWidget(assetPath: _ChatAssets.back),
          Expanded(
            child: Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildDoctorAvatar(imageUrl),
                  SizedBox(width: 12.w),
                  Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(),
                          style: AppFonts.lamaSans(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Container(
                              width: 7.w,
                              height: 7.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFF34C759),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              'متصل الآن',
                              style: AppFonts.lamaSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: _grayText,
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
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorAvatar(String? imageUrl) {
    final hasImage =
        imageUrl != null && ImageUtils.isValidImageUrl(imageUrl);

    return Container(
      width: 46.w,
      height: 46.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: 46.w,
                height: 46.w,
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
      if (_chatController.isLoading.value &&
          _chatController.messages.isEmpty) {
        return const LoadingWidget(message: 'جاري تحميل الرسائل...');
      }

      if (_chatController.messages.isEmpty) {
        return _buildEmptyState();
      }

      return Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: _buildDateChip(_todayLabel()),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              reverse: true,
              itemCount: _chatController.messages.length,
              itemBuilder: (context, index) {
                final currentUserId =
                    _authController.currentUser.value?.id ?? '';
                final message = _chatController
                    .messages[_chatController.messages.length - 1 - index];

                if (_chatController.messages.length != _lastMessageCount) {
                  _lastMessageCount = _chatController.messages.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }

                final isSent =
                    message.senderId.trim() == currentUserId.trim();
                final time = _formatMessageTime(message.timestamp);

                return _buildMessageBubble(
                  message: message,
                  isSent: isSent,
                  time: time,
                );
              },
            ),
          ),
        ],
      );
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

  Widget _buildInputBar() {
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
        child: Row(
          children: [
            _buildCircleAction(
              icon: Icons.image_outlined,
              color: _navy.withValues(alpha: 0.08),
              iconColor: _navy,
              onTap: _pickImage,
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: TextField(
                controller: _messageController,
                textAlign: TextAlign.right,
                maxLines: 4,
                minLines: 1,
                style: AppFonts.lamaSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: _navy,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.writeMessage,
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
            _buildCircleAction(
              icon: Icons.send_rounded,
              color: _navy,
              iconColor: Colors.white,
              onTap: _sendMessage,
              rotateIcon: true,
            ),
          ],
        ),
      ),
    );
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty && patientId != null) {
      await _chatController.sendMessage(_messageController.text.trim());
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null && patientId != null) {
        await _chatController.sendMessageWithImage(
          image: File(image.path),
          content: _messageController.text.trim().isNotEmpty
              ? _messageController.text.trim()
              : null,
        );
        _messageController.clear();

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اختيار الصورة');
    }
  }

  String _formatMessageTime(DateTime localTime) {
    final hour = localTime.hour;
    final minute = localTime.minute.toString().padLeft(2, '0');

    int displayHour;
    String period;

    if (hour == 0) {
      displayHour = 12;
      period = 'صباحاً';
    } else if (hour < 12) {
      displayHour = hour;
      period = 'صباحاً';
    } else if (hour == 12) {
      displayHour = 12;
      period = 'مساءً';
    } else {
      displayHour = hour - 12;
      period = 'مساءً';
    }

    return '$displayHour:$minute $period';
  }

  Widget _buildMessageBubble({
    required MessageModel message,
    required bool isSent,
    required String time,
  }) {
    final imageUrl = message.imageUrl;
    final validImageUrl = imageUrl != null && imageUrl.isNotEmpty
        ? ImageUtils.convertToValidUrl(imageUrl)
        : null;
    final hasImage =
        validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl);
    final hasText = message.message.isNotEmpty;

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
          Container(
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
              border: isSent || hasImage
                  ? null
                  : Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  color: (isSent ? _navy : Colors.black)
                      .withValues(alpha: isSent ? 0.18 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                      message.message,
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
                    final isSending =
                        _chatController.sendingMessageIds.contains(message.id);
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
                      return Icon(Icons.done_all, size: 14.sp, color: _navy);
                    }
                    return Icon(Icons.done, size: 14.sp, color: _grayText);
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
