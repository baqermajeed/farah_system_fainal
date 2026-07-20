import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/app_colors.dart';
import 'implant_stage_controller.dart';
import 'working_hours_controller.dart';

/// Controller لشاشة تعديل تاريخ مرحلة زراعة الأسنان.
class EditImplantStageDateController extends GetxController {
  final Rxn<DateTime> selectedDate = Rxn<DateTime>();
  final Rxn<String> selectedTime = Rxn<String>();
  final RxList<String> availableSlots = <String>[].obs;
  final RxBool isLoadingSlots = false.obs;

  String? patientId;
  String? stageName;
  DateTime? currentDate;

  late final WorkingHoursController workingHoursController;
  ImplantStageController get implantStageController =>
      Get.find<ImplantStageController>();

  @override
  void onInit() {
    super.onInit();
    workingHoursController = Get.put(WorkingHoursController());

    final args = Get.arguments as Map<String, dynamic>?;
    patientId = args?['patientId'];
    stageName = args?['stageName'];
    currentDate = args?['currentDate'] as DateTime?;

    if (currentDate != null) {
      selectedDate.value = currentDate;
      // تحويل الوقت إلى تنسيق 12 ساعة
      final hour = currentDate!.hour;
      final minute = currentDate!.minute;
      final isPM = hour >= 12;
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      selectedTime.value =
          '$displayHour:${minute.toString().padLeft(2, '0')} ${isPM ? 'م' : 'ص'}';
    }

    // تحميل أوقات العمل
    workingHoursController.loadWorkingHours();
  }

  Future<void> loadAvailableSlots(DateTime date) async {
    if (patientId == null) return;

    isLoadingSlots.value = true;

    try {
      // الحصول على معرف الطبيب من المريض
      // هنا نحتاج إلى معرف الطبيب، لكن يمكننا استخدام أول طبيب
      // في الواقع، يجب أن نحصل على معرف الطبيب من المريض
      // لكن للتبسيط، سنستخدم طريقة أخرى

      // سنستخدم طريقة بسيطة: عرض جميع الأوقات المتاحة
      // في التطبيق الحقيقي، يجب جلب الأوقات المتاحة من API
      availableSlots.clear();
    } finally {
      isLoadingSlots.value = false;
    }
  }

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'),
    );
    if (picked != null) {
      selectedDate.value = picked;
      selectedTime.value = null; // إعادة تعيين الوقت عند تغيير التاريخ
      await loadAvailableSlots(picked);
    }
  }

  Future<void> pickTime(BuildContext context) async {
    if (selectedDate.value == null) {
      Get.snackbar(
        'تنبيه',
        'يرجى اختيار التاريخ أولاً',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: AppColors.white,
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime.value != null
          ? TimeOfDay(
              hour: int.parse(selectedTime.value!.split(':')[0]),
              minute: int.parse(
                selectedTime.value!.split(':')[1].split(' ')[0],
              ),
            )
          : TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour;
      final minute = picked.minute;
      final isPM = hour >= 12;
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      selectedTime.value =
          '$displayHour:${minute.toString().padLeft(2, '0')} ${isPM ? 'م' : 'ص'}';
    }
  }

  Future<void> saveChanges() async {
    if (patientId == null || stageName == null) {
      Get.snackbar(
        'خطأ',
        'بيانات غير صحيحة',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: AppColors.white,
      );
      return;
    }

    // تحويل الوقت من 12 ساعة إلى 24 ساعة
    final time = selectedTime.value!;
    final isPM = time.contains('م');
    final timeStr = time.replaceAll(' م', '').replaceAll(' ص', '').trim();
    final timeParts = timeStr.split(':');
    var hour = int.parse(timeParts[0]);
    final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

    if (isPM && hour != 12) {
      hour += 12;
    } else if (!isPM && hour == 12) {
      hour = 0;
    }

    final success = await implantStageController.updateStageDate(
      patientId!,
      stageName!,
      selectedDate.value!,
      '$hour:${minute.toString().padLeft(2, '0')}',
    );

    if (success) {
      Get.snackbar(
        'نجح',
        'تم تحديث التاريخ بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.white,
      );
      Get.back();
    } else {
      Get.snackbar(
        'خطأ',
        implantStageController.errorMessage.value.isNotEmpty
            ? implantStageController.errorMessage.value
            : 'فشل تحديث التاريخ',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: AppColors.white,
      );
    }
  }
}
