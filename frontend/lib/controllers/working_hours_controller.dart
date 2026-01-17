import 'package:get/get.dart';
import 'package:farah_sys_final/services/working_hours_service.dart';
import 'package:farah_sys_final/models/working_hours_model.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';

class WorkingHoursController extends GetxController {
  final _service = WorkingHoursService();
  final _authController = Get.find<AuthController>();

  // حالة التحميل
  RxBool isLoading = false.obs;

  // قائمة أوقات العمل (7 أيام)
  RxList<Map<String, dynamic>> workingHours = <Map<String, dynamic>>[].obs;

  // حالة التوسع لكل يوم
  RxMap<int, bool> expandedDays = <int, bool>{}.obs;

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
  Future<void> loadWorkingHours() async {
    final user = _authController.currentUser.value;
    if (user == null) return;

    // Get doctor ID from user
    // Assuming the user ID is the doctor ID or we need to get it from Doctor model
    final doctorId = user.id;

    isLoading.value = true;
    try {
      final hours = await _service.getDoctorWorkingHours(doctorId);
      
      // تحديث أوقات العمل من البيانات المسترجعة
      // تأكد من وجود جميع الأيام السبعة
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
      for (int i = 0; i < 7; i++) {
        if (hoursMap.containsKey(i)) {
          workingHours[i] = hoursMap[i]!;
        } else {
          // إذا لم يكن اليوم موجوداً في قاعدة البيانات، استخدم القيم الافتراضية
          workingHours[i] = {
            'dayOfWeek': i,
            'dayName': dayNames[i],
            'startTime': '09:00',
            'endTime': '17:00',
            'isWorking': i != 5, // الجمعة عطلة افتراضياً
            'slotDuration': 30,
            'id': null,
          };
        }
      }
      workingHours.refresh();
    } catch (e) {
      print('❌ [WorkingHoursController] Error loading working hours: $e');
      // Keep default values on error
    } finally {
      isLoading.value = false;
    }
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
      // إعادة تحميل البيانات
      await loadWorkingHours();
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

