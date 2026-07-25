import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/services/chat_service.dart';

/// Controller لشاشة الرئيسية للطبيب — منطق البحث، الرسائل غير المقروءة، والتنقل خارج الـ View (نمط GetX MVC).
class DoctorHomeController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final ChatService chatService = ChatService();
  final RxMap<String, int> unreadCounts = <String, int>{}.obs;
  final RxList<AppointmentModel> todayAppointments = <AppointmentModel>[].obs;
  final RxBool isLoadingAppointments = false.obs;
  bool _dashboardLoading = false;

  AuthController get _authController => Get.find<AuthController>();
  PatientController get _patientController => Get.find<PatientController>();
  AppointmentController get _appointmentController =>
      Get.find<AppointmentController>();

  RxBool get isLoading => _patientController.isLoading;

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'مساء الخير';
    return 'مساء الخير';
  }

  String get doctorDisplayName {
    final name = _authController.currentUser.value?.name ?? 'دكتور';
    return name.startsWith('د.') ? name : 'د. $name';
  }

  @override
  void onReady() {
    super.onReady();
    final userType = _authController.currentUser.value?.userType;
    if (userType != 'doctor') {
      print('⚠️ [DoctorHomeController] User is not a doctor: $userType');
      return;
    }

    // تأجيل التحميل بعد أول إطار لتجنب تعليق الواجهة عند الانتقال من السبلاش
    SchedulerBinding.instance.addPostFrameCallback((_) {
      loadDashboard();
    });
  }

  /// التحميل الأولي — أول 25 مريض (pagination مثل desktop).
  Future<void> loadDashboard() async {
    if (_dashboardLoading) return;
    _dashboardLoading = true;
    try {
      await Future.wait([
        if (_patientController.patients.isEmpty)
          _patientController.loadPatients(isInitial: true, isRefresh: false),
        loadUnreadCounts(),
        loadTodayAppointments(),
      ]);
    } finally {
      _dashboardLoading = false;
    }
  }

  /// سحب للتحديث — إعادة جلب الصفحة الأولى.
  Future<void> refreshDashboard() async {
    if (_dashboardLoading) return;
    _dashboardLoading = true;
    try {
      await Future.wait([
        // لا نعيد تحميل المرضى هنا لتجنب الضغط المزدوج عند التنقل.
        // شاشة "جميع المرضى" مسؤولة عن pagination الخاص بها.
        loadUnreadCounts(),
        loadTodayAppointments(),
      ]);
    } finally {
      _dashboardLoading = false;
    }
  }

  Future<void> loadTodayAppointments() async {
    try {
      isLoadingAppointments.value = true;
      await _appointmentController.loadDoctorAppointments(
        day: 'today',
        limit: 50,
      );
      final now = DateTime.now();
      todayAppointments.assignAll(
        _appointmentController.appointments.where((a) {
          return a.date.year == now.year &&
              a.date.month == now.month &&
              a.date.day == now.day;
        }).toList(),
      );
      todayAppointments.sort((a, b) => a.time.compareTo(b.time));
    } catch (e) {
      print('❌ [DoctorHomeController] Error loading today appointments: $e');
    } finally {
      isLoadingAppointments.value = false;
    }
  }

  PatientModel? patientForAppointment(AppointmentModel appointment) {
    try {
      return _patientController.patients
          .firstWhere((p) => p.id == appointment.patientId);
    } catch (_) {
      return null;
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// آخر 8 مرضى للعرض في الرئيسية — بدون ترتيب القائمة كاملة (السيرفر يرجّع الأحدث أولاً).
  List<PatientModel> get recentPatients {
    final pc = _patientController;
    final source = pc.lastSearchQuery.value.trim().isNotEmpty
        ? pc.searchResults
        : pc.patients;
    if (source.length <= 8) {
      return source.toList(growable: false);
    }
    return source.take(8).toList(growable: false);
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

  List<PatientModel> get filteredPatients => recentPatients;

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
