import 'package:get/get.dart';
import 'package:frontend_desktop/models/doctor_model.dart';
import 'package:frontend_desktop/models/user_model.dart';
import 'package:frontend_desktop/services/socket_service.dart';

/// Tracks which doctors are currently online (desktop app open).
class PresenceController extends GetxController {
  final SocketService _socketService = SocketService();
  final RxSet<String> _onlineDoctorUserIds = <String>{}.obs;

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
    final ok = await _socketService.connect();
    if (!ok) {
      print('⚠️ [PresenceController] Failed to connect presence socket');
    }
  }

  /// Seed from REST. Only add confirmed online doctors — never clear
  /// someone who may already be online via a live `presence_changed` event
  /// when the API returns a stale/false `is_online` (e.g. multi-worker).
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
    _onlineDoctorUserIds
      ..clear()
      ..addAll(onlineUserIds.where((id) => id.isNotEmpty));
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
    _socketService.disconnect();
    _onlineDoctorUserIds.clear();
    _onlineDoctorUserIds.refresh();
  }
}
