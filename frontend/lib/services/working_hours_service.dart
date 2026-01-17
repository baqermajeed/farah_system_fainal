import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/models/working_hours_model.dart';
import 'package:farah_sys_final/services/api_service.dart';

class WorkingHoursService {
  final _api = ApiService();

  /// جلب أوقات عمل الطبيب
  Future<List<WorkingHoursModel>> getDoctorWorkingHours(String doctorId) async {
    try {
      print(
        '📋 [WorkingHoursService] Fetching working hours for doctor: $doctorId',
      );
      final response = await _api.get(ApiConstants.doctorWorkingHours);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final List<WorkingHoursModel> workingHours = data
            .map((json) => WorkingHoursModel.fromJson(json))
            .toList();
        print(
          '✅ [WorkingHoursService] Fetched ${workingHours.length} working hours',
        );
        return workingHours;
      } else {
        throw ApiException('فشل جلب أوقات العمل');
      }
    } catch (e) {
      print('❌ [WorkingHoursService] Error fetching working hours: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب أوقات العمل: ${e.toString()}');
    }
  }

  /// حفظ أوقات عمل الطبيب
  Future<List<WorkingHoursModel>> setWorkingHours(
    String doctorId,
    List<WorkingHoursModel> workingHours,
  ) async {
    try {
      print(
        '💾 [WorkingHoursService] Saving working hours for doctor: $doctorId',
      );
      // Convert to snake_case format expected by backend
      final List<Map<String, dynamic>> hoursData = workingHours.map((wh) {
        return {
          'day_of_week': wh.dayOfWeek,
          'start_time': wh.startTime,
          'end_time': wh.endTime,
          'is_working': wh.isWorking,
          'slot_duration': wh.slotDuration,
        };
      }).toList();

      final response = await _api.post(
        ApiConstants.doctorWorkingHours,
        data: hoursData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data;
        final List<WorkingHoursModel> savedHours = data
            .map((json) => WorkingHoursModel.fromJson(json))
            .toList();
        print(
          '✅ [WorkingHoursService] Saved ${savedHours.length} working hours',
        );
        return savedHours;
      } else {
        throw ApiException('فشل حفظ أوقات العمل');
      }
    } catch (e) {
      print('❌ [WorkingHoursService] Error saving working hours: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل حفظ أوقات العمل: ${e.toString()}');
    }
  }

  /// حذف جميع أوقات عمل الطبيب
  Future<bool> deleteWorkingHours(String doctorId) async {
    try {
      print(
        '🗑️ [WorkingHoursService] Deleting working hours for doctor: $doctorId',
      );
      final response = await _api.delete(ApiConstants.doctorWorkingHours);

      if (response.statusCode == 204 || response.statusCode == 200) {
        print('✅ [WorkingHoursService] Deleted working hours successfully');
        return true;
      } else {
        throw ApiException('فشل حذف أوقات العمل');
      }
    } catch (e) {
      print('❌ [WorkingHoursService] Error deleting working hours: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل حذف أوقات العمل: ${e.toString()}');
    }
  }

  /// جلب الأوقات المتاحة لطبيب في يوم معين
  Future<List<String>> getAvailableSlots(String doctorId, String date) async {
    try {
      print(
        '📅 [WorkingHoursService] Fetching available slots for doctor: $doctorId, date: $date',
      );
      final response = await _api.get(ApiConstants.doctorAvailableSlots(date));

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final List<String> slots = data.map((slot) => slot.toString()).toList();
        print('✅ [WorkingHoursService] Found ${slots.length} available slots');
        return slots;
      } else {
        throw ApiException('فشل جلب الأوقات المتاحة');
      }
    } catch (e) {
      print('❌ [WorkingHoursService] Error fetching available slots: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب الأوقات المتاحة: ${e.toString()}');
    }
  }
}
