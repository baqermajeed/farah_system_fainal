import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_exception.dart';
import '../models/patient_item.dart';

class AdminService {
  final Dio _dio = ApiClient.instance.dio;

  Future<void> createDoctor({
    required String phone,
    required String username,
    required String password,
    required String name,
  }) async {
    try {
      await _dio.post(
        '/admin/staff',
        queryParameters: {
          'phone': phone,
          'username': username,
          'password': password,
          'role': 'doctor',
          'name': name,
        },
        options: ApiClient.instance.authorizedOptions(),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw ApiException('فشل إنشاء الطبيب. ${e.response?.data ?? ''}', statusCode: status);
    }
  }

  Future<List<PatientItem>> getDoctorPatients({
    required String doctorId,
    String? dateFromIso,
    String? dateToIso,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get(
        '/admin/doctors/$doctorId/patients',
        queryParameters: {
          if (dateFromIso != null) 'date_from': dateFromIso,
          if (dateToIso != null) 'date_to': dateToIso,
          'skip': skip,
          'limit': limit,
        },
        options: ApiClient.instance.authorizedOptions(),
      );

      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => PatientItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException('تعذر جلب مرضى الطبيب.', statusCode: e.response?.statusCode);
    }
  }
}


