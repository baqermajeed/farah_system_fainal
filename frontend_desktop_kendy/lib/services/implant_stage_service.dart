import 'package:frontend_desktop/services/api_service.dart';
import 'package:frontend_desktop/core/network/api_constants.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/models/implant_stage_model.dart';

class ImplantStageService {
  final _api = ApiService();

  List<ImplantStageModel> _parseStagesFromResponseData(dynamic data) {
    // Supports multiple backend shapes:
    // 1) { stages: [...] }
    // 2) { data: { stages: [...] } }
    // 3) [ ... ]
    if (data is List) {
      return data.map((x) => ImplantStageModel.fromJson(x)).toList();
    }

    if (data is Map) {
      final stages = data['stages'];
      if (stages is List) {
        return stages.map((x) => ImplantStageModel.fromJson(x)).toList();
      }

      final nested = data['data'];
      if (nested is Map) {
        final nestedStages = nested['stages'];
        if (nestedStages is List) {
          return nestedStages.map((x) => ImplantStageModel.fromJson(x)).toList();
        }
      }
    }

    return [];
  }

  // جلب جميع مراحل زراعة الأسنان للمريض
  Future<List<ImplantStageModel>> getImplantStages(String patientId) async {
    try {
      final response = await _api.get(ApiConstants.getImplantStages(patientId));

      if (response.statusCode == 200) {
        return _parseStagesFromResponseData(response.data);
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
        return _parseStagesFromResponseData(response.data);
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
      // دمج التاريخ والوقت (محلي) وإرساله كما هو بدون تحويل UTC
      // حتى يبقى نفس الوقت الذي يراه الطبيب في الواجهة هو المخزَّن في الباكند.
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      final localDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );

      final data = {
        'scheduled_at': localDateTime.toIso8601String(),
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
