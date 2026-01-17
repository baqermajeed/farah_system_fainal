import 'package:farah_sys_final/services/api_service.dart';
import 'package:farah_sys_final/core/network/api_constants.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/models/implant_stage_model.dart';

class ImplantStageService {
  final _api = ApiService();

  // جلب جميع مراحل زراعة الأسنان للمريض
  Future<List<ImplantStageModel>> getImplantStages(String patientId) async {
    try {
      final response = await _api.get(ApiConstants.getImplantStages(patientId));

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['stages'] != null && data['stages'] is List) {
          return (data['stages'] as List)
              .map((stage) => ImplantStageModel.fromJson(stage))
              .toList();
        }
        return [];
      } else {
        throw ApiException('فشل جلب مراحل الزراعة');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل جلب مراحل الزراعة: ${e.toString()}');
    }
  }

  // تهيئة مراحل زراعة الأسنان
  Future<List<ImplantStageModel>> initializeImplantStages(String patientId) async {
    try {
      final response = await _api.post(ApiConstants.initializeImplantStages(patientId));

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['stages'] != null && data['stages'] is List) {
          return (data['stages'] as List)
              .map((stage) => ImplantStageModel.fromJson(stage))
              .toList();
        }
        return [];
      } else {
        throw ApiException('فشل تهيئة مراحل الزراعة');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل تهيئة مراحل الزراعة: ${e.toString()}');
    }
  }

  // تحديث تاريخ مرحلة
  Future<ImplantStageModel> updateStageDate(
    String patientId,
    String stageName,
    DateTime date,
    String time,
  ) async {
    try {
      // دمج التاريخ والوقت (نستخدم التاريخ والوقت المحلي)
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      
      // إنشاء DateTime محلي باستخدام DateTime.now() كمرجع للحصول على timezone
      final now = DateTime.now();
      final localDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
      
      // حساب الفرق بين now المحلي و now UTC للحصول على offset
      final nowUtc = now.toUtc();
      final offset = now.difference(nowUtc);
      
      // تحويل إلى UTC بطرح offset
      final utcDateTime = localDateTime.subtract(offset);

      final data = {
        'scheduled_at': utcDateTime.toIso8601String(),
      };

      final response = await _api.put(
        ApiConstants.updateImplantStageDate(patientId, stageName),
        data: data,
      );

      if (response.statusCode == 200) {
        return ImplantStageModel.fromJson(response.data);
      } else {
        throw ApiException('فشل تحديث تاريخ المرحلة');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل تحديث تاريخ المرحلة: ${e.toString()}');
    }
  }

  // إكمال مرحلة
  Future<ImplantStageModel> completeStage(String patientId, String stageName) async {
    try {
      final response = await _api.post(
        ApiConstants.completeImplantStage(patientId, stageName),
      );

      if (response.statusCode == 200) {
        return ImplantStageModel.fromJson(response.data);
      } else {
        throw ApiException('فشل إكمال المرحلة');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل إكمال المرحلة: ${e.toString()}');
    }
  }

  // إلغاء إكمال مرحلة
  Future<ImplantStageModel> uncompleteStage(String patientId, String stageName) async {
    try {
      final response = await _api.post(
        ApiConstants.uncompleteImplantStage(patientId, stageName),
      );

      if (response.statusCode == 200) {
        return ImplantStageModel.fromJson(response.data);
      } else {
        throw ApiException('فشل إلغاء إكمال المرحلة');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('فشل إلغاء إكمال المرحلة: ${e.toString()}');
    }
  }
}

