import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/chat_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/presence_controller.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/models/message_model.dart';

/// Controller لشاشة الدردشة الفردية — يملك حالة الواجهة الخاصة بهذه الشاشة
/// (حقل النص، التمرير، اختيار الصور)، بينما يفوّض تحميل/إرسال الرسائل
/// والاتصال بالـ socket إلى ChatController المشترك (permanent).
class ChatScreenController extends GetxController {
  ChatController get chatController => Get.find<ChatController>();
  AuthController get authController => Get.find<AuthController>();
  PatientController get patientController => Get.find<PatientController>();

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final Rxn<MessageModel> replyingTo = Rxn<MessageModel>();
  final Rxn<MessageModel> editingMessage = Rxn<MessageModel>();
  final Rxn<File> pendingImage = Rxn<File>();
  final RxString highlightedMessageId = ''.obs;

  String? patientId;
  String? patientNameArg;
  String? patientImageUrlArg;
  String? doctorId;
  String? doctorName;
  String? doctorUserId;
  int _lastMessageCount = 0;
  bool _loadingOlder = false;
  final Map<String, GlobalKey> _messageKeys = {};
  Timer? _highlightTimer;
  static final RegExp _replyMetaRegex = RegExp(
    r'^\[reply:([^:\]]+)::([^\]]*)\]\n',
  );
  static final RegExp _replyImageMetaRegex = RegExp(
    r'^\[reply_image:([^\]]*)\]\n',
  );

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    patientId = args?['patientId'];
    patientNameArg = args?['patientName']?.toString();
    patientImageUrlArg = args?['patientImageUrl']?.toString();
    doctorId = args?['doctorId'];
    doctorName = args?['doctorName'];
    doctorUserId = args?['doctorUserId']?.toString();

    scrollController.addListener(_onScroll);

