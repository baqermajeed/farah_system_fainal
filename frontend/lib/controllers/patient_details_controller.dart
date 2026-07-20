import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/gallery_controller.dart';
import 'package:farah_sys_final/controllers/implant_stage_controller.dart';
import 'package:farah_sys_final/controllers/medical_record_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/models/doctor_model.dart';
import 'package:farah_sys_final/services/chat_service.dart';
import 'package:farah_sys_final/services/patient_service.dart';
import 'package:farah_sys_final/services/working_hours_service.dart';

/// Controller لشاشة ملف المريض — يملك حالة الشاشة (التبويبات، وضع التحديد
/// المتعدد للمواعيد، عدد الرسائل غير المقروءة، أطباء المريض)، ويهيّئ
/// الـ controllers الفرعية الخاصة بهذه الشاشة (المعرض/السجلات الطبية)،
/// بينما يفوّض باقي العمليات إلى الـ controllers/services المشتركة.
class PatientDetailsController extends GetxController
    with GetSingleTickerProviderStateMixin {
  PatientController get patientController => Get.find<PatientController>();
  AppointmentController get appointmentController =>
      Get.find<AppointmentController>();
  AuthController get authController => Get.find<AuthController>();

  final PatientService patientService = PatientService();
  final ChatService chatService = ChatService();
  final WorkingHoursService workingHoursService = WorkingHoursService();
  final ImagePicker imagePicker = ImagePicker();

  late final GalleryController galleryController;
  late final MedicalRecordController medicalRecordController;

  late final TabController tabController;
  final RxInt currentTabIndex = 0.obs;

  String? patientId;
  AppointmentModel? selectedAppointmentArg;
  String? selectedAppointmentId;
  final Map<String, GlobalKey> appointmentItemKeys = {};
  final Map<String, GlobalKey> implantStageItemKeys = {};
  bool didAutoScrollToSelected = false;
  bool didAutoScrollToSelectedImplantStage = false;

  // Unread messages count
  final RxInt unreadCount = 0.obs;

  // State for doctors (receptionist view)
  final RxList<DoctorModel> patientDoctors = <DoctorModel>[].obs;
  final RxBool isLoadingDoctors = false.obs;

  // Selection mode state (appointments tab)
  final RxSet<String> selectedAppointmentIds = <String>{}.obs;
  final RxBool isSelectionMode = false.obs;

  @override
  void onInit() {
    super.onInit();

    // Get patientId (and optional selected appointment) from arguments
    final args = Get.arguments as Map<String, dynamic>?;
    patientId = args?['patientId'];
    final dynamic passedAppointment = args?['appointment'];
    if (passedAppointment is AppointmentModel) {
      selectedAppointmentArg = passedAppointment;
    }
    final dynamic passedAppointmentId = args?['appointmentId'];
    selectedAppointmentId =
        selectedAppointmentArg?.id ?? passedAppointmentId?.toString();

    // If we came from an appointment tap, open the "المواعيد" tab by default.
    tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: selectedAppointmentId != null ? 1 : 0,
    );

    // Keep an Rx mirror of the tab index for reactive UI updates.
    tabController.addListener(() {
      currentTabIndex.value = tabController.index;
    });

    galleryController = Get.put(GalleryController());
    medicalRecordController = Get.put(MedicalRecordController());
  }

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (patientId == null) return;

      final userType = authController.currentUser.value?.userType;
      final isReceptionist =
          userType != null && userType.toLowerCase() == 'receptionist';

      if (isReceptionist) {
        // For receptionist, ensure patients list is loaded so getPatientById works
        final patient = patientController.getPatientById(patientId!);
        if (patient == null) {
          await patientController.loadPatients();
        }
        loadPatientDoctors(patientId!);
      } else {
        // Only load appointments, gallery, and records for non-receptionists (doctors)
        appointmentController.loadPatientAppointmentsById(patientId!);
        galleryController.loadGallery(patientId!);
        medicalRecordController.loadPatientRecords(patientId!);
        loadUnreadCount();

        // Load implant stages if treatment type is زراعة
        final patient = patientController.getPatientById(patientId!);
        if (patient != null &&
            patient.treatmentHistory != null &&
            patient.treatmentHistory!.isNotEmpty &&
            patient.treatmentHistory!.first == 'زراعة') {
          final implantStageController = Get.put(ImplantStageController());
          implantStageController.ensureStagesLoaded(patientId!);
        }
      }
    });
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  void exitSelectionMode() {
    isSelectionMode.value = false;
    selectedAppointmentIds.clear();
  }

  void startSelectionWith(String appointmentId) {
    isSelectionMode.value = true;
    selectedAppointmentIds.add(appointmentId);
  }

  void toggleAppointmentSelected(String appointmentId) {
    if (selectedAppointmentIds.contains(appointmentId)) {
      selectedAppointmentIds.remove(appointmentId);
      if (selectedAppointmentIds.isEmpty) {
        isSelectionMode.value = false;
      }
    } else {
      selectedAppointmentIds.add(appointmentId);
    }
  }

  Future<void> deleteSelectedAppointments() async {
    if (patientId == null || selectedAppointmentIds.isEmpty) return;

    final idsToDelete = List<String>.from(selectedAppointmentIds);
    int successCount = 0;
    int failCount = 0;

    for (final appointmentId in idsToDelete) {
      try {
        await appointmentController.deleteAppointment(
          patientId!,
          appointmentId,
        );
        successCount++;
      } catch (e) {
        failCount++;
        print(
          '❌ [PatientDetailsController] Error deleting appointment $appointmentId: $e',
        );
      }
    }

    selectedAppointmentIds.clear();
    isSelectionMode.value = false;

    if (failCount == 0) {
      Get.snackbar(
        'نجح',
        'تم حذف $successCount موعد بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primary,
        colorText: AppColors.white,
      );
    } else {
      Get.snackbar(
        'تحذير',
        'تم حذف $successCount موعد، فشل حذف $failCount موعد',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: AppColors.white,
      );
    }
  }

  Future<void> loadUnreadCount() async {
    if (patientId == null) return;
    try {
      final chatList = await chatService.getChatList();
      final chat = chatList.firstWhere(
        (c) => c['patient_id']?.toString() == patientId,
        orElse: () => <String, dynamic>{},
      );
      final count = chat['unread_count'] as int? ?? 0;
      unreadCount.value = count;
    } catch (e) {
      print('❌ Error loading unread count: $e');
      unreadCount.value = 0;
    }
  }

  Future<void> loadPatientDoctors(String patientId) async {
    isLoadingDoctors.value = true;
    try {
      final doctors = await patientService.getPatientDoctors(patientId);
      patientDoctors.value = doctors;
    } catch (e) {
      patientDoctors.clear();
    } finally {
      isLoadingDoctors.value = false;
    }
  }
}
