import 'package:dio/dio.dart';

import '../models/dashboard_stats.dart';
import '../models/doctor_stats.dart';
import '../models/doctor_profile.dart';
import '../models/patient_activity_stats.dart';
import '../models/transfers_stats.dart';
import 'api_client.dart';
import 'api_exception.dart';

class StatsService {
  final Dio _dio = ApiClient.instance.dio;

  Future<DashboardStats> getDashboard() async {
    try {
      final res = await _dio.get('/stats/dashboard', options: ApiClient.instance.authorizedOptions());
      return DashboardStats.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException('تعذر جلب إحصائيات لوحة التحكم.', statusCode: e.response?.statusCode);
    }
  }

  Future<List<DoctorStat>> getDoctors() async {
    try {
      final res = await _dio.get('/stats/doctors', options: ApiClient.instance.authorizedOptions());
      final data = (res.data as Map).cast<String, dynamic>();
      final doctorsRaw = (data['doctors'] as List?) ?? const [];
      return doctorsRaw
          .map((e) => DoctorStat.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException('تعذر جلب قائمة الأطباء.', statusCode: e.response?.statusCode);
    }
  }

  Future<DoctorProfile> getDoctorProfile({
    required String doctorId,
    String? dateFromIso,
    String? dateToIso,
  }) async {
    try {
      final res = await _dio.get(
        '/stats/doctors/$doctorId/profile',
        queryParameters: {
          if (dateFromIso != null) 'date_from': dateFromIso,
          if (dateToIso != null) 'date_to': dateToIso,
        },
        options: ApiClient.instance.authorizedOptions(),
      );
      return DoctorProfile.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException('تعذر جلب بروفايل الطبيب.', statusCode: e.response?.statusCode);
    }
  }

  Future<TransfersStats> getTransfers({
    required String group,
    String? dateFromIso,
    String? dateToIso,
    String? doctorId,
  }) async {
    try {
      final res = await _dio.get(
        '/stats/transfers',
        queryParameters: {
          'group': group,
          if (dateFromIso != null) 'date_from': dateFromIso,
          if (dateToIso != null) 'date_to': dateToIso,
          if (doctorId != null && doctorId.isNotEmpty) 'doctor_id': doctorId,
        },
        options: ApiClient.instance.authorizedOptions(),
      );
      return TransfersStats.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException('تعذر جلب إحصائيات التحويلات.', statusCode: e.response?.statusCode);
    }
  }

  Future<PatientActivityStats> getPatientActivity({
    String? dateFromIso,
    String? dateToIso,
    String? doctorId,
  }) async {
    try {
      final res = await _dio.get(
        '/stats/patient-activity',
        queryParameters: {
          if (dateFromIso != null) 'date_from': dateFromIso,
          if (dateToIso != null) 'date_to': dateToIso,
          if (doctorId != null && doctorId.isNotEmpty) 'doctor_id': doctorId,
        },
        options: ApiClient.instance.authorizedOptions(),
      );
      return PatientActivityStats.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException('تعذر جلب إحصائيات نشاط المرضى.', statusCode: e.response?.statusCode);
    }
  }
}


