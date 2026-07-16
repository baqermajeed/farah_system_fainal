import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/services/api_service.dart';

/// HTTP presence API (heartbeat + online roster).
class PresenceApiService {
  final ApiService _api = ApiService();

  Future<void> sendHeartbeat() async {
    await _api.post(ApiConstants.presenceHeartbeat);
  }

  Future<List<String>> fetchOnlineDoctorUserIds() async {
    final response = await _api.get(ApiConstants.presenceOnlineDoctors);
    final data = response.data;
    if (data is! Map) return const [];
    final raw = data['online_user_ids'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }
}
