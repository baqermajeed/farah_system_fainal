import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_exception.dart';
import '../models/patient_item.dart';
import '../models/call_center_staff.dart';

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

  Future<void> createCallCenterStaff({
    required String phone,
    required String username,
    required String password,
    required String name,
    String? imageUrl,
  }) async {
    try {
      await _dio.post(
        '/admin/staff',
        queryParameters: {
          'phone': phone,
          'username': username,
          'password': password,
          'role': 'call_center',
          'name': name,
          if (imageUrl != null && imageUrl.trim().isNotEmpty)
            'imageUrl': imageUrl.trim(),
        },
        options: ApiClient.instance.authorizedOptions(),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw ApiException(
        'فشل إنشاء موظف مركز الاتصالات. ${e.response?.data ?? ''}',
        statusCode: status,
      );
    }
  }

  Future<List<CallCenterStaff>> getCallCenterStaff({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final res = await _dio.get(
        '/admin/staff',
        queryParameters: {
          'role': 'call_center',
          'skip': skip,
          'limit': limit,
        },
        options: ApiClient.instance.authorizedOptions(),
      );

      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => CallCenterStaff.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiException('تعذر جلب موظفي مركز الاتصالات.',
          statusCode: e.response?.statusCode);
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

  /// تعيين أو إلغاء خاصية "طبيب مدير" للطبيب
  Future<void> setDoctorManager({
    required String doctorId,
    required bool isManager,
  }) async {
    try {
      await _dio.patch(
        '/admin/doctors/$doctorId/manager',
        data: {'is_manager': isManager},
        options: ApiClient.instance.authorizedOptions(),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw ApiException(
        'فشل ${isManager ? 'تعيين' : 'إلغاء'} طبيب مدير. ${e.response?.data ?? ''}',
        statusCode: status,
      );
    }
  }
}


