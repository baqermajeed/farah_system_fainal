import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/controllers/appointment_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';

/// Controller لشاشة مواعيد الطبيب — تصفية من السيرفر + pagination.
/// التبويبات: اليوم / هذا الشهر / المتأخرون.
/// التصفية المخصصة (من-إلى) عبر زر الفلترة في الهيدر فقط.
class AppointmentsScreenController extends GetxController
    with GetSingleTickerProviderStateMixin {
  static const List<String> tabFilters = [
    'اليوم',
    'هذا الشهر',
    'المتأخرون',
  ];

  static const String customFilter = 'تصفية مخصصة';

  AppointmentController get appointmentController =>
      Get.find<AppointmentController>();
  PatientController get patientController => Get.find<PatientController>();

  late final TabController tabController;

  final RxString currentFilter = 'هذا الشهر'.obs;

  DateTime? customFilterStart;
  DateTime? customFilterEnd;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    tabController.addListener(_onTabChanged);
  }

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadForFilter(
        currentFilter.value,
        isInitial: true,
        isRefresh: false,
      );
      if (patientController.patients.isEmpty) {
        patientController.reloadPatientsList();
      }
    });
  }

  @override
  void onClose() {
    tabController.removeListener(_onTabChanged);
    tabController.dispose();
    super.onClose();
  }

  void _onTabChanged() {
    if (tabController.indexIsChanging) return;
    handleTabIndex(tabController.index);
  }

  void handleTabIndex(int index) {
    if (index < 0 || index >= tabFilters.length) return;
    final newFilter = tabFilters[index];
    if (newFilter == currentFilter.value) return;
    loadForFilter(newFilter);
  }

  void loadForFilter(
    String filter, {
    DateTime? start,
    DateTime? end,
    bool isInitial = false,
    bool isRefresh = true,
  }) {
    currentFilter.value = filter;
    if (start != null) customFilterStart = start;
    if (end != null) customFilterEnd = end;

    appointmentController.appointments.clear();
    appointmentController.loadDoctorAppointments(
      isInitial: isInitial,
      isRefresh: isRefresh,
      filter: filter,
      customFilterStart: customFilterStart,
      customFilterEnd: customFilterEnd,
    );
  }

  void rememberCustomRange(DateTime start, DateTime end) {
    customFilterStart = start;
    customFilterEnd = end;
  }

  void loadMore() {
    appointmentController.loadMoreAppointments(
      filter: currentFilter.value,
      customFilterStart: customFilterStart,
      customFilterEnd: customFilterEnd,
    );
  }

  Future<void> refreshAppointments() async {
    await appointmentController.loadDoctorAppointments(
      isInitial: true,
      isRefresh: true,
      filter: currentFilter.value,
      customFilterStart: customFilterStart,
      customFilterEnd: customFilterEnd,
    );
    if (patientController.patients.isEmpty) {
      await patientController.reloadPatientsList();
    }
  }
}
