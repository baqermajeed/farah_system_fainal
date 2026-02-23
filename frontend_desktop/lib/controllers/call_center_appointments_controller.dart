import 'package:get/get.dart';

import '../models/call_center_appointment_model.dart';
import '../services/call_center_service.dart';

class CallCenterAppointmentsController extends GetxController {
  final _service = CallCenterService();

  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxList<CallCenterAppointmentModel> appointments =
      <CallCenterAppointmentModel>[].obs;
  /// عدد المواعيد المقبولة من الاستقبال (يُحدّث مع الإحصائيات).
  final RxInt acceptedCount = 0.obs;

  String _lastSearch = '';

  Future<void> loadAppointments({String? search}) async {
    loading.value = true;
    error.value = null;
    final q = search?.trim() ?? '';
    _lastSearch = q;
    try {
      final list = await _service.getAppointments(search: q);
      appointments.assignAll(list);
      await loadStats();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadStats() async {
    try {
      final res = await _service.getStats();
      acceptedCount.value = (res['accepted'] is int)
          ? res['accepted'] as int
          : (int.tryParse(res['accepted']?.toString() ?? '0') ?? 0);
    } catch (_) {
      acceptedCount.value = 0;
    }
  }

  Future<void> refresh() async {
    await loadAppointments(search: _lastSearch);
  }

  Future<void> createAppointment({
    required String patientName,
    required String patientPhone,
    required DateTime scheduledAt,
    String governorate = '',
    String platform = '',
  }) async {
    await _service.createAppointment(
      patientName: patientName,
      patientPhone: patientPhone,
      scheduledAt: scheduledAt,
      governorate: governorate,
      platform: platform,
    );
    await refresh();
  }

  Future<void> updateAppointment({
    required String id,
    String? patientName,
    String? patientPhone,
    DateTime? scheduledAt,
    String? governorate,
    String? platform,
  }) async {
    await _service.updateAppointment(
      id: id,
      patientName: patientName,
      patientPhone: patientPhone,
      scheduledAt: scheduledAt,
      governorate: governorate,
      platform: platform,
    );
    await refresh();
  }

  Future<void> deleteAppointment(String id) async {
    await _service.deleteAppointment(id);
    await refresh();
  }
}

