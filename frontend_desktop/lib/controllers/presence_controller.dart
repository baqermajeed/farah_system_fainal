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
    await _socketService.connect();
  }

  void seedFromDoctors(List<DoctorModel> doctors) {
    for (final doctor in doctors) {
      if (doctor.isOnline) {
        _onlineDoctorUserIds.add(doctor.userId);
      } else {
        _onlineDoctorUserIds.remove(doctor.userId);
      }
    }
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
