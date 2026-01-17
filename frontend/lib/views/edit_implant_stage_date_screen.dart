import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/custom_button.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/implant_stage_controller.dart';
import 'package:farah_sys_final/controllers/working_hours_controller.dart';

class EditImplantStageDateScreen extends StatefulWidget {
  const EditImplantStageDateScreen({super.key});

  @override
  State<EditImplantStageDateScreen> createState() => _EditImplantStageDateScreenState();
}

class _EditImplantStageDateScreenState extends State<EditImplantStageDateScreen> {
  DateTime? selectedDate;
  String? selectedTime;
  List<String> availableSlots = [];
  bool isLoadingSlots = false;
  
  late final WorkingHoursController _workingHoursController;
  late final ImplantStageController _implantStageController;
  
  String? patientId;
  String? stageName;
  DateTime? currentDate;

  @override
  void initState() {
    super.initState();
    _implantStageController = Get.find<ImplantStageController>();
    _workingHoursController = Get.put(WorkingHoursController());
    
    final args = Get.arguments as Map<String, dynamic>?;
    patientId = args?['patientId'];
    stageName = args?['stageName'];
    currentDate = args?['currentDate'] as DateTime?;
    
    if (currentDate != null) {
      selectedDate = currentDate;
      // تحويل الوقت إلى تنسيق 12 ساعة
      final hour = currentDate!.hour;
      final minute = currentDate!.minute;
      final isPM = hour >= 12;
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      selectedTime = '$displayHour:${minute.toString().padLeft(2, '0')} ${isPM ? 'م' : 'ص'}';
    }
    
    // تحميل أوقات العمل
    _workingHoursController.loadWorkingHours();
  }

  Future<void> _loadAvailableSlots(DateTime date) async {
    if (patientId == null) return;
    
    setState(() {
      isLoadingSlots = true;
    });
    
    try {
      // الحصول على معرف الطبيب من المريض
      // هنا نحتاج إلى معرف الطبيب، لكن يمكننا استخدام أول طبيب
      // في الواقع، يجب أن نحصل على معرف الطبيب من المريض
      // لكن للتبسيط، سنستخدم طريقة أخرى
      
      // سنستخدم طريقة بسيطة: عرض جميع الأوقات المتاحة
      // في التطبيق الحقيقي، يجب جلب الأوقات المتاحة من API
      setState(() {
        availableSlots = [];
        isLoadingSlots = false;
      });
    } catch (e) {
      setState(() {
        availableSlots = [];
        isLoadingSlots = false;
      });
    }
  }
  //line 83

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFF),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: ui.TextDirection.ltr, // keep back button on LEFT always
          child: AppBar(
            backgroundColor: const Color(0xFFF4FEFF),
            elevation: 0,
            leading: const BackButtonWidget(),
            leadingWidth: 56.w,
            title: const Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Text(
                'تعديل تاريخ المرحلة',
              ),
            ),
            titleTextStyle: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stageName != null) ...[
              Text(
                'المرحلة: $stageName',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 24.h),
            ],
            
            // اختيار التاريخ
            Text(
              'اختر التاريخ',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  locale: const Locale('ar', 'SA'),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                    selectedTime = null; // إعادة تعيين الوقت عند تغيير التاريخ
                  });
                  await _loadAvailableSlots(picked);
                }
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.primary),
                    Text(
                      selectedDate != null
                          ? DateFormat('yyyy-MM-dd', 'ar').format(selectedDate!)
                          : 'اختر التاريخ',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: selectedDate != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // اختيار الوقت
            Text(
              'اختر الوقت',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: () async {
                if (selectedDate == null) {
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
                  initialTime: selectedTime != null
                      ? TimeOfDay(
                          hour: int.parse(selectedTime!.split(':')[0]),
                          minute: int.parse(selectedTime!.split(':')[1].split(' ')[0]),
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
                  setState(() {
                    final hour = picked.hour;
                    final minute = picked.minute;
                    final isPM = hour >= 12;
                    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                    selectedTime = '$displayHour:${minute.toString().padLeft(2, '0')} ${isPM ? 'م' : 'ص'}';
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.access_time, color: AppColors.primary),
                    Text(
                      selectedTime ?? 'اختر الوقت',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: selectedTime != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 32.h),
            
            // زر الحفظ
            CustomButton(
              text: 'حفظ التغييرات',
              onPressed: selectedDate != null && selectedTime != null
                  ? () async {
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
                      final isPM = selectedTime!.contains('م');
                      final timeStr = selectedTime!
                          .replaceAll(' م', '')
                          .replaceAll(' ص', '')
                          .trim();
                      final timeParts = timeStr.split(':');
                      var hour = int.parse(timeParts[0]);
                      final minute = timeParts.length > 1
                          ? int.parse(timeParts[1])
                          : 0;
                      
                      if (isPM && hour != 12) {
                        hour += 12;
                      } else if (!isPM && hour == 12) {
                        hour = 0;
                      }
                      
                      final success = await _implantStageController.updateStageDate(
                        patientId!,
                        stageName!,
                        selectedDate!,
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
                          _implantStageController.errorMessage.value.isNotEmpty
                              ? _implantStageController.errorMessage.value
                              : 'فشل تحديث التاريخ',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: AppColors.white,
                        );
                      }
                    }
                  : null,
              backgroundColor: AppColors.primary,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

