import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/models/call_center_appointment_model.dart';
import 'package:frontend_desktop/services/api_service.dart';

class CallCenterService {
  final _api = ApiService();

  /// مواعيد مركز الاتصالات (للموظف نفسه أو للأدمن).
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

  /// جلب جميع مواعيد مركز الاتصالات (لموظف الاستقبال - من جميع الموظفين).
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

  Future<void> createAppointment({
    required String patientName,
    required String patientPhone,
    required DateTime scheduledAt,
    String governorate = '',
    String platform = '',
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.callCenterAppointments,
        data: {
          'patient_name': patientName,
          'patient_phone': patientPhone,
          'scheduled_at': scheduledAt.toIso8601String(),
          'governorate': governorate,
          'platform': platform,
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

  Future<void> updateAppointment({
    required String id,
    String? patientName,
    String? patientPhone,
    DateTime? scheduledAt,
    String? governorate,
    String? platform,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (patientName != null) data['patient_name'] = patientName;
      if (patientPhone != null) data['patient_phone'] = patientPhone;
      if (scheduledAt != null) data['scheduled_at'] = scheduledAt.toIso8601String();
      if (governorate != null) data['governorate'] = governorate;
      if (platform != null) data['platform'] = platform;
      final response = await _api.put(
        ApiConstants.callCenterAppointment(id),
        data: data,
      );
      if (response.statusCode != 200) throw ApiException('فشل تعديل الموعد');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('فشل تعديل الموعد: ${e.toString()}');
    }
  }

  Future<void> deleteAppointment(String id) async {
    try {
      final response = await _api.delete(
        ApiConstants.callCenterAppointment(id),
      );
      if (response.statusCode != 200) throw ApiException('فشل حذف الموعد');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('فشل حذف الموعد: ${e.toString()}');
    }
  }

  /// موظف الاستقبال يقبل الموعد: يُحذف من الجدول ويزيد عداد المقبولة عند الموظف الذي أضافه.
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

  /// إحصائيات مواعيد مركز الاتصالات (اليوم، الشهر، النطاق، المقبولة).
  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await _api.get(
        ApiConstants.callCenterAppointmentsStats,
      );
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(
            (response.data as Map).map((k, v) => MapEntry(k.toString(), v)));
      }
      return {'today': 0, 'this_month': 0, 'accepted': 0};
    } catch (e) {
      return {'today': 0, 'this_month': 0, 'accepted': 0};
    }
  }
}

