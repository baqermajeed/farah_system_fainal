import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/models/call_center_appointment_model.dart';
import 'package:frontend_desktop/services/api_service.dart';

class CallCenterService {
  final _api = ApiService();

  /// جلب مواعيد مركز الاتصالات لموظف الاستقبال (غير المقبولة فقط من الـ API).
  Future<List<CallCenterAppointmentModel>> getAppointmentsForReception({
    String? search,
    String? dateFromIso,
    String? dateToIso,
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _api.get(
        ApiConstants.receptionCallCenterAppointments,
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (dateFromIso != null) 'date_from': dateFromIso,
          if (dateToIso != null) 'date_to': dateToIso,
          'skip': skip,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = (response.data as List?) ?? const [];
        return data
            .map((e) =>
                CallCenterAppointmentModel.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      }
      throw ApiException('تعذر جلب مواعيد مركز الاتصالات');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر جلب مواعيد مركز الاتصالات: ${e.toString()}');
    }
  }

  /// موظف الاستقبال يقبل الموعد (يُخفى من القائمة ويزيد عداد المقبولة عند موظف الـ call center).
  Future<void> acceptForReception(String appointmentId) async {
    try {
      final response = await _api.post(
        ApiConstants.receptionCallCenterAppointmentAccept(appointmentId),
      );
      if (response.statusCode != 200) throw ApiException('فشل قبول الموعد');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('فشل قبول الموعد: ${e.toString()}');
    }
  }

  Future<List<CallCenterAppointmentModel>> getAppointments({
    String? search,
    String? dateFromIso,
    String? dateToIso,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _api.get(
        ApiConstants.callCenterAppointments,
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (dateFromIso != null) 'date_from': dateFromIso,
          if (dateToIso != null) 'date_to': dateToIso,
          'skip': skip,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = (response.data as List?) ?? const [];
        return data
            .map((e) =>
                CallCenterAppointmentModel.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      }
      throw ApiException('تعذر جلب مواعيد مركز الاتصالات');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر جلب مواعيد مركز الاتصالات: ${e.toString()}');
    }
  }

  Future<void> createAppointment({
    required String patientName,
    required String patientPhone,
    required DateTime scheduledAt,
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.callCenterAppointments,
        data: {
          'patient_name': patientName,
          'patient_phone': patientPhone,
          'scheduled_at': scheduledAt.toIso8601String(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }
      throw ApiException('فشل إنشاء الموعد');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('فشل إنشاء الموعد: ${e.toString()}');
    }
  }
}

