import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/services/chat_service.dart';
import 'package:farah_sys_final/services/notification_service.dart';

class _HomeAssets {
  static const moon = 'assets/icon/Moon.png';
  static const sun = 'assets/icon/sun.png';
}

/// Controller للشاشة الرئيسية للمريض — كل المنطق والحالة خارج الـ View.
class PatientHomeController extends GetxController {
  AuthController get authController => Get.find<AuthController>();
  PatientController get patientController => Get.find<PatientController>();
  AppointmentController get appointmentController =>
      Get.find<AppointmentController>();

  final ChatService chatService = ChatService();

  /// Unread chat messages keyed by doctor profile id.
  final RxMap<String, int> unreadByDoctorId = <String, int>{}.obs;
  final RxInt unreadNotificationsCount = 0.obs;
  final RxBool isInitialLoading = true.obs;

  int get totalUnreadMessages =>
      unreadByDoctorId.values.fold(0, (sum, count) => sum + count);

  bool hasHomeData() {
    return patientController.myProfile.value != null ||
        patientController.myDoctors.isNotEmpty ||
        appointmentController.appointments.isNotEmpty;
  }

  @override
  void onInit() {
    super.onInit();
    // Avoid full-screen loader flash when controllers already have data.
    isInitialLoading.value = !hasHomeData();
  }

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadData();
      listenForIncomingMessages();
    });
  }

  @override
  void onClose() {
    chatService.socketService.off('message_received', onIncomingChatMessage);
    super.onClose();
  }

  Future<void> loadData({bool showFullScreenLoader = true}) async {
    final showLoader = showFullScreenLoader && !hasHomeData();

    if (showLoader) {
      isInitialLoading.value = true;
    }

    try {
      await Future.wait([
        patientController.loadMyProfile().catchError((e) {
          debugPrint('❌ [PatientHomeController] Error loading profile: $e');
        }),
        appointmentController.loadPatientAppointments().catchError((e) {
          debugPrint(
            '❌ [PatientHomeController] Error loading appointments: $e',
          );
        }),
        patientController.loadMyDoctors().catchError((e) {
          debugPrint('❌ [PatientHomeController] Error loading doctors: $e');
        }),
        loadUnreadCount(),
      ]);
    } finally {
      isInitialLoading.value = false;
      await loadUnreadNotificationsCount();
    }
  }

  Future<void> onRefresh() async {
    await loadData(showFullScreenLoader: false);
    listenForIncomingMessages();
  }

  Future<void> loadUnreadCount() async {
    try {
      final chatList = await chatService.getChatList();
      final doctors = patientController.myDoctors;
      final unreadMap = <String, int>{};

      for (final chat in chatList) {
        final unreadCount = (chat['unread_count'] as num?)?.toInt() ?? 0;
        if (unreadCount <= 0) continue;

        String? doctorId = chat['doctor_id']?.toString();
        final doctorUserId = chat['doctor_user_id']?.toString();

        // Old API / legacy rooms: patient_name is the doctor display name.
        if ((doctorId == null || doctorId.isEmpty) && doctors.isNotEmpty) {
          final doctorName = (chat['patient_name'] ?? '').toString().trim();
          for (final doctor in doctors) {
            final name = (doctor['name'] ?? '').toString().trim();
            if (name.isNotEmpty && name == doctorName) {
              doctorId = doctor['id']?.toString();
              break;
            }
          }
        }

        if (doctorId != null && doctorId.isNotEmpty) {
          unreadMap[doctorId] = (unreadMap[doctorId] ?? 0) + unreadCount;
        }
        if (doctorUserId != null && doctorUserId.isNotEmpty) {
          unreadMap[doctorUserId] =
              (unreadMap[doctorUserId] ?? 0) + unreadCount;
        }
      }

      // Single-doctor fallback when ids/names couldn't be matched.
      if (unreadMap.isEmpty && doctors.length == 1) {
        final totalUnread = chatList.fold<int>(
          0,
          (sum, chat) => sum + ((chat['unread_count'] as num?)?.toInt() ?? 0),
        );
        final onlyId = doctors.first['id']?.toString();
        if (totalUnread > 0 && onlyId != null && onlyId.isNotEmpty) {
          unreadMap[onlyId] = totalUnread;
        }
      }

      unreadByDoctorId.assignAll(unreadMap);
      debugPrint(
        '📩 [PatientHomeController] Unread by doctor: $unreadMap (chats=${chatList.length})',
      );
    } catch (e) {
      debugPrint('❌ [PatientHomeController] Error loading unread counts: $e');
      unreadByDoctorId.clear();
    }
  }

  void bumpUnreadForDoctor({String? doctorId, String? doctorUserId}) {
    if (doctorId != null && doctorId.isNotEmpty) {
      unreadByDoctorId[doctorId] = (unreadByDoctorId[doctorId] ?? 0) + 1;
    }
    if (doctorUserId != null &&
        doctorUserId.isNotEmpty &&
        doctorUserId != doctorId) {
      unreadByDoctorId[doctorUserId] =
          (unreadByDoctorId[doctorUserId] ?? 0) + 1;
    }
    unreadByDoctorId.refresh();
    unreadNotificationsCount.value = unreadNotificationsCount.value + 1;
  }

  void onIncomingChatMessage(dynamic data) {
    try {
      final messageData = data is Map && data['message'] is Map
          ? Map<String, dynamic>.from(data['message'] as Map)
          : (data is Map ? Map<String, dynamic>.from(data) : null);
      if (messageData == null) return;

      final senderRole = messageData['sender_role']?.toString().toLowerCase();
      if (senderRole != 'doctor') return;

      final myUserId = authController.currentUser.value?.id;
      final receiverId = messageData['receiver_id']?.toString();
      if (myUserId != null &&
          receiverId != null &&
          receiverId.isNotEmpty &&
          receiverId != myUserId) {
        return;
      }

      var doctorId = messageData['doctor_id']?.toString();
      final doctorUserId = messageData['doctor_user_id']?.toString() ??
          messageData['sender_user_id']?.toString();

      if ((doctorId == null || doctorId.isEmpty) && doctorUserId != null) {
        for (final doctor in patientController.myDoctors) {
          if (doctor['user_id']?.toString() == doctorUserId) {
            doctorId = doctor['id']?.toString();
            break;
          }
        }
      }

      // Don't badge while the patient is already inside a chat screen.
      if (Get.currentRoute == AppRoutes.chat) {
        return;
      }

      bumpUnreadForDoctor(doctorId: doctorId, doctorUserId: doctorUserId);
    } catch (e) {
      debugPrint(
        '❌ [PatientHomeController] Error handling incoming chat message: $e',
      );
    }
  }

  void listenForIncomingMessages() {
    final socket = chatService.socketService;
    // Remove only this screen's handler to avoid duplicates, keep ChatController's.
    socket.off('message_received', onIncomingChatMessage);
    socket.on('message_received', onIncomingChatMessage);
  }

  Future<void> loadUnreadNotificationsCount() async {
    try {
      final count = await NotificationService().getUnreadCount();
      unreadNotificationsCount.value = count;
    } catch (e) {
      debugPrint(
        '❌ [PatientHomeController] Error loading notification unread count: $e',
      );
      unreadNotificationsCount.value = 0;
    }
  }

  bool get isMorning => DateTime.now().hour < 12;

  String greeting() {
    if (isMorning) return 'صبــاح الخــير';
    return 'مساء الخير';
  }

  String greetingIcon() => isMorning ? _HomeAssets.sun : _HomeAssets.moon;

  /// رسائل اليوم — تتغير مع بداية كل يوم جديد (بعد 12:00 منتصف الليل)
  static const List<String> _dailyMessages = [
    'اليوم بداية ابتسامة جديدة',
    'عنايتك تصنع فرقًا دائمًا',
    'اسنان صحية لحياة سعيدة',
    'ابدأ يومك بابتسامة مشرقة',
    'ثقتك تبدأ بابتسامتك الجميلة',
    'العناية تصنع ابتسامة تدوم',
    'صحتك الفموية أولويتنا دائمًا',
    'كل موعد خطوة للأفضل',
    'لأن ابتسامتك تستحق الأفضل',
    'أسنان أقوى ابتسامة أجمل',
    'جمالك يبدأ بابتسامتك دائمًا',
  ];

  /// كلمتان في السطر الأول والباقي في السطر الثاني
  (String line1, String line2) dailyMessageLines() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayIndex = today.difference(DateTime(2020, 1, 1)).inDays.abs();
    final message = _dailyMessages[dayIndex % _dailyMessages.length];
    final words = message.trim().split(RegExp(r'\s+'));

    if (words.length <= 2) {
      return (message, '');
    }

    return (
      words.take(2).join(' '),
      words.skip(2).join(' '),
    );
  }
}
