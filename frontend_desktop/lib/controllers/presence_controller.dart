import 'dart:async';

import 'package:get/get.dart';
import 'package:frontend_desktop/models/doctor_model.dart';
import 'package:frontend_desktop/models/user_model.dart';
import 'package:frontend_desktop/services/presence_api_service.dart';
import 'package:frontend_desktop/services/socket_service.dart';

/// Tracks which doctors are currently online (desktop app open).
///
/// Primary path: HTTP heartbeat + polling (works when nginx blocks WebSocket).
/// Optional path: Socket.IO events when the proxy upgrade works.
class PresenceController extends GetxController {
  final SocketService _socketService = SocketService();
  final PresenceApiService _presenceApi = PresenceApiService();
  final RxSet<String> _onlineDoctorUserIds = <String>{}.obs;

  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  String? _activeRole;
  bool _heartbeatInFlight = false;
  bool _pollInFlight = false;

  static const Duration _heartbeatInterval = Duration(seconds: 25);
  static const Duration _pollInterval = Duration(seconds: 20);

  bool isDoctorOnline(String userId) => _onlineDoctorUserIds.contains(userId);

  @override
  void onInit() {
    super.onInit();
    _socketService.onPresenceChanged = _handlePresenceChanged;
    _socketService.onPresenceSnapshot = _handlePresenceSnapshot;
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }

  bool _shouldMaintainConnection(UserModel user) {
    final type = user.userType.toLowerCase();
    return type == 'doctor' || type == 'receptionist';
  }

  Future<void> connectForUser(UserModel user) async {
    if (!_shouldMaintainConnection(user)) {
      disconnect();
      return;
    }

    _activeRole = user.userType.toLowerCase();
    _startHttpPresence();

    // Socket is optional — nginx currently rejects WebSocket upgrades.
    unawaited(_socketService.connect().then((ok) {
      if (!ok) {
        print(
          '⚠️ [PresenceController] Socket unavailable; using HTTP presence',
        );
      }
    }));
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

    // Reception and doctors both need the online roster.
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
      print('⚠️ [PresenceController] Heartbeat failed: $e');
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
      print('⚠️ [PresenceController] Online poll failed: $e');
    } finally {
      _pollInFlight = false;
    }
  }

  /// Seed from REST doctor lists (additive only).
  void seedFromDoctors(List<DoctorModel> doctors) {
    var changed = false;
    for (final doctor in doctors) {
      if (doctor.isOnline && doctor.userId.isNotEmpty) {
        if (_onlineDoctorUserIds.add(doctor.userId)) {
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
    _socketService.disconnect();
    _onlineDoctorUserIds.clear();
    _onlineDoctorUserIds.refresh();
  }
}
