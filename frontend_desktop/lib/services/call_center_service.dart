import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/models/call_center_appointment_model.dart';
import 'package:frontend_desktop/services/api_service.dart';

class CallCenterService {
  final _api = ApiService();

  Future<List<CallCenterAppointmentModel>> _fetchBranchAppointmentsAll({
    required String branch,
    required String endpoint,
    required String? search,
    required String? dateFromIso,
    required String? dateToIso,
    String? baseUrlOverride,
    int pageSize = 50,
  }) async {
    final all = <CallCenterAppointmentModel>[];
    var skip = 0;

    while (true) {
      final response = await _api.get(
        endpoint,
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (dateFromIso != null) 'date_from': dateFromIso,
          if (dateToIso != null) 'date_to': dateToIso,
          'skip': skip,
          'limit': pageSize,
        },
        baseUrlOverride: baseUrlOverride,
      );

      if (response.statusCode != 200) {
        break;
      }

      final data = (response.data as List?) ?? const [];
      if (data.isEmpty) {
        break;
      }

      for (final e in data) {
        try {
          all.add(
            CallCenterAppointmentModel.fromJson(
              (e as Map).cast<String, dynamic>(),
              branch: branch,
            ),
          );
        } catch (_) {
          // نتجاوز السجل غير الصالح بدل إيقاف تحميل كل القائمة.
        }
      }

      // انتهت الصفحات.
      if (data.length < pageSize) {
        break;
      }

      skip += pageSize;
    }

    return all;
  }

  /// مواعيد مركز الاتصالات (للموظف نفسه أو للأدمن) — من فرع النجف فقط.
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
            .map((e) => CallCenterAppointmentModel.fromJson(
                  (e as Map).cast<String, dynamic>(),
                  branch: ApiConstants.callCenterBranchFarahNajaf,
                ))
            .toList(growable: false);
      }
      throw ApiException('تعذر جلب مواعيد مركز الاتصالات');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر جلب مواعيد مركز الاتصالات: ${e.toString()}');
    }
  }

  /// جلب مواعيد الفرعين (النجف + الكندي) ودمجها مع تعليم الفرع وترتيب حسب التاريخ.
  Future<List<CallCenterAppointmentModel>> getAppointmentsFromBoth({
    String? search,
    String? dateFromIso,
    String? dateToIso,
    int limit = 50,
  }) async {
    final List<CallCenterAppointmentModel> merged = [];

    // النجف
    try {
      final najafItems = await _fetchBranchAppointmentsAll(
        branch: ApiConstants.callCenterBranchFarahNajaf,
        endpoint: ApiConstants.callCenterAppointments,
        search: search,
        dateFromIso: dateFromIso,
        dateToIso: dateToIso,
        pageSize: limit,
      );
      merged.addAll(najafItems);
    } catch (_) {
      // نتابع ونعرض ما تيسر من الكندي
    }

    // الكندي
    try {
      final kendyItems = await _fetchBranchAppointmentsAll(
        branch: ApiConstants.callCenterBranchKendyBaghdad,
        endpoint: ApiConstants.callCenterAppointments,
        search: search,
        dateFromIso: dateFromIso,
        dateToIso: dateToIso,
        baseUrlOverride: ApiConstants.baseUrlKendy,
        pageSize: limit,
      );
      merged.addAll(kendyItems);
    } catch (_) {
      // نتابع
    }

    merged.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return merged;
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

  /// [branch]: ApiConstants.callCenterBranchFarahNajaf → backend (فرح النجف)،
  /// ApiConstants.callCenterBranchKendyBaghdad → backend_kendy (الكندي بغداد).
  /// عند اختيار الكندي يُحفظ الموعد في الكندي فقط (يظهر مرة واحدة في الجدول).
  Future<void> createAppointment({
    required String patientName,
    required String patientPhone,
    required DateTime scheduledAt,
    required String branch,
    String governorate = '',
    String platform = '',
    String note = '',
  }) async {
    final payload = {
      'patient_name': patientName,
      'patient_phone': patientPhone,
      'scheduled_at': scheduledAt.toIso8601String(),
      'governorate': governorate,
      'platform': platform,
      'note': note,
    };

    try {
      final isKendy = branch == ApiConstants.callCenterBranchKendyBaghdad;

      final response = await _api.post(
        ApiConstants.callCenterAppointments,
        data: Map<String, dynamic>.from(payload),
        baseUrlOverride: isKendy ? ApiConstants.baseUrlKendy : null,
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

  /// [branch] إذا كان فرع الكندي يُرسل الطلب إلى backend_kendy.
  Future<void> updateAppointment({
    required String id,
    String? patientName,
    String? patientPhone,
    DateTime? scheduledAt,
    String? governorate,
    String? platform,
    String? note,
    String? branch,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (patientName != null) data['patient_name'] = patientName;
      if (patientPhone != null) data['patient_phone'] = patientPhone;
      if (scheduledAt != null) data['scheduled_at'] = scheduledAt.toIso8601String();
      if (governorate != null) data['governorate'] = governorate;
      if (platform != null) data['platform'] = platform;
      if (note != null) data['note'] = note;
      final isKendy = branch == ApiConstants.callCenterBranchKendyBaghdad;
      final response = await _api.put(
        ApiConstants.callCenterAppointment(id),
        data: data,
        baseUrlOverride: isKendy ? ApiConstants.baseUrlKendy : null,
      );
      if (response.statusCode != 200) throw ApiException('فشل تعديل الموعد');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('فشل تعديل الموعد: ${e.toString()}');
    }
  }

  /// [branch] إذا كان فرع الكندي يُرسل الطلب إلى backend_kendy.
  Future<void> deleteAppointment(String id, {String? branch}) async {
    try {
      final isKendy = branch == ApiConstants.callCenterBranchKendyBaghdad;
      final response = await _api.delete(
        ApiConstants.callCenterAppointment(id),
        baseUrlOverride: isKendy ? ApiConstants.baseUrlKendy : null,
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

