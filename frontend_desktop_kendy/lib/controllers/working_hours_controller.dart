import 'package:get/get.dart';
import 'package:frontend_desktop/services/working_hours_service.dart';
import 'package:frontend_desktop/models/working_hours_model.dart';
import 'package:frontend_desktop/core/network/api_exception.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';

class WorkingHoursController extends GetxController {
  final _service = WorkingHoursService();
  final _authController = Get.find<AuthController>();

  // حالة التحميل
  RxBool isLoading = false.obs;

  // قائمة أوقات العمل (7 أيام)
  RxList<Map<String, dynamic>> workingHours = <Map<String, dynamic>>[].obs;

  // حالة التوسع لكل يوم
  RxMap<int, bool> expandedDays = <int, bool>{}.obs;

  // كاش أوقات العمل لكل طبيب (doctorId -> workingHours)
  // الكاش يبقى دائماً حتى يتم التحديث يدوياً
  final Map<String, List<Map<String, dynamic>>> _workingHoursCache = {};

  // أسماء الأيام
  final List<String> dayNames = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  @override
  void onInit() {
    super.onInit();
    // تهيئة أوقات العمل الافتراضية
    _initializeDefaultWorkingHours();
    // جلب أوقات العمل من الـ API
    loadWorkingHours();
  }

  /// تهيئة أوقات العمل الافتراضية
  void _initializeDefaultWorkingHours() {
    workingHours.value = List.generate(7, (index) {
      return {
        'dayOfWeek': index,
        'dayName': dayNames[index],
        'startTime': '09:00',
        'endTime': '17:00',
        'isWorking': index != 5, // الجمعة عطلة افتراضياً
        'slotDuration': 30,
        'id': null,
      };
    });
  }

