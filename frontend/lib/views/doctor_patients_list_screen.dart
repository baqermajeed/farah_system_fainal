import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_back_button.dart';
import 'package:farah_sys_final/controllers/doctor_patients_list_controller.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_glass_card.dart';
import 'package:farah_sys_final/views/doctor/widgets/doctor_patient_list_tile.dart';

class DoctorPatientsListScreen extends GetView<DoctorPatientsListController> {
  const DoctorPatientsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            Expanded(child: _buildPatientsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          DoctorBackButton(
            onTap: () {
              final nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.pop();
              } else {
                Get.offAllNamed(AppRoutes.doctorHome);
              }
            },
          ),
          Expanded(
            child: Text(
              'جميع المرضى',
              style: AppFonts.lamaSans(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F2A44),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 44.w, height: 44.w),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: DoctorGlassCard(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        borderRadius: 16.r,
        child: TextField(
          controller: controller.searchController,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث عن مريض...',
            hintStyle: AppFonts.lamaSans(
              fontSize: 14.sp,
              color: AppColors.textHint,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 22.sp,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12.h),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    return Obx(() {
      final pc = controller.patientController;
      // قراءة قيم Rx مباشرة داخل Obx
      final isLoading = pc.isLoading.value;
      final isSearching = pc.isSearching.value;
      final searchText = controller.searchQuery.value;
      final isLoadingMore = controller.isLoadingMore;
      final hasMore = controller.hasMore;
      final patients = controller.displayedPatients;
      final isInitialLoading =
          (isLoading || isSearching) && patients.isEmpty;

      if (isInitialLoading) {
        return const LoadingWidget(message: 'جاري تحميل المرضى...');
      }

      if (patients.isEmpty) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.refreshList,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: 80.h),
              EmptyStateWidget(
                icon: Icons.people_outline,
                title: 'لا يوجد مرضى',
                subtitle: searchText.isEmpty
                    ? 'لم يتم إضافة أي مريض بعد'
                    : 'لم يتم العثور على نتائج',
              ),
            ],
          ),
        );
      }

      final showFooter = hasMore || isLoadingMore;

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refreshList,
        child: ListView.builder(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          cacheExtent: 400,
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          itemCount: patients.length + (showFooter ? 1 : 0),
          itemBuilder: (_, index) {
            if (index >= patients.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Center(
                  child: SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              );
            }
            return _buildPatientCard(patients[index]);
          },
        ),
      );
    });
  }

  Widget _buildPatientCard(PatientModel patient) {
    return DoctorPatientListTile(
      patient: patient,
      onTap: () => controller.openPatientDetails(patient),
      onChatTap: () => controller.openChat(patient),
    );
  }

}
