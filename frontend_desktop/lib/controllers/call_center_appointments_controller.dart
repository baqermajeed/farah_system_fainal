import 'package:get/get.dart';

import '../models/call_center_appointment_model.dart';
import '../services/call_center_service.dart';

class CallCenterAppointmentsController extends GetxController {
  final _service = CallCenterService();

  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxList<CallCenterAppointmentModel> appointments =
      <CallCenterAppointmentModel>[].obs;

  String _lastSearch = '';

  Future<void> loadAppointments({String? search}) async {
    loading.value = true;
    error.value = null;
    final q = search?.trim() ?? '';
    _lastSearch = q;
    try {
      final list = await _service.getAppointments(search: q);
      appointments.assignAll(list);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> refresh() async {
    await loadAppointments(search: _lastSearch);
  }

  Future<void> createAppointment({
    required String patientName,
    required String patientPhone,
    required DateTime scheduledAt,
  }) async {
    await _service.createAppointment(
      patientName: patientName,
      patientPhone: patientPhone,
      scheduledAt: scheduledAt,
    );
    await refresh();
  }
}

