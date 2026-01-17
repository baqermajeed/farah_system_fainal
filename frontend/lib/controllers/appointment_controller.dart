import 'dart:io';
import 'package:get/get.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/doctor_service.dart';
import 'package:farah_sys_final/core/network/api_exception.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';

class AppointmentController extends GetxController {
  final _patientService = PatientService();
  final _doctorService = DoctorService();
  
  final RxList<AppointmentModel> appointments = <AppointmentModel>[].obs;
  final RxList<AppointmentModel> primaryAppointments = <AppointmentModel>[].obs;
  final RxList<AppointmentModel> secondaryAppointments =
      <AppointmentModel>[].obs;
  final RxBool isLoading = false.obs;

  // جلب مواعيد المريض أو جميع المواعيد للاستقبال
  Future<void> loadPatientAppointments() async {
    try {
      print('📅 [AppointmentController] loadPatientAppointments called');
      isLoading.value = true;

      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;
      print('📅 [AppointmentController] User type: $userType');

      if (userType == 'receptionist') {
        // موظف الاستقبال: يجلب جميع المواعيد من /reception/appointments
        print('📅 [AppointmentController] Loading appointments for receptionist');
        final list = await _doctorService.getAllAppointmentsForReception();
        appointments.value = list;
        primaryAppointments.clear();
        secondaryAppointments.clear();
        print('📅 [AppointmentController] Loaded ${list.length} appointments for receptionist');
      } else {
        // المريض: يجلب مواعيده الخاصة من /patient/appointments
        print('📅 [AppointmentController] Loading appointments for patient');
        final result = await _patientService.getMyAppointments();
        primaryAppointments.value = result['primary'] ?? [];
        secondaryAppointments.value = result['secondary'] ?? [];

        // دمج المواعيد
        appointments.value = [...primaryAppointments, ...secondaryAppointments];
        print('📅 [AppointmentController] Loaded ${primaryAppointments.length} primary and ${secondaryAppointments.length} secondary appointments');
        print('📅 [AppointmentController] Total appointments: ${appointments.length}');
      }
    } on ApiException catch (e) {
      print('❌ [AppointmentController] ApiException: ${e.message}');
      Get.snackbar('خطأ', e.message);
    } catch (e, stackTrace) {
      print('❌ [AppointmentController] Error loading appointments: $e');
      print('❌ [AppointmentController] Stack trace: $stackTrace');
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المواعيد');
    } finally {
      isLoading.value = false;
      print('📅 [AppointmentController] loadPatientAppointments finished');
    }
  }

  // جلب مواعيد الطبيب أو جميع المواعيد للاستقبال
  Future<void> loadDoctorAppointments({
    String? day,
    String? dateFrom,
    String? dateTo,
    String? status,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      isLoading.value = true;
      
      final authController = Get.find<AuthController>();
      final userType = authController.currentUser.value?.userType;
      
      List<AppointmentModel> appointmentsList;
      
      if (userType == 'receptionist') {
        // موظف الاستقبال: يجلب جميع المواعيد من جميع الأطباء
        print('📅 [AppointmentController] Loading all appointments for receptionist');
        appointmentsList = await _doctorService.getAllAppointmentsForReception(
          day: day,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
          skip: skip,
          limit: limit,
        );
      } else {
        // الطبيب: يجلب مواعيده الخاصة
        print('📅 [AppointmentController] Loading appointments for doctor');
        appointmentsList = await _doctorService.getMyAppointments(
          day: day,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
          skip: skip,
          limit: limit,
        );
      }
      
      appointments.value = appointmentsList;
      print('📅 [AppointmentController] Loaded ${appointmentsList.length} appointments');
    } on ApiException catch (e) {
      Get.snackbar('خطأ', e.message);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المواعيد');
    } finally {
      isLoading.value = false;
    }
  }

