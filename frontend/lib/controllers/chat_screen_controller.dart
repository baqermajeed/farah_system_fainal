import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/chat_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';

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

  String? patientId;
  String? doctorId;
  String? doctorName;
  int _lastMessageCount = 0;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    patientId = args?['patientId'];
    doctorId = args?['doctorId'];
    doctorName = args?['doctorName'];

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

  @override
  void onClose() {
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
      return patient?.name ?? 'مريض';
    }
    return 'محادثة';
  }

  String? doctorImageUrl() {
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

  /// Called while building the message list; scrolls to bottom whenever a
  /// new message shows up (mirrors previous StatefulWidget behavior).
  void onMessagesRendered() {
    if (chatController.messages.length != _lastMessageCount) {
      _lastMessageCount = chatController.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    }
  }

  Future<void> sendMessage() async {
    if (messageController.text.trim().isNotEmpty && patientId != null) {
      await chatController.sendMessage(messageController.text.trim());
      messageController.clear();
      scrollToBottom();
    }
  }

  Future<void> pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null && patientId != null) {
        await chatController.sendMessageWithImage(
          image: File(image.path),
          content: messageController.text.trim().isNotEmpty
              ? messageController.text.trim()
              : null,
        );
        messageController.clear();
        scrollToBottom();
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اختيار الصورة');
    }
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
}
