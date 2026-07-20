import 'package:get/get.dart';

import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';
import 'package:farah_sys_final/services/chat_service.dart';

/// Controller لشاشة قائمة محادثات الطبيب — يملك حالة القائمة الخاصة بهذه
/// الشاشة (chat list summaries)، بينما محادثة فردية تُدار عبر ChatController.
class DoctorChatsScreenController extends GetxController {
  final ChatService _chatService = ChatService();

  final RxList<Map<String, dynamic>> chatList = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadChatList();
  }

  Future<void> loadChatList() async {
    try {
      isLoading.value = true;
      final list = await _chatService.getChatList();
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

  Future<void> openChat(String? patientId) async {
    await Get.toNamed(AppRoutes.chat, arguments: {'patientId': patientId});
    // Reload chat list when returning from chat.
    // Add small delay to ensure messages are marked as read.
    await Future.delayed(const Duration(milliseconds: 300));
    loadChatList();
  }
}
