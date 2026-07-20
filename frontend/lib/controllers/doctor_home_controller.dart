import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/services/chat_service.dart';

/// Controller لشاشة الرئيسية للطبيب — منطق البحث، الرسائل غير المقروءة، والتنقل خارج الـ View (نمط GetX MVC).
class DoctorHomeController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final ChatService chatService = ChatService();
  final RxMap<String, int> unreadCounts = <String, int>{}.obs;

  AuthController get _authController => Get.find<AuthController>();
  PatientController get _patientController => Get.find<PatientController>();

  RxBool get isLoading => _patientController.isLoading;

  @override
  void onReady() {
    super.onReady();
    final userType = _authController.currentUser.value?.userType;
    if (userType == 'doctor') {
      print('🏥 [DoctorHomeController] Loading patients for doctor...');
      _patientController.loadPatients();
    } else {
      print('⚠️ [DoctorHomeController] User is not a doctor: $userType');
    }
    loadUnreadCounts();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  // Extract MongoDB ObjectId timestamp (first 8 hex chars = seconds since epoch).
  int objectIdSeconds(String id) {
    if (id.length < 8) return 0;
    return int.tryParse(id.substring(0, 8), radix: 16) ?? 0;
  }

  List<PatientModel> sortNewestFirst(Iterable<PatientModel> patients) {
    final list = patients.toList(growable: false);
    final sorted = List<PatientModel>.from(list);
    sorted.sort(
      (a, b) => objectIdSeconds(b.id).compareTo(objectIdSeconds(a.id)),
    );
    return sorted;
  }

  Future<void> loadUnreadCounts() async {
    try {
      final chatList = await chatService.getChatList();
      final unreadMap = <String, int>{};
      for (var chat in chatList) {
        final patientId = chat['patient_id']?.toString();
        final unreadCount = chat['unread_count'] as int? ?? 0;
        if (patientId != null) {
          unreadMap[patientId] = unreadCount;
        }
      }
      unreadCounts.value = unreadMap;
    } catch (e) {
      print('❌ [DoctorHomeController] Error loading unread counts: $e');
    }
  }

  int get totalUnreadCount {
    return unreadCounts.values.fold(0, (sum, count) => sum + count);
  }

  List<PatientModel> get filteredPatients {
    final raw = searchQuery.value.isEmpty
        ? _patientController.patients
        : _patientController.searchPatients(searchQuery.value);
    return sortNewestFirst(raw);
  }

  void openPatient(PatientModel patient) {
    _patientController.selectPatient(patient);
    Get.toNamed(
      AppRoutes.patientDetails,
      arguments: {'patientId': patient.id},
    );
  }

  Future<void> openChatsAndRefresh() async {
    await Get.toNamed(AppRoutes.doctorChats);
    // Reload unread counts when returning from chats screen.
    // Small delay to ensure messages are marked as read.
    await Future.delayed(const Duration(milliseconds: 300));
    loadUnreadCounts();
  }

  Future<void> openPatientChatAndRefresh(String patientId) async {
    await Get.toNamed(AppRoutes.chat, arguments: {'patientId': patientId});
    // Reload unread counts when returning from chat.
    // Small delay to ensure messages are marked as read.
    await Future.delayed(const Duration(milliseconds: 300));
    loadUnreadCounts();
  }
}
