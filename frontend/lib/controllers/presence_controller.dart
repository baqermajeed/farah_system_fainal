import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:farah_sys_final/controllers/chat_controller.dart';
import 'package:farah_sys_final/models/user_model.dart';
import 'package:farah_sys_final/services/presence_api_service.dart';

/// يتتبع الأطباء المتصلين حالياً (التطبيق مفتوح) — مثل frontend_desktop.
///
/// - الطبيب: يرسل heartbeat دوري + يستمع للـ Socket
/// - المريض/الموظف: يستطلع قائمة المتصلين + Socket
class PresenceController extends GetxController {
  final PresenceApiService _presenceApi = PresenceApiService();
  final RxSet<String> _onlineDoctorUserIds = <String>{}.obs;

  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  String? _activeRole;
  bool _heartbeatInFlight = false;
  bool _pollInFlight = false;
  bool _socketHooksAttached = false;

  static const Duration _heartbeatInterval = Duration(seconds: 25);
  static const Duration _pollInterval = Duration(seconds: 20);

  /// يُستخدم من Obx لمراقبة تغيّر القائمة.
  RxSet<String> get onlineDoctorUserIds => _onlineDoctorUserIds;

  bool isDoctorOnline(String userId) {
    if (userId.isEmpty) return false;
    return _onlineDoctorUserIds.contains(userId);
  }

  @override
  void onInit() {
    super.onInit();
    // اربط مستمعي الـ Socket مبكراً حتى لا تفوت presence_snapshot عند الاتصال
    _attachSocketHooks();
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }

  bool _shouldTrackPresence(UserModel user) {
    final type = user.userType.toLowerCase();
    return type == 'doctor' ||
        type == 'receptionist' ||
        type == 'patient';
  }

  Future<void> connectForUser(UserModel user) async {
    if (!_shouldTrackPresence(user)) {
      disconnect();
      return;
    }

    _activeRole = user.userType.toLowerCase();
    _attachSocketHooks();
    _startHttpPresence();
  }

  void _attachSocketHooks() {
    if (_socketHooksAttached) return;
    if (!Get.isRegistered<ChatController>()) return;

    final socket = Get.find<ChatController>().chatServiceSocket;
    socket.onPresenceChanged = _handlePresenceChanged;
    socket.onPresenceSnapshot = _handlePresenceSnapshot;
    _socketHooksAttached = true;
  }

  void _startHttpPresence() {
    _heartbeatTimer?.cancel();
    _pollTimer?.cancel();

    if (_activeRole == 'doctor') {
      unawaited(_sendHeartbeat());
      _heartbeatTimer = Timer.periodic(
        _heartbeatInterval,
        (_) => unawaited(_sendHeartbeat()),
      );
    }

    unawaited(_pollOnlineDoctors());
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_pollOnlineDoctors()),
    );
  }

  Future<void> _sendHeartbeat() async {
    if (_heartbeatInFlight || _activeRole != 'doctor') return;
    _heartbeatInFlight = true;
    try {
      await _presenceApi.sendHeartbeat();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PresenceController] Heartbeat failed: $e');
      }
    } finally {
      _heartbeatInFlight = false;
    }
  }

  Future<void> _pollOnlineDoctors() async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    try {
      final ids = await _presenceApi.fetchOnlineDoctorUserIds();
      _handlePresenceSnapshot(ids);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PresenceController] Online poll failed: $e');
      }
    } finally {
      _pollInFlight = false;
    }
  }

  /// بذرة من REST (مثل قائمة أطباء المريض) — إضافة فقط.
  void seedFromDoctors(Iterable<Map<String, dynamic>> doctors) {
    var changed = false;
    for (final doctor in doctors) {
      final online = doctor['is_online'] == true || doctor['isOnline'] == true;
      final userId =
          doctor['user_id']?.toString() ?? doctor['userId']?.toString() ?? '';
      if (online && userId.isNotEmpty) {
        if (_onlineDoctorUserIds.add(userId)) {
          changed = true;
        }
      }
    }
    if (changed) {
      _onlineDoctorUserIds.refresh();
    }
  }

  void _handlePresenceSnapshot(List<String> onlineUserIds) {
    final next = onlineUserIds.where((id) => id.isNotEmpty).toSet();
    if (next.length == _onlineDoctorUserIds.length &&
        next.containsAll(_onlineDoctorUserIds)) {
      return;
    }
    _onlineDoctorUserIds
      ..clear()
      ..addAll(next);
    _onlineDoctorUserIds.refresh();
  }

  void _handlePresenceChanged(String userId, bool isOnline) {
    if (userId.isEmpty) return;
    if (isOnline) {
      _onlineDoctorUserIds.add(userId);
    } else {
      _onlineDoctorUserIds.remove(userId);
    }
    _onlineDoctorUserIds.refresh();
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _pollTimer?.cancel();
    _heartbeatTimer = null;
    _pollTimer = null;
    _activeRole = null;
    _onlineDoctorUserIds.clear();
    _onlineDoctorUserIds.refresh();
    // أبقِ مستمعي الـ Socket مربوطين لإعادة الاستخدام بعد تسجيل الدخول التالي
  }
}