  // جلب مواعيد مريض محدد (للطبيب)
  Future<void> loadPatientAppointmentsById(String patientId) async {
    try {
      isLoading.value = true;
      final appointmentsList = await _doctorService.getPatientAppointments(
        patientId,
      );
      // Filter by patient ID
      appointments.value = appointmentsList
          .where((apt) => apt.patientId == patientId)
          .toList();
    } on ApiException catch (e) {
      Get.snackbar('خطأ', e.message);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحميل المواعيد');
    } finally {
      isLoading.value = false;
    }
  }

  // حذف موعد (للطبيب)
  Future<void> deleteAppointment(String patientId, String appointmentId) async {
    try {
      isLoading.value = true;
      final success = await _doctorService.deleteAppointment(
        patientId,
        appointmentId,
      );

      if (success) {
        appointments.removeWhere((apt) => apt.id == appointmentId);
        Get.snackbar('نجح', 'تم حذف الموعد بنجاح');
      } else {
        throw ApiException('فشل حذف الموعد');
      }
    } on ApiException catch (e) {
      Get.snackbar('خطأ', e.message);
      rethrow;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء حذف الموعد');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // إضافة موعد جديد (للطبيب)
  Future<void> addAppointment({
    required String patientId,
    required DateTime scheduledAt,
    String? note,
    File? imageFile,
    List<File>? imageFiles,
  }) async {
    try {
      isLoading.value = true;
      final appointment = await _doctorService.addAppointment(
        patientId: patientId,
        scheduledAt: scheduledAt,
        note: note,
        imageFile: imageFile,
        imageFiles: imageFiles,
      );
      
      appointments.add(appointment);
      Get.snackbar('نجح', 'تم إضافة الموعد بنجاح');
    } on ApiException catch (e) {
      Get.snackbar('خطأ', e.message);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء إضافة الموعد');
    } finally {
      isLoading.value = false;
    }
  }

  // تحديث حالة الموعد (للطبيب)
  Future<void> updateAppointmentStatus(
    String patientId,
    String appointmentId,
    String status,
  ) async {
    try {
      isLoading.value = true;
      final updatedAppointment = await _doctorService.updateAppointmentStatus(
        patientId,
        appointmentId,
        status,
      );

      // تحديث الموعد في القائمة
      final index = appointments.indexWhere((apt) => apt.id == appointmentId);
      if (index != -1) {
        appointments[index] = updatedAppointment;
      }

      Get.snackbar('نجح', 'تم تحديث حالة الموعد بنجاح');
    } on ApiException catch (e) {
      Get.snackbar('خطأ', e.message);
      rethrow;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث حالة الموعد');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  List<AppointmentModel> getUpcomingAppointments() {
    final now = DateTime.now();
    return appointments.where((appointment) {
      return appointment.date.isAfter(now) && 
          (appointment.status == 'pending' ||
              appointment.status == 'scheduled');
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  List<AppointmentModel> getPastAppointments() {
    final now = DateTime.now();
    return appointments.where((appointment) {
      return appointment.date.isBefore(now) || 
             appointment.status == 'completed' ||
             appointment.status == 'cancelled';
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  // مواعيد اليوم
  List<AppointmentModel> getTodayAppointments() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return appointments.where((appointment) {
      final appointmentDate = appointment.date;
      return appointmentDate.isAfter(todayStart) && 
             appointmentDate.isBefore(todayEnd) &&
          (appointment.status == 'pending' ||
              appointment.status == 'scheduled');
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  // المواعيد المتأخرة (مواعيد فاتت ولم تكتمل)
  List<AppointmentModel> getLateAppointments() {
    final now = DateTime.now();
    return appointments.where((appointment) {
      return appointment.date.isBefore(now) && 
          (appointment.status == 'pending' ||
              appointment.status == 'scheduled');
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  // مواعيد هذا الشهر
  List<AppointmentModel> getThisMonthAppointments() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    
    return appointments.where((appointment) {
      final appointmentDate = appointment.date;
      return appointmentDate.isAfter(monthStart) && 
             appointmentDate.isBefore(monthEnd) &&
          (appointment.status == 'pending' ||
              appointment.status == 'scheduled');
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }
}
