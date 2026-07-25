import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/services/api_service.dart';

class StatsService {
  final ApiService _api = ApiService();

  String? _cachedDoctorId;

  Future<String> resolveDoctorId({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDoctorId != null && _cachedDoctorId!.isNotEmpty) {
      return _cachedDoctorId!;
    }

    final response = await _api.get(ApiConstants.doctorMe);
    if (response.statusCode != 200) {
      throw ApiException('تعذر تحديد حساب الطبيب');
    }

    final data = (response.data as Map).cast<String, dynamic>();
    final doctorId = data['doctor_id']?.toString() ?? '';
    if (doctorId.isEmpty) {
      throw ApiException('معرّف الطبيب غير متوفر');
    }

    _cachedDoctorId = doctorId;
    return doctorId;
  }

  Future<Map<String, dynamic>> getDoctorDetailsCards(String doctorId) async {
    final response = await _api.get(ApiConstants.statsDoctorDetailsCards(doctorId));
    if (response.statusCode != 200) {
      throw ApiException('تعذر جلب إحصائيات الطبيب');
    }
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getDoctorAppointmentsBreakdown(
    String doctorId, {
    String? dateFrom,
    String? dateTo,
    String group = 'day',
  }) async {
    final response = await _api.get(
      ApiConstants.statsDoctorAppointmentsBreakdown(doctorId),
      queryParameters: {
        'group': group,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      },
    );
    if (response.statusCode != 200) {
      throw ApiException('تعذر جلب إحصائيات المواعيد');
    }
    return (response.data as Map).cast<String, dynamic>();
  }
}
