import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/models/call_center_appointment_model.dart';
import 'package:frontend_desktop/services/api_service.dart';

class CallCenterService {
  final _api = ApiService();

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
    int skip = 0,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (dateFromIso != null) 'date_from': dateFromIso,
      if (dateToIso != null) 'date_to': dateToIso,
      'skip': skip,
      'limit': limit,
    };

    final List<CallCenterAppointmentModel> merged = [];

    // النجف
    try {
      final responseNajaf = await _api.get(
        ApiConstants.callCenterAppointments,
        queryParameters: Map<String, dynamic>.from(params),
      );
      if (responseNajaf.statusCode == 200) {
        final data = (responseNajaf.data as List?) ?? const [];
        for (final e in data) {
          merged.add(CallCenterAppointmentModel.fromJson(
            (e as Map).cast<String, dynamic>(),
            branch: ApiConstants.callCenterBranchFarahNajaf,
          ));
        }
      }
    } catch (_) {
      // نتابع ونعرض ما تيسر من الكندي
    }

    // الكندي
    try {
      final responseKendy = await _api.get(
        ApiConstants.callCenterAppointments,
        queryParameters: Map<String, dynamic>.from(params),
        baseUrlOverride: ApiConstants.baseUrlKendy,
      );
      if (responseKendy.statusCode == 200) {
        final data = (responseKendy.data as List?) ?? const [];
        for (final e in data) {
          merged.add(CallCenterAppointmentModel.fromJson(
            (e as Map).cast<String, dynamic>(),
            branch: ApiConstants.callCenterBranchKendyBaghdad,
          ));
        }
      }
    } catch (_) {
      // نتابع
    }

    merged.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
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