    // Clear previous conversation before first frame to avoid flash of old/empty chat.
    if (patientId != null) {
      chatController.prepareConversation(
        patientId: patientId!,
        doctorId: doctorId,
      );
    }
  }

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (authController.currentUser.value?.userType == 'patient') {
        if (patientController.myDoctors.isEmpty) {
          await patientController.loadMyDoctors();
        }
        _resolveDoctorUserId();
      }
      if (patientId != null) {
        try {
          await chatController.openChat(
            patientId: patientId!,
            doctorId: doctorId,
          );
          _lastMessageCount = chatController.messages.length;
          await Future.delayed(const Duration(milliseconds: 300));
          scrollToBottom();
        } catch (e) {
          debugPrint('❌ [ChatScreenController] Error initializing chat: $e');
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

  void _resolveDoctorUserId() {
    if (doctorUserId != null && doctorUserId!.isNotEmpty) return;
    for (final doctor in patientController.myDoctors) {
      final id = doctor['id']?.toString();
      if (doctorId != null && id == doctorId) {
        doctorUserId = doctor['user_id']?.toString();
        return;
      }
    }
    doctorUserId = patientController.myDoctor.value?['user_id']?.toString();
  }

  /// هل نظهر حالة الاتصال؟ (للمريض فقط تجاه الطبيب)
  bool get showsDoctorPresence {
    return authController.currentUser.value?.userType.toLowerCase() ==
        'patient';
  }

  /// حالة الطبيب الحقيقية من PresenceController.
  bool get isDoctorOnline {
    final userId = doctorUserId;
    if (userId == null || userId.isEmpty) return false;
    if (!Get.isRegistered<PresenceController>()) return false;
    // قراءة الـ RxSet لتفعيل Obx
    Get.find<PresenceController>().onlineDoctorUserIds.length;
    return Get.find<PresenceController>().isDoctorOnline(userId);
  }

  @override
  void onClose() {
    chatController.stopTyping();
    _highlightTimer?.cancel();
    _messageKeys.clear();
    clearPendingImage();
    messageController.dispose();
    scrollController.dispose();
    chatController.disconnect();
    super.onClose();
  }

  String displayName() {
    final currentUser = authController.currentUser.value;
    final currentUserType = currentUser?.userType.toLowerCase();

    if (currentUserType == 'patient') {
      final name = doctorName ?? 'طبيب';
      return name.startsWith('د.') ? name : 'د. $name';
    }
    if (patientId != null) {
      final patient = patientController.getPatientById(patientId!);
      final fallback = patientNameArg?.trim();
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return patient?.name ?? 'مريض';
    }
    return 'محادثة';
  }

  String? doctorImageUrl() {
    final currentUserType =
        authController.currentUser.value?.userType.toLowerCase();
    if (currentUserType == 'doctor') {
      if (patientId != null) {
        final patient = patientController.getPatientById(patientId!);
        final modelUrl = ImageUtils.convertToValidUrl(patient?.imageUrl);
        if (modelUrl != null && modelUrl.isNotEmpty) return modelUrl;
      }
      return ImageUtils.convertToValidUrl(patientImageUrlArg);
    }

    for (final doctor in patientController.myDoctors) {
      final id = doctor['id']?.toString();
      if (doctorId != null && id == doctorId) {
        return ImageUtils.convertToValidUrl(doctor['imageUrl']);
      }
    }
    return ImageUtils.convertToValidUrl(
      patientController.myDoctor.value?['imageUrl'],
    );
  }

  String todayLabel() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'مساءً' : 'صباحاً';
    return 'اليوم، $displayHour:$minute $period';
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final pos = scrollController.position;
    // reverse:true → أعلى المحادثة = maxScrollExtent
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      _loadOlderIfNeeded();
    }
  }

  Future<void> _loadOlderIfNeeded() async {
    if (_loadingOlder) return;
    if (!chatController.hasMoreMessages.value) return;
    if (chatController.isLoadingMore.value || chatController.isLoading.value) {
      return;
    }

    _loadingOlder = true;
    try {
      await chatController.loadOlderMessages();
    } finally {
      _loadingOlder = false;
    }
  }

  /// Called while building the message list; scrolls to bottom whenever a
  /// new message shows up (not when loading older pages).
  void onMessagesRendered() {
    if (chatController.isLoadingMore.value) {
      _lastMessageCount = chatController.messages.length;
      return;
    }
    if (chatController.messages.length != _lastMessageCount) {
      _lastMessageCount = chatController.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    }
  }

  Future<void> sendMessage() async {
    if (patientId == null) return;

    final raw = messageController.text.trim();
    final editing = editingMessage.value;
    final image = pendingImage.value;

    if (editing != null) {
      if (raw.isEmpty) return;
      await chatController.editMessage(
        messageId: editing.id,
        newContent: buildEditedText(editing, raw),
      );
      messageController.clear();
      cancelEditing();
      scrollToBottom();
      return;
    }

    if (image != null) {
      final payload = raw.isNotEmpty ? buildOutgoingText(raw) : null;
      await chatController.sendMessageWithImage(
        image: image,
        content: payload,
      );
      messageController.clear();
      clearPendingImage();
      clearReply();
      scrollToBottom();
      return;
    }

    if (raw.isEmpty) return;

    final payload = buildOutgoingText(raw);
    await chatController.sendMessage(payload);
    messageController.clear();
    clearReply();
    scrollToBottom();
  }

  Future<void> pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        pendingImage.value = File(image.path);
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اختيار الصورة');
    }
  }

  void clearPendingImage() {
    pendingImage.value = null;
  }

  String formatMessageTime(DateTime localTime) {
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

  void onComposerChanged(String value) {
    chatController.onComposerTextChanged(value);
  }

  void setReply(MessageModel message) {
    editingMessage.value = null;
    replyingTo.value = message;
  }

  void clearReply() {
    replyingTo.value = null;
  }

  void startEditing(MessageModel message) {
    replyingTo.value = null;
    clearPendingImage();
    editingMessage.value = message;
    messageController.text = extractForwardText(message);
    messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: messageController.text.length),
    );
  }

  void cancelEditing() {
    editingMessage.value = null;
  }

  GlobalKey messageKey(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  void cleanupMessageKeys(Iterable<String> activeMessageIds) {
    final keep = activeMessageIds.toSet();
    _messageKeys.removeWhere((id, _) => !keep.contains(id));
  }

  MessageModel? findMessageById(String messageId) {
    try {
      return chatController.messages.firstWhere((m) => m.id == messageId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> scrollToMessageById(String messageId) async {
    for (var i = 0; i < 5; i++) {
      final key = _messageKeys[messageId];
      final context = key?.currentContext;
      if (context != null) {
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.45,
        );

        highlightedMessageId.value = messageId;
        _highlightTimer?.cancel();
        _highlightTimer = Timer(const Duration(seconds: 2), () {
          if (highlightedMessageId.value == messageId) {
            highlightedMessageId.value = '';
          }
        });
        return true;
      }

      final hasTargetInLoadedList =
          chatController.messages.any((m) => m.id == messageId);
      if (hasTargetInLoadedList) {
        await _scrollNearLoadedMessage(messageId);
        await Future.delayed(const Duration(milliseconds: 140));
        continue;
      }

      if (!chatController.hasMoreMessages.value) break;
      await chatController.loadOlderMessages();
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return false;
  }

  Future<void> _scrollNearLoadedMessage(String messageId) async {
    if (!scrollController.hasClients) return;
    final total = chatController.messages.length;
    if (total <= 1) return;

    final logicalIndex =
        chatController.messages.indexWhere((m) => m.id == messageId);
    if (logicalIndex < 0) return;

    final reverseIndex = total - 1 - logicalIndex;
    final ratio = (reverseIndex / (total - 1)).clamp(0.0, 1.0);
    final maxExtent = scrollController.position.maxScrollExtent;
    final target = maxExtent * ratio;

    await scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> scrollToReplyTarget({
    required String? messageId,
    String? replySnippet,
    String? replyImageUrl,
  }) async {
    final id = messageId?.trim() ?? '';
    if (id.isNotEmpty) {
      final byId = await scrollToMessageById(id);
      if (byId) return true;
    }

    final normalizedReplyImage = _normalizeImageRef(replyImageUrl);
    final snippet = (replySnippet ?? '').trim();

    int score(MessageModel m) {
      var s = 0;
      if (snippet.isNotEmpty) {
        final text = extractForwardText(m).trim();
        if (text == snippet) s += 5;
        if (text.contains(snippet) || snippet.contains(text)) s += 3;
      }
      if (normalizedReplyImage.isNotEmpty) {
        final current = _normalizeImageRef(m.imageUrl);
        if (current.isNotEmpty && current == normalizedReplyImage) s += 6;
      }
      return s;
    }

    MessageModel? best;
    var bestScore = 0;
    for (var i = 0; i < 5; i++) {
      for (final m in chatController.messages) {
        final sc = score(m);
        if (sc > bestScore) {
          bestScore = sc;
          best = m;
        }
      }
      if (bestScore >= 5) break;
      if (!chatController.hasMoreMessages.value) break;
      await chatController.loadOlderMessages();
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (best != null && bestScore > 0) {
      return scrollToMessageById(best.id);
    }
    return false;
  }

  String _normalizeImageRef(String? raw) {
    if (raw == null) return '';
    final value = raw.trim();
    if (value.isEmpty) return '';
    final url = ImageUtils.convertToValidUrl(value) ?? value;
    final noQuery = url.split('?').first;
    final normalized = noQuery.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? normalized : parts.last.toLowerCase();
  }

  String buildOutgoingText(String content) {
    final base = content.trim();
    final reply = replyingTo.value;
    if (reply == null) return base;
    final snippet = _replySnippetFromMessage(reply);
    final safeSnippet = snippet.replaceAll(']', ')').replaceAll('\n', ' ');
    final imagePath = (reply.imageUrl ?? '').trim();
    final imageMeta = imagePath.isEmpty
        ? ''
        : '[reply_image:${Uri.encodeComponent(imagePath)}]\n';
    return '[reply:${reply.id}::$safeSnippet]\n$imageMeta$base';
  }

  String buildEditedText(MessageModel original, String newContent) {
    final base = newContent.trim();
    final parsed = parseMessage(original.message);
    final replyId = parsed.replyMessageId;
    if (replyId == null || replyId.isEmpty) return base;

    final snippet = (parsed.replySnippet ?? '').replaceAll(']', ')').replaceAll('\n', ' ');
    final imagePath = (parsed.replyImageUrl ?? '').trim();
    final imageMeta = imagePath.isEmpty
        ? ''
        : '[reply_image:${Uri.encodeComponent(imagePath)}]\n';
    return '[reply:$replyId::$snippet]\n$imageMeta$base';
  }

  ParsedChatMessage parseMessage(String raw) {
    var input = raw;
    final match = _replyMetaRegex.firstMatch(input);
    if (match == null) {
      return ParsedChatMessage(
        text: raw,
        replyMessageId: null,
        replySnippet: null,
        replyImageUrl: null,
      );
    }
    final replyId = match.group(1);
    final snippet = match.group(2);
    input = input.substring(match.end);

    String? replyImageUrl;
    final imageMatch = _replyImageMetaRegex.firstMatch(input);
    if (imageMatch != null) {
      final encoded = imageMatch.group(1);
      if (encoded != null && encoded.isNotEmpty) {
        try {
          replyImageUrl = Uri.decodeComponent(encoded);
        } catch (_) {
          replyImageUrl = encoded;
        }
      }
      input = input.substring(imageMatch.end);
    }

    final text = input.trimLeft();
    return ParsedChatMessage(
      text: text,
      replyMessageId: replyId,
      replySnippet: (snippet == null || snippet.isEmpty) ? null : snippet,
      replyImageUrl: replyImageUrl,
    );
  }

  String _replySnippetFromMessage(MessageModel message) {
    final parsed = parseMessage(message.message);
    final clean = parsed.text.trim();
    if (clean.isNotEmpty) {
      if (clean.length <= 45) return clean;
      return '${clean.substring(0, 45)}...';
    }
    if ((message.imageUrl ?? '').isNotEmpty) {
      return 'صورة';
    }
    return 'رسالة';
  }

  String extractForwardText(MessageModel message) {
    final parsed = parseMessage(message.message);
    return parsed.text.trim();
  }

}

class ParsedChatMessage {
  ParsedChatMessage({
    required this.text,
    required this.replyMessageId,
    required this.replySnippet,
    required this.replyImageUrl,
  });

  final String text;
  final String? replyMessageId;
  final String? replySnippet;
  final String? replyImageUrl;
}
