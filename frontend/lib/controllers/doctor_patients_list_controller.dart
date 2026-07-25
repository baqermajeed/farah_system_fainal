import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/models/patient_model.dart';

/// Controller لشاشة قائمة مرضى الطبيب — pagination من السيرفر (مثل frontend_desktop).
class DoctorPatientsListController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final RxString searchQuery = ''.obs;
  final RxString activeFilter = 'all'.obs;

  Timer? _searchDebounce;

  static const filters = <String, String>{
    'all': 'الكل',
    'active': 'نشط',
    'followup': 'متابعة',
    'finished': 'انتهى العلاج',
  };

  PatientController get patientController => Get.find<PatientController>();

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_onSearchChanged);
    scrollController.addListener(_onScroll);
  }

  @override
  void onReady() {
    super.onReady();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final pc = patientController;
      if (pc.patients.isEmpty && !pc.isLoading.value && !pc.isDoctorSearching) {
        pc.loadPatients(isInitial: true, isRefresh: false);
      }
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    searchController.removeListener(_onSearchChanged);
    scrollController.removeListener(_onScroll);
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void _onSearchChanged() {
    final query = searchController.text;
    searchQuery.value = query;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final trimmed = query.trim();
      if (trimmed.isEmpty) {
        patientController.clearDoctorSearch();
      } else {
        patientController.searchDoctorPatients(searchQuery: trimmed);
      }
    });
  }

  /// تحميل المزيد عند الاقتراب من نهاية القائمة — نفس منطق frontend_desktop.
  void _onScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.pixels < position.maxScrollExtent - 200) return;

    final pc = patientController;
    if (pc.isDoctorSearching) {
      if (pc.hasMoreSearchResults.value && !pc.isLoadingMoreSearch.value) {
        pc.loadMoreSearchResults();
      }
    } else if (pc.hasMorePatients.value && !pc.isLoadingMorePatients.value) {
      pc.loadMorePatients();
    }
  }

  List<PatientModel> get displayedPatients {
    final pc = patientController;
    final raw = pc.lastSearchQuery.value.trim().isNotEmpty
        ? pc.searchResults
        : pc.patients;
    return raw.where(_matchesFilter).toList(growable: false);
  }

  bool get isLoadingMore {
    if (patientController.isDoctorSearching) {
      return patientController.isLoadingMoreSearch.value;
    }
    return patientController.isLoadingMorePatients.value;
  }

  bool get hasMore {
    if (patientController.isDoctorSearching) {
      return patientController.hasMoreSearchResults.value;
    }
    return patientController.hasMorePatients.value;
  }

  bool _matchesFilter(PatientModel patient) {
    switch (activeFilter.value) {
      case 'active':
        return patient.treatmentHistory != null &&
            patient.treatmentHistory!.isNotEmpty;
      case 'followup':
        return patient.treatmentHistory != null &&
            patient.treatmentHistory!.length > 1;
      case 'finished':
        return patient.treatmentHistory == null ||
            patient.treatmentHistory!.isEmpty;
      default:
        return true;
    }
  }

  void setFilter(String filter) {
    activeFilter.value = filter;
  }

  Future<void> refreshList() async {
    final query = searchController.text.trim();
    if (query.isNotEmpty) {
      await patientController.searchDoctorPatients(searchQuery: query);
    } else {
      await patientController.loadPatients(isInitial: false, isRefresh: true);
    }
  }

  void openPatientDetails(PatientModel patient) {
    patientController.selectPatient(patient);
    Get.toNamed(
      AppRoutes.patientDetails,
      arguments: {'patientId': patient.id},
    );
  }

  void openChat(PatientModel patient) {
    Get.toNamed(
      AppRoutes.chat,
      arguments: {
        'patientId': patient.id,
        'patientName': patient.name,
        'patientImageUrl': patient.imageUrl,
      },
    );
  }

  Future<bool?> addPatientAndReload() async {
    final result = await Get.toNamed(AppRoutes.addPatient);
    await patientController.refreshDoctorPatients();
    return result as bool?;
  }
}