  /// جلب أوقات العمل من الـ API
  ///
  /// - إذا تم تمرير [doctorId] سيتم جلب أوقات عمل هذا الطبيب.
  /// - إذا لم يُمرر، سيتم استخدام مستخدم الجلسة الحالية (مفيد في شاشة الطبيب).
  /// - [forceRefresh] إذا كان true، سيتم تجاهل الكاش وجلب البيانات من الباكند.
  ///   يجب استخدام forceRefresh عند فتح صفحة تعديل أوقات العمل.
  Future<void> loadWorkingHours({String? doctorId, bool forceRefresh = false}) async {
    final resolvedDoctorId = doctorId ?? _authController.currentUser.value?.id;
    if (resolvedDoctorId == null || resolvedDoctorId.isEmpty) return;

    // التحقق من الكاش أولاً (الكاش دائماً صالح إلا إذا كان forceRefresh = true)
    if (!forceRefresh && _workingHoursCache.containsKey(resolvedDoctorId)) {
      print('✅ [WorkingHoursController] Using cached working hours for doctor: $resolvedDoctorId');
      final cachedHours = _workingHoursCache[resolvedDoctorId]!;
      workingHours.value = List.from(cachedHours);
      workingHours.refresh();
      return;
    }

    isLoading.value = true;
    try {
      print('📡 [WorkingHoursController] Fetching working hours from backend for doctor: $resolvedDoctorId');
      final userType =
          (_authController.currentUser.value?.userType ?? '').toLowerCase();
      final bool isReceptionOrAdmin =
          userType == 'receptionist' || userType == 'admin';

      final hours = (isReceptionOrAdmin && doctorId != null)
          ? await _service.getDoctorWorkingHoursForReception(resolvedDoctorId)
          : await _service.getDoctorWorkingHours(resolvedDoctorId);
      
      // تحديث أوقات العمل من البيانات المسترجعة
      final Map<int, Map<String, dynamic>> hoursMap = {};
      for (var hour in hours) {
        final dayIndex = hour.dayOfWeek;
        if (dayIndex >= 0 && dayIndex < 7) {
          hoursMap[dayIndex] = {
            'dayOfWeek': dayIndex,
            'dayName': dayNames[dayIndex],
            'startTime': hour.startTime,
            'endTime': hour.endTime,
            'isWorking': hour.isWorking,
            'slotDuration': hour.slotDuration,
            'id': hour.id,
          };
        }
      }
      
      // ضمان وجود جميع الأيام السبعة (استخدم القيم الافتراضية للأيام المفقودة)
      final List<Map<String, dynamic>> processedHours = [];
      for (int i = 0; i < 7; i++) {
        if (hoursMap.containsKey(i)) {
          processedHours.add(hoursMap[i]!);
        } else {
          // إذا لم يكن اليوم موجوداً في قاعدة البيانات، استخدم القيم الافتراضية
          processedHours.add({
            'dayOfWeek': i,
            'dayName': dayNames[i],
            'startTime': '09:00',
            'endTime': '17:00',
            'isWorking': i != 5, // الجمعة عطلة افتراضياً
            'slotDuration': 30,
            'id': null,
          });
        }
      }
      
      // تحديث الكاش (يتم تحديثه دائماً عند جلب البيانات من الباكند)
      _workingHoursCache[resolvedDoctorId] = processedHours;
      
      // تحديث أوقات العمل المعروضة
      workingHours.value = processedHours;
      workingHours.refresh();
      
      print('✅ [WorkingHoursController] Cached working hours for doctor: $resolvedDoctorId');
    } catch (e) {
      print('❌ [WorkingHoursController] Error loading working hours: $e');
      // في حالة الخطأ، حاول استخدام الكاش القديم إذا كان موجوداً
      if (_workingHoursCache.containsKey(resolvedDoctorId)) {
        print('⚠️ [WorkingHoursController] Using stale cache due to error');
        final cachedHours = _workingHoursCache[resolvedDoctorId]!;
        workingHours.value = List.from(cachedHours);
        workingHours.refresh();
      } else {
        // Keep default values on error
        _initializeDefaultWorkingHours();
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// مسح الكاش لطبيب معين
  void clearCacheForDoctor(String doctorId) {
    _workingHoursCache.remove(doctorId);
    print('🗑️ [WorkingHoursController] Cleared cache for doctor: $doctorId');
  }

  /// مسح جميع الكاش
  void clearAllCache() {
    _workingHoursCache.clear();
    print('🗑️ [WorkingHoursController] Cleared all cache');
  }

  /// حفظ أوقات العمل
  Future<Map<String, dynamic>> saveWorkingHours() async {
    final user = _authController.currentUser.value;
    if (user == null) {
      return {'ok': false, 'message': 'المستخدم غير موجود'};
    }

    final doctorId = user.id;

    // تحويل البيانات للصيغة المطلوبة - تأكد من إرسال جميع الأيام السبعة
    final List<WorkingHoursModel> hoursToSend = [];
    for (int i = 0; i < 7; i++) {
      if (i < workingHours.length) {
        final hour = workingHours[i];
        hoursToSend.add(WorkingHoursModel(
          id: hour['id'] ?? '',
          doctorId: doctorId,
          dayOfWeek: hour['dayOfWeek'] ?? i,
          startTime: hour['startTime'] ?? '09:00',
          endTime: hour['endTime'] ?? '17:00',
          isWorking: hour['isWorking'] ?? (i != 5),
          slotDuration: hour['slotDuration'] ?? 30,
        ));
      } else {
        // إذا لم يكن اليوم موجوداً، أضفه بقيم افتراضية
        hoursToSend.add(WorkingHoursModel(
          id: '',
          doctorId: doctorId,
          dayOfWeek: i,
          startTime: '09:00',
          endTime: '17:00',
          isWorking: i != 5, // الجمعة عطلة افتراضياً
          slotDuration: 30,
        ));
      }
    }

    try {
      await _service.setWorkingHours(doctorId, hoursToSend);
      // مسح الكاش وإعادة تحميل البيانات
      clearCacheForDoctor(doctorId);
      await loadWorkingHours(forceRefresh: true);
      return {'ok': true, 'message': 'تم حفظ أوقات العمل بنجاح'};
    } catch (e) {
      print('❌ [WorkingHoursController] Error saving working hours: $e');
      return {
        'ok': false,
        'message': e is ApiException ? e.message : 'فشل حفظ أوقات العمل',
      };
    }
  }

  /// حذف جميع أوقات العمل
  Future<Map<String, dynamic>> deleteAllWorkingHours() async {
    final user = _authController.currentUser.value;
    if (user == null) {
      return {'ok': false, 'message': 'المستخدم غير موجود'};
    }

    final doctorId = user.id;

    try {
      await _service.deleteWorkingHours(doctorId);
      // مسح الكاش
      clearCacheForDoctor(doctorId);
      _initializeDefaultWorkingHours();
      return {'ok': true, 'message': 'تم حذف جميع أوقات العمل بنجاح'};
    } catch (e) {
      print('❌ [WorkingHoursController] Error deleting working hours: $e');
      return {
        'ok': false,
        'message': e is ApiException ? e.message : 'فشل حذف أوقات العمل',
      };
    }
  }

  /// تحديث حالة العمل ليوم معين
  void toggleDayWorking(int dayIndex) {
    if (dayIndex >= 0 && dayIndex < workingHours.length) {
      workingHours[dayIndex]['isWorking'] = !workingHours[dayIndex]['isWorking'];
      workingHours.refresh();
    }
  }

  /// تحديث وقت البداية ليوم معين
  void updateStartTime(int dayIndex, String time) {
    if (dayIndex >= 0 && dayIndex < workingHours.length) {
      workingHours[dayIndex]['startTime'] = time;
      workingHours.refresh();
    }
  }

  /// تحديث وقت النهاية ليوم معين
  void updateEndTime(int dayIndex, String time) {
    if (dayIndex >= 0 && dayIndex < workingHours.length) {
      workingHours[dayIndex]['endTime'] = time;
      workingHours.refresh();
    }
  }

  /// تحديث مدة الفترة الزمنية ليوم معين
  void updateSlotDuration(int dayIndex, int duration) {
    if (dayIndex >= 0 && dayIndex < workingHours.length) {
      workingHours[dayIndex]['slotDuration'] = duration;
      workingHours.refresh();
    }
  }

  /// تطبيق أوقات يوم معين على جميع الأيام
  void applyDayToAllDays(int sourceDayIndex) {
    if (sourceDayIndex < 0 || sourceDayIndex >= workingHours.length) return;

    final sourceDay = workingHours[sourceDayIndex];
    final startTime = sourceDay['startTime'];
    final endTime = sourceDay['endTime'];
    final slotDuration = sourceDay['slotDuration'];
    final isWorking = sourceDay['isWorking'];

    for (int i = 0; i < workingHours.length; i++) {
      workingHours[i]['startTime'] = startTime;
      workingHours[i]['endTime'] = endTime;
      workingHours[i]['slotDuration'] = slotDuration;
      workingHours[i]['isWorking'] = isWorking;
    }
    workingHours.refresh();
  }
}
