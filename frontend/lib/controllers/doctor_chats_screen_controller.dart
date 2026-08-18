import 'package:get/get.dart';

import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';
import 'package:farah_sys_final/core/utils/date_time_utils.dart';
import 'package:farah_sys_final/services/chat_service.dart';

enum ChatReadFilter { all, read, unread }

int chatUnreadCount(Map<String, dynamic> item) {
  final value = item['unread_count'];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Controller لشاشة قائمة محادثات الطبيب — يملك حالة القائمة الخاصة بهذه
/// الشاشة (chat list summaries)، بينما محادثة فردية تُدار عبر ChatController.
class DoctorChatsScreenController extends GetxController {
  final ChatService _chatService = ChatService();

  final RxList<Map<String, dynamic>> chatList = <Map<String, dynamic>>[].obs;
  final RxString searchQuery = ''.obs;
  final Rx<ChatReadFilter> readFilter = ChatReadFilter.all.obs;
  final RxBool isLoading = true.obs;

  List<Map<String, dynamic>> get filteredChatList {
    Iterable<Map<String, dynamic>> list = chatList;

    switch (readFilter.value) {
      case ChatReadFilter.read:
        list = list.where((item) => chatUnreadCount(item) == 0);
        break;
      case ChatReadFilter.unread:
        list = list.where((item) => chatUnreadCount(item) > 0);
        break;
      case ChatReadFilter.all:
        break;
    }

    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return list.toList();
    return list.where((item) {
      final name = (item['patient_name'] ?? '').toString().toLowerCase();
      final last = (item['last_message'] ?? '').toString().toLowerCase();
      return name.contains(query) || last.contains(query);
    }).toList();
  }

  int get unreadChatsCount =>
      chatList.where((item) => chatUnreadCount(item) > 0).length;

  void setReadFilter(ChatReadFilter filter) {
    readFilter.value = filter;
  }

  @override
  void onReady() {
    super.onReady();
    if (chatList.isEmpty) {
      loadChatList();
    }
  }

  Future<void> loadChatList() async {
    try {
      isLoading.value = true;
      final list = await _chatService.getChatList();
      list.sort(_sortByLatestMessageDesc);
      chatList.value = list;
    } on ApiException catch (e) {
      await NetworkUtils.showError(e);
    } catch (e) {
      await NetworkUtils.showError(
        e,
        fallbackMessage: 'حدث خطأ أثناء تحميل المحادثات',
      );
    } finally {
      isLoading.value = false;
    }
  }

  int _sortByLatestMessageDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aTime = _parseMessageTime(a['last_message_time']?.toString());
    final bTime = _parseMessageTime(b['last_message_time']?.toString());
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  }

  DateTime? _parseMessageTime(String? raw) {
    return DateTimeUtils.parseApiToLocal(raw);
  }

  void onIncomingChatMessage(dynamic data) {
    try {
      final messageData = data is Map && data['message'] is Map
          ? Map<String, dynamic>.from(data['message'] as Map)
          : (data is Map ? Map<String, dynamic>.from(data) : null);
      if (messageData == null) return;

      if (Get.isRegistered<AuthController>()) {
        final myId = Get.find<AuthController>().currentUser.value?.id;
        final senderId = messageData['sender_user_id']?.toString();
        if (myId != null && senderId != null && senderId == myId) return;
      }

      final senderRole = messageData['sender_role']?.toString().toLowerCase();
      if (senderRole == 'doctor') return;

      final patientId = messageData['patient_id']?.toString();
      final roomId = messageData['room_id']?.toString();
      final imageUrl = messageData['imageUrl']?.toString();
      final content = (messageData['content'] ?? messageData['message'] ?? '')
          .toString()
          .trim();
      final lastMessage = imageUrl != null && imageUrl.isNotEmpty
          ? 'صورة'
          : (content.isEmpty ? 'رسالة جديدة' : content);
      final time = messageData['created_at']?.toString();

      final index = chatList.indexWhere((item) {
        final itemRoom = item['room_id']?.toString();
        final itemPatient = item['patient_id']?.toString();
        if (roomId != null && roomId.isNotEmpty && itemRoom == roomId) {
          return true;
        }
        return patientId != null &&
            patientId.isNotEmpty &&
            itemPatient == patientId;
      });

      if (index < 0) {
        loadChatList();
        return;
      }

      final updated = Map<String, dynamic>.from(chatList[index]);
      updated['unread_count'] = chatUnreadCount(updated) + 1;
      updated['last_message'] = lastMessage;
      if (time != null && time.isNotEmpty) {
        updated['last_message_time'] = time;
      }
      chatList.removeAt(index);
      chatList.insert(0, updated);
    } catch (_) {}
  }

  Future<void> openChat(
    String? patientId, {
    String? patientName,
    String? patientImageUrl,
  }) async {
    await Get.toNamed(
      AppRoutes.chat,
      arguments: {
        'patientId': patientId,
        'patientName': patientName,
        'patientImageUrl': patientImageUrl,
      },
    );
    // Reload chat list when returning from chat.
    // Add small delay to ensure messages are marked as read.
    await Future.delayed(const Duration(milliseconds: 300));
    loadChatList();
  }
}
