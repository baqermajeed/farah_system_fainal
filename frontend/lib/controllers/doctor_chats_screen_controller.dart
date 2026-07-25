import 'package:get/get.dart';

import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';
import 'package:farah_sys_final/core/utils/date_time_utils.dart';
import 'package:farah_sys_final/services/chat_service.dart';

enum ChatReadFilter { all, read, unread }

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
        list = list.where((item) => _unreadCount(item) == 0);
        break;
      case ChatReadFilter.unread:
        list = list.where((item) => _unreadCount(item) > 0);
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
      chatList.where((item) => _unreadCount(item) > 0).length;

  void setReadFilter(ChatReadFilter filter) {
    readFilter.value = filter;
  }

  int _unreadCount(Map<String, dynamic> item) =>
      (item['unread_count'] as int?) ?? 0;

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
