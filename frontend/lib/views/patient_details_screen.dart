import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/iraq_governorates.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/core/utils/network_utils.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/working_hours_controller.dart';
import 'package:farah_sys_final/controllers/implant_stage_controller.dart';
import 'package:farah_sys_final/controllers/patient_details_controller.dart';
import 'package:farah_sys_final/models/implant_stage_model.dart';
import 'package:farah_sys_final/models/medical_record_model.dart';
import 'package:farah_sys_final/models/appointment_model.dart';
import 'package:farah_sys_final/models/doctor_model.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:farah_sys_final/widgets/portrait_network_image.dart';
import 'package:farah_sys_final/widgets/dental_chart/patient_dental_chart_tab.dart';

// Shared shadow used in patient UI cards.
const List<BoxShadow> kPatientFileShadow = [
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 12,
    offset: Offset(0, 6),
  ),
];

const Color _kPatientProfileNavy = Color(0xFF1E3A5F);
const Color _kPatientProfileGray = Color(0xFF8A97A8);
const Color _kPatientProfileBg = Color(0xFFF8FAFC);
const Color _kPatientProfileBlue = Color(0xFF4A88B8);
const Color _kPatientProfileNavyDark = Color(0xFF162D4A);
const Color _kPatientProfileDivider = Color(0xFFE8ECF0);

const LinearGradient _kPatientProfileGradient = LinearGradient(
  colors: [_kPatientProfileNavyDark, _kPatientProfileBlue],
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
);

class _PatientDetailsAssets {
  static const back = 'assets/icon/backblack.png';
  static const chat = 'assets/icon/chatddd.png';
}

const double _kPatientHeaderButtonSize = 50;
const double _kPatientHeaderButtonRadius = 16;

const List<BoxShadow> _kPatientHeaderButtonShadow = [
  BoxShadow(
    color: Color(0x1F000000),
    blurRadius: 8,
    offset: Offset.zero,
  ),
];

// Delegate for sticky TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => 56.0;

  @override
  double get maxExtent => 56.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class PatientDetailsScreen extends GetView<PatientDetailsController> {
  const PatientDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final cairoTheme = baseTheme.copyWith(
      textTheme: AppFonts.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppFonts.textTheme(baseTheme.primaryTextTheme),
    );

    return Theme(
      data: cairoTheme,
      child: Scaffold(
        backgroundColor: _kPatientProfileBg,
        floatingActionButton: Obx(() {
          final showFab = controller.currentTabIndex.value == 1 &&
              controller.isSelectionMode.value &&
              controller.selectedAppointmentIds.isNotEmpty;
          if (!showFab) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => _showDeleteConfirmDialog(context),
            backgroundColor: Colors.red,
            icon: Icon(Icons.delete, color: AppColors.white),
            label: Text(
              'حذف (${controller.selectedAppointmentIds.length})',
              style: AppFonts.lamaSans(color: AppColors.white),
            ),
          );
        }),
        body: SafeArea(
          child: Obx(() {
          final userType = controller.authController.currentUser.value?.userType;
          final isReceptionist =
              userType != null && userType.toLowerCase() == 'receptionist';

          return Column(
            children: [
              Expanded(
                child: NestedScrollView(
                  headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                    return <Widget>[
                      // Header with light blue background
                      SliverAppBar(
                        backgroundColor: _kPatientProfileBg,
                        pinned: false,
                        floating: false,
                        expandedHeight: 0,
                        toolbarHeight: 64.h,
                        automaticallyImplyLeading: false,
                        flexibleSpace: Container(
                          color: _kPatientProfileBg,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          child: Row(
                            textDirection: ui.TextDirection.ltr,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const BackButtonWidget(
                                assetPath: _PatientDetailsAssets.back,
                                size: _kPatientHeaderButtonSize,
                              ),
                              Expanded(
                                child: Text(
                                  'ملف المريض',
                                  textAlign: TextAlign.center,
                                  style: AppFonts.lamaSans(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: _kPatientProfileNavy,
                                  ),
                                ),
                              ),
                              if (controller.isSelectionMode.value)
                                GestureDetector(
                                  onTap: controller.exitSelectionMode,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8.w),
                                    child: Text(
                                      'إلغاء',
                                      style: AppFonts.lamaSans(
                                        fontSize: 14.sp,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                              else if (!isReceptionist)
                                GestureDetector(
                                  onTap: () async {
                                    if (controller.patientId != null) {
                                      await Get.toNamed(
                                        AppRoutes.chat,
                                        arguments: {
                                          'patientId': controller.patientId,
                                        },
                                      );
                                      await Future.delayed(
                                        const Duration(milliseconds: 300),
                                      );
                                      controller.loadUnreadCount();
                                    }
                                  },
                                  child: Obx(() {
                                    final hasUnread =
                                        controller.unreadCount.value > 0;
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        _buildHeaderIconButton(
                                          child: Image.asset(
                                            _PatientDetailsAssets.chat,
                                            width: 30.w,
                                            height: 30.w,
                                          ),
                                        ),
                                        if (hasUnread)
                                          Positioned(
                                            top: 2.h,
                                            right: 2.w,
                                            child: Container(
                                              width: 10.w,
                                              height: 10.w,
                                              decoration: BoxDecoration(
                                                color: AppColors.error,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                )
                              else
                                SizedBox(
                                  width: _kPatientHeaderButtonSize.w,
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Patient Information Card
                      SliverToBoxAdapter(
                        child: Obx(() {
                          controller.patientController.selectedPatient.value;
                          controller.patientController.searchResults.length;
                          controller.isLoadingPatientProfile.value;

                          if (controller.isLoadingPatientProfile.value) {
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 24.h,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final patient = controller.patientId != null
                              ? controller.patientController
                                  .getPatientById(controller.patientId!)
                              : null;

                          if (patient == null) {
                            return const SizedBox.shrink();
                          }

                          final userType =
                              controller.authController.currentUser.value?.userType;
                          final isReceptionist =
                              userType != null &&
                              userType.toLowerCase() == 'receptionist';

                          return Column(
                            children: [
                              _buildRefinedPatientInfoCard(
                                context,
                                patient,
                                isReceptionist,
                              ),

                              // Doctors Section (only for receptionist)
                              if (isReceptionist) ...[
                                SizedBox(height: 24.h),
                                _buildDoctorsSection(patient),
                              ],
                            ],
                          );
                        }),
                      ),

                      // Tabs - Sticky Header (only for non-receptionist)
                      if (!isReceptionist)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverTabBarDelegate(
                            child: Container(
                              height: 56.0,
                              margin: EdgeInsets.symmetric(horizontal: 16.w),
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: TabBar(
                                controller: controller.tabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                indicator: BoxDecoration(
                                  color: _kPatientProfileNavy,
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _kPatientProfileNavy
                                          .withValues(alpha: 0.22),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                labelColor: Colors.white,
                                unselectedLabelColor: _kPatientProfileGray,
                                labelStyle: AppFonts.lamaSans(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                                unselectedLabelStyle: AppFonts.lamaSans(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                tabs: const [
                                  Tab(text: 'السجلات'),
                                  Tab(text: 'المواعيد'),
                                  Tab(text: 'المعرض'),
                                  Tab(text: 'Dental Chart'),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ];
                  },
                  body: isReceptionist
                      ? Container(color: _kPatientProfileBg)
                      : TabBarView(
                          controller: controller.tabController,
                          children: [
                            _buildRecordsTab(),
                            _buildAppointmentsTab(),
                            _buildGalleryTab(),
                            _buildDentalChartTab(),
                          ],
                        ),
                ),
              ),

              // Button at the bottom
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                child: Obx(() {
                  final patient = controller.patientId != null
                      ? controller.patientController.getPatientById(controller.patientId!)
                      : null;

                  final userTypeForButton =
                      controller.authController.currentUser.value?.userType;
                  final isReceptionistForButton =
                      userTypeForButton != null &&
                      userTypeForButton.toLowerCase() == 'receptionist';

                  if (isReceptionistForButton) {
                    // For receptionist: show "تحويل" button
                    return Container(
                      width: double.infinity,
                      height: 52.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF162D4A), Color(0xFF4A88B8)],
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A88B8).withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (patient != null) {
                            Get.toNamed(
                              AppRoutes.selectDoctor,
                              arguments: {
                                'patientId': patient.id,
                                'currentDoctorIds': patient.doctorIds,
                              },
                            )?.then((result) async {
                              if (result == true && controller.patientId != null) {
                                await controller.loadPatientDoctors(controller.patientId!);
                                await controller.patientController.loadPatients();
                              }
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          'تحويل',
                          style: AppFonts.lamaSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    );
                  } else {
                    // For doctor: show dynamic button based on selected tab
                    final tabIndex = controller.currentTabIndex.value;

                    // التحقق من نوع العلاج - إخفاء زر حجز الموعد إذا كان "زراعة"
                    final isImplantTreatment =
                        patient != null &&
                        patient.treatmentHistory != null &&
                        patient.treatmentHistory!.isNotEmpty &&
                        patient.treatmentHistory!.first == 'زراعة';

                    // إخفاء الزر في تبويب Dental Chart أو tab المواعيد مع زراعة
                    if (tabIndex == 3) {
                      return SizedBox.shrink();
                    }

                    // إخفاء الزر إذا كان tab المواعيد ونوع العلاج "زراعة"
                    if (tabIndex == 1 && isImplantTreatment) {
                      return SizedBox.shrink();
                    }

                    return Container(
                      width: double.infinity,
                      height: 52.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF162D4A), Color(0xFF4A88B8)],
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A88B8).withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          _onButtonPressed(context, tabIndex);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          _getButtonText(tabIndex),
                          style: AppFonts.lamaSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    );
                  }
                }),
              ),
            ],
          );
          }),
        ),
      ),
    );
  }

  /// Scrollable wrapper required for TabBarView inside NestedScrollView.
  Widget _tabFillScroll(Widget child) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: child,
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({required Widget child}) {
    return Container(
      width: _kPatientHeaderButtonSize.w,
      height: _kPatientHeaderButtonSize.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kPatientHeaderButtonRadius.r),
        boxShadow: _kPatientHeaderButtonShadow,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _buildRefinedPatientInfoCard(
    BuildContext context,
    PatientModel patient,
    bool isReceptionist,
  ) {
    final gender = patient.gender == 'male'
        ? 'ذكر'
        : patient.gender == 'female'
            ? 'أنثى'
            : patient.gender;
    final treatment = patient.treatmentHistory != null &&
            patient.treatmentHistory!.isNotEmpty
        ? patient.treatmentHistory!.last
        : 'لا يوجد';

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF162D4A).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4.h,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF162D4A), Color(0xFF4A88B8)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
              child: Directionality(
                textDirection: ui.TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _showPatientImageDialog(context, patient),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: SizedBox(
                              width: 56.w,
                              height: 56.w,
                              child: PortraitNetworkImage(
                                imageUrl: patient.imageUrl,
                                borderRadius: BorderRadius.zero,
                                showSkeleton: true,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _patientInfoLabelChip('الاسم'),
                              SizedBox(height: 4.h),
                              Text(
                                patient.name,
                                style: AppFonts.lamaSans(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: _kPatientProfileNavy,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        _patientInfoActionButton(
                          size: 36.w,
                          onTap: () => _showEditPatientProfileDialog(
                            context,
                            patient,
                            isReceptionist,
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Divider(
                        color: const Color(0xFFE8ECF0),
                        height: 1,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _patientDetailLine(
                                      'العمر',
                                      '${patient.age} سنة',
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: _patientDetailLine(
                                      'الجنس',
                                      gender,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              _patientDetailLine('الهاتف', patient.phoneNumber),
                              SizedBox(height: 4.h),
                              _patientDetailLine('المدينة', patient.city),
                              SizedBox(height: 4.h),
                              _patientDetailLine('العلاج', treatment),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _patientInfoQrButton(
                              patientId: patient.id,
                              onTap: () =>
                                  _showQrCodeDialog(context, patient.id),
                            ),
                            if (!isReceptionist) ...[
                              SizedBox(height: 8.h),
                              _patientInfoActionButton(
                                size: 36.w,
                                onTap: () => _showTreatmentTypeDialog(
                                  context,
                                  patient,
                                ),
                                child: Image.asset(
                                  'assets/icon/implanticon.png',
                                  width: 20.w,
                                  height: 20.w,
                                  color: Colors.white,
                                  colorBlendMode: BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientInfoLabelChip(String label) {
    return Container(
      width: 52.w,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFF162D4A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Text(
        label,
        style: AppFonts.lamaSans(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4A88B8),
        ),
      ),
    );
  }

  Widget _patientInfoActionButton({
    required double size,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF162D4A), Color(0xFF4A88B8)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: child,
      ),
    );
  }

  Widget _patientInfoQrButton({
    required String patientId,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48.w,
        height: 48.w,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFF4A88B8),
            width: 1.5,
          ),
        ),
        child: RepaintBoundary(
          child: QrImageView(
            data: patientId,
            version: QrVersions.auto,
            size: 36.w,
            gapless: false,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _patientDetailLine(String label, String value) {
    return SizedBox(
      height: 22.h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _patientInfoLabelChip(label),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              value,
              style: AppFonts.lamaSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: _kPatientProfileNavy,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTab() {
    return Obx(() {
      if (controller.medicalRecordController.isLoading.value) {
        return _tabFillScroll(
          Container(
            color: _kPatientProfileBg,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        );
      }

      final records = controller.medicalRecordController.records
          .where((record) => record.patientId == controller.patientId)
          .toList();

      if (records.isEmpty) {
        return _tabFillScroll(
          Container(
            color: _kPatientProfileBg,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Container(
                  width: 88.w,
                  height: 88.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _kPatientProfileNavy.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    size: 40.sp,
                    color: _kPatientProfileGray.withValues(alpha: 0.45),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا يوجد سجلات',
                  style: AppFonts.lamaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: _kPatientProfileGray,
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      }

      return Container(
        color: _kPatientProfileBg,
        child: ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return _buildRecordCard(context, record);
          },
        ),
      );
    });
  }

  Widget _buildRecordCard(BuildContext context, MedicalRecordModel record) {
    final hasNote = record.notes != null && record.notes!.isNotEmpty;
    final hasImages = record.images != null && record.images!.isNotEmpty;
    final formattedDate = DateFormat('dd/MM/yyyy', 'ar').format(record.date);

    return GestureDetector(
      onLongPress: () => _showRecordOptionsDialog(context, record),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64748B).withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            textDirection: ui.TextDirection.rtl,
            children: [
              Container(
                width: 4.w,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A88B8), Color(0xFF162D4A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasNote)
                        Text(
                          record.notes!,
                          style: AppFonts.lamaSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: _kPatientProfileNavy,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.right,
                        )
                      else
                        Text(
                          'سجل طبي',
                          style: AppFonts.lamaSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: _kPatientProfileGray,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      if (hasImages) ...[
                        SizedBox(height: 6.h),
                        SizedBox(
                          height: 60.h,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: record.images!.length,
                            separatorBuilder: (_, __) => SizedBox(width: 8.w),
                            itemBuilder: (context, imgIndex) {
                              return _buildRecordImageThumb(
                                context,
                                record.images![imgIndex],
                              );
                            },
                          ),
                        ),
                      ],
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF4F9),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_rounded,
                                  size: 13.sp,
                                  color: const Color(0xFF4A88B8),
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  formattedDate,
                                  style: AppFonts.lamaSans(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _kPatientProfileNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showDeleteRecordConfirmDialog(
                                context,
                                record,
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                              child: Padding(
                                padding: EdgeInsets.all(4.w),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20.sp,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordImageThumb(BuildContext context, String imagePath) {
    final imageUrl = ImageUtils.convertToValidUrl(imagePath);
    final isValid =
        imageUrl != null && ImageUtils.isValidImageUrl(imageUrl);

    return GestureDetector(
      onTap: () {
        if (isValid) {
          _showRecordImageDialog(context, imageUrl);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: SizedBox(
          width: 60.w,
          height: 60.h,
          child: isValid
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(
                      child: SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4A88B8),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFFF1F5F9),
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: _kPatientProfileGray,
                      size: 22.sp,
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: _kPatientProfileGray,
                    size: 22.sp,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    // التحقق من نوع العلاج
    final patient = controller.patientId != null
        ? controller.patientController.getPatientById(controller.patientId!)
        : null;

    final isImplantTreatment =
        patient != null &&
        patient.treatmentHistory != null &&
        patient.treatmentHistory!.isNotEmpty &&
        patient.treatmentHistory!.first == 'زراعة';

    // إذا كان نوع العلاج زراعة، نعرض المراحل
    if (isImplantTreatment) {
      return _buildImplantStagesView();
    }

    // في وضع العرض، نستخدم Obx فقط عند الحاجة
    final appointments = controller.appointmentController.appointments
        .where((apt) => apt.patientId == controller.patientId)
        .toList();

    if (appointments.isEmpty) {
      return _tabFillScroll(
        Container(
          color: _kPatientProfileBg,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                width: 100.w,
                height: 100.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.divider,
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 50.sp,
                  color: AppColors.textHint,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'لا يوجد مواعيد',
                style: TextStyle(fontSize: 16.sp, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ),
      );
    }

    return Obx(() {
      final updatedAppointments = controller.appointmentController.appointments
          .where((apt) => apt.patientId == controller.patientId)
          .toList();

      if (updatedAppointments.isEmpty) {
        return _tabFillScroll(
          Container(
            color: _kPatientProfileBg,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.divider,
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 50.sp,
                    color: AppColors.textHint,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا يوجد مواعيد',
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ),
        );
      }

      final now = DateTime.now();
      final patient = controller.patientId != null
          ? controller.patientController.getPatientById(controller.patientId!)
          : null;

      // Sort appointments: upcoming first, then past
      final sortedAppointments = List<AppointmentModel>.from(
        updatedAppointments,
      );
      sortedAppointments.sort((a, b) {
        // تحديد المواعيد القادمة: فقط المواعيد بحالة scheduled/pending
        final aStatus = a.status.toLowerCase();
        final bStatus = b.status.toLowerCase();
        final aIsUpcoming =
            (aStatus == 'scheduled' || aStatus == 'pending') &&
            (a.date.isAfter(now) ||
                a.date.isAfter(now.subtract(Duration(hours: 1))));
        final bIsUpcoming =
            (bStatus == 'scheduled' || bStatus == 'pending') &&
            (b.date.isAfter(now) ||
                b.date.isAfter(now.subtract(Duration(hours: 1))));
        if (aIsUpcoming != bIsUpcoming) {
          return aIsUpcoming ? -1 : 1; // Upcoming first
        }
        return a.date.compareTo(b.date) *
            (aIsUpcoming
                ? 1
                : -1); // Upcoming: oldest first, Past: newest first
      });

      // Auto-scroll to the tapped appointment card (one attempt only).
      if (!controller.didAutoScrollToSelected &&
          controller.selectedAppointmentId != null) {
        controller.didAutoScrollToSelected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final key = controller
              .appointmentItemKeys[controller.selectedAppointmentId!];
          final ctx = key?.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.1,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          }
        });
      }

      return Container(
        color: _kPatientProfileBg,
        child: ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: sortedAppointments.length,
          itemBuilder: (context, index) {
            final appointment = sortedAppointments[index];
            final appointmentStatus = appointment.status.toLowerCase();

            // تحديد إذا كان الموعد قادم أم سابق بناءً على الحالة
            final isUpcoming =
                appointmentStatus == 'scheduled' &&
                (appointment.date.isAfter(now) ||
                    appointment.date.isAfter(now.subtract(Duration(hours: 1))));

            final isSelected = controller.selectedAppointmentIds.contains(appointment.id);

            // تحديد حالة Checkbox بناءً على status
            final bool isCompleted = appointmentStatus == 'completed';
            final bool isCancelled =
                appointmentStatus == 'cancelled' ||
                appointmentStatus == 'canceled' ||
                appointmentStatus == 'no_show';
            final bool isPending =
                appointmentStatus == 'scheduled' ||
                appointmentStatus == 'pending';

            // Format date in Arabic
            String formattedDate = '';
            try {
              final dayName = DateFormat('EEEE', 'ar').format(appointment.date);
              final dateStr = DateFormat(
                'yyyy-MM-dd',
                'ar',
              ).format(appointment.date);
              formattedDate = 'يوم $dayName المصادف $dateStr';
            } catch (e) {
              formattedDate = DateFormat(
                'yyyy-MM-dd',
                'ar',
              ).format(appointment.date);
            }

            // Format time
            String formattedTime = '';
            try {
              final timeParts = appointment.time.split(':');
              if (timeParts.length >= 2) {
                final hour = int.parse(timeParts[0]);
                final minute = timeParts[1];
                final period = hour >= 12 ? 'مساءاً' : 'صباحاً';
                final displayHour = hour > 12
                    ? hour - 12
                    : (hour == 0 ? 12 : hour);
                formattedTime = '$displayHour:$minute $period';
              } else {
                formattedTime = appointment.time;
              }
            } catch (e) {
              formattedTime = appointment.time;
            }

            final itemKey = controller.appointmentItemKeys.putIfAbsent(
              appointment.id,
              () => GlobalKey(),
            );

            return _buildAppointmentCard(
              context,
              appointment: appointment,
              itemKey: itemKey,
              patient: patient,
              isUpcoming: isUpcoming,
              isSelected: isSelected,
              isCompleted: isCompleted,
              isCancelled: isCancelled,
              isPending: isPending,
              appointmentStatus: appointmentStatus,
              formattedDate: formattedDate,
              formattedTime: formattedTime,
            );
          },
        ),
      );
    });
  }

  Color _appointmentAccentColor({
    required bool isCompleted,
    required bool isCancelled,
  }) {
    if (isCompleted) return AppColors.success;
    if (isCancelled) return AppColors.error;
    return AppColors.warning;
  }

  Widget _buildAppointmentCard(
    BuildContext context, {
    required AppointmentModel appointment,
    required GlobalKey itemKey,
    required PatientModel? patient,
    required bool isUpcoming,
    required bool isSelected,
    required bool isCompleted,
    required bool isCancelled,
    required bool isPending,
    required String appointmentStatus,
    required String formattedDate,
    required String formattedTime,
  }) {
    final accentColor = _appointmentAccentColor(
      isCompleted: isCompleted,
      isCancelled: isCancelled,
    );
    final hasNote =
        appointment.notes != null && appointment.notes!.isNotEmpty;
    final imagesToShow = appointment.imagePaths.isNotEmpty
        ? appointment.imagePaths
        : (appointment.imagePath != null && appointment.imagePath!.isNotEmpty
            ? [appointment.imagePath!]
            : <String>[]);
    final statusLabel = isCompleted
        ? 'مكتمل'
        : (isCancelled
            ? (appointmentStatus == 'no_show' ? 'لم يحضر' : 'ملغي')
            : 'قيد الانتظار');
    final title = isPending && isUpcoming
        ? 'موعد مريضك "${patient?.name ?? ''}" القادم هو'
        : 'موعد مريضك "${patient?.name ?? ''}" السابق هو';

    return KeyedSubtree(
      key: itemKey,
      child: GestureDetector(
        onLongPress: () {
          controller.startSelectionWith(appointment.id);
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: controller.isSelectionMode.value && isSelected
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              textDirection: ui.TextDirection.rtl,
              children: [
                Container(
                  width: 4.w,
                  color: accentColor,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: controller.isSelectionMode.value
                                  ? () => controller.toggleAppointmentSelected(
                                        appointment.id,
                                      )
                                  : null,
                              child: Container(
                                width: 22.w,
                                height: 22.w,
                                margin: EdgeInsets.only(left: 8.w, top: 1.h),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: controller.isSelectionMode.value &&
                                            isSelected
                                        ? AppColors.primary
                                        : (isCompleted
                                            ? AppColors.primary
                                            : (isCancelled
                                                ? AppColors.error
                                                : AppColors.divider)),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                  color: controller.isSelectionMode.value &&
                                          isSelected
                                      ? AppColors.primary
                                      : (isCompleted
                                          ? AppColors.primary
                                          : (isCancelled
                                              ? AppColors.error
                                              : Colors.transparent)),
                                ),
                                child: controller.isSelectionMode.value &&
                                        isSelected
                                    ? Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 13.sp,
                                      )
                                    : (isCompleted
                                        ? Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 13.sp,
                                          )
                                        : (isCancelled
                                            ? Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 13.sp,
                                              )
                                            : null)),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                title,
                                style: AppFonts.lamaSans(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                  color: _kPatientProfileNavy,
                                  height: 1.35,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          formattedDate,
                          style: AppFonts.lamaSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4A88B8),
                            height: 1.3,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: isPending && isUpcoming
                                ? const Color(0xFFEEF4F9)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'في تمام الساعة $formattedTime',
                            style: AppFonts.lamaSans(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: isPending && isUpcoming
                                  ? _kPatientProfileNavy
                                  : _kPatientProfileGray,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        if (hasNote) ...[
                          SizedBox(height: 6.h),
                          Text(
                            appointment.notes!,
                            style: AppFonts.lamaSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: _kPatientProfileGray,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                        if (imagesToShow.isNotEmpty) ...[
                          SizedBox(height: 6.h),
                          SizedBox(
                            height: 60.h,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: imagesToShow.length,
                              separatorBuilder: (_, __) => SizedBox(width: 8.w),
                              itemBuilder: (context, index) {
                                final imageUrl = ImageUtils.convertToValidUrl(
                                  imagesToShow[index],
                                );
                                return GestureDetector(
                                  onTap: () {
                                    _showAppointmentImageDialog(
                                      context,
                                      imageUrl ?? imagesToShow[index],
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: SizedBox(
                                      width: 60.w,
                                      height: 60.h,
                                      child: imageUrl != null &&
                                              ImageUtils.isValidImageUrl(
                                                imageUrl,
                                              )
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                color: const Color(0xFFF1F5F9),
                                                child: Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  color: _kPatientProfileGray,
                                                  size: 22.sp,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: const Color(0xFFF1F5F9),
                                              child: Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                color: _kPatientProfileGray,
                                                size: 22.sp,
                                              ),
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: AppFonts.lamaSans(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (!controller.isSelectionMode.value)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showChangeStatusDialog(
                                    context,
                                    appointment,
                                    controller.patientId!,
                                  ),
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF4F9),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 14.sp,
                                          color: const Color(0xFF4A88B8),
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          'تغيير الحالة',
                                          style: AppFonts.lamaSans(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF4A88B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangeStatusDialog(
    BuildContext context,
    AppointmentModel appointment,
    String appointmentPatientId,
  ) {
    final statusOptions = [
      {'value': 'scheduled', 'label': 'قيد الانتظار', 'icon': Icons.schedule_rounded},
      {'value': 'completed', 'label': 'مكتمل', 'icon': Icons.check_circle_rounded},
      {'value': 'cancelled', 'label': 'ملغي', 'icon': Icons.cancel_rounded},
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 48.w),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 300.w),
            child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: _kPatientProfileNavy.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4.h,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF162D4A), Color(0xFF4A88B8)],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تغيير حالة الموعد',
                        style: AppFonts.lamaSans(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: _kPatientProfileNavy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      ...statusOptions.map((option) {
                        final value = option['value'] as String;
                        final isSelected = appointment.status.toLowerCase() ==
                            value.toLowerCase();
                        final accentColor = _statusOptionColor(value);

                        return Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                Navigator.of(dialogContext).pop();
                                try {
                                  await controller.appointmentController
                                      .updateAppointmentStatus(
                                    appointmentPatientId,
                                    appointment.id,
                                    value,
                                  );
                                  await controller.appointmentController
                                      .loadPatientAppointmentsById(
                                    appointmentPatientId,
                                  );
                                } catch (_) {
                                  // الخطأ معالج في Controller
                                }
                              },
                              borderRadius: BorderRadius.circular(12.r),
                              child: Ink(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accentColor.withValues(alpha: 0.1)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? accentColor.withValues(alpha: 0.45)
                                        : const Color(0xFFE8ECF0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Directionality(
                                  textDirection: ui.TextDirection.rtl,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34.w,
                                        height: 34.w,
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10.r),
                                        ),
                                        child: Icon(
                                          option['icon'] as IconData,
                                          color: accentColor,
                                          size: 18.sp,
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Text(
                                          option['label'] as String,
                                          style: AppFonts.lamaSans(
                                            fontSize: 13.sp,
                                            fontWeight: isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? _kPatientProfileNavy
                                                : _kPatientProfileGray,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: accentColor,
                                          size: 20.sp,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: Container(
                          width: double.infinity,
                          height: 42.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: Text(
                              'إلغاء',
                              style: AppFonts.lamaSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: _kPatientProfileGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  Color _statusOptionColor(String value) {
    switch (value) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
      case 'no_show':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Widget _buildImplantStagesView() {
    final userType = controller.authController.currentUser.value?.userType;
    final isDoctor = userType != null && userType.toLowerCase() == 'doctor';

    final implantStageController = Get.isRegistered<ImplantStageController>()
        ? Get.find<ImplantStageController>()
        : Get.put(ImplantStageController());

    return Obx(() {
      if (implantStageController.isLoading.value) {
        return _tabFillScroll(
          Container(
            color: _kPatientProfileBg,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        );
      }

      // Only consider stages for this patient (controller may hold stages for multiple patients)
      final pid = controller.patientId ?? '';
      final patientStages =
          pid.isEmpty ? <ImplantStageModel>[] : implantStageController.stagesForPatient(pid);

      // Auto-scroll to the tapped implant stage (one attempt only).
      if (!controller.didAutoScrollToSelectedImplantStage &&
          controller.selectedAppointmentId != null &&
          patientStages.any((s) => s.id == controller.selectedAppointmentId)) {
        controller.didAutoScrollToSelectedImplantStage = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = controller
              .implantStageItemKeys[controller.selectedAppointmentId!]
              ?.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.1,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          }
        });
      }

      if (patientStages.isEmpty) {
        return _tabFillScroll(
          Container(
            color: _kPatientProfileBg,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.divider,
                  ),
                  child: Icon(
                    Icons.medical_services,
                    size: 50.sp,
                    color: AppColors.textHint,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا توجد مراحل زراعة',
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textHint),
                ),
                if (isDoctor && pid.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await implantStageController.initializeStages(pid);
                        // After initialization, ensure we have fresh data
                        await implantStageController.loadStages(pid);
                      } catch (_) {}
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('تهيئة مراحل الزراعة'),
                  ),
                ],
              ],
            ),
          ),
        ),
        );
      }

      // تنسيق التاريخ والوقت
      String getDayName(DateTime date) {
        final days = [
          'الأحد',
          'الاثنين',
          'الثلاثاء',
          'الأربعاء',
          'الخميس',
          'الجمعة',
          'السبت',
        ];
        return days[date.weekday % 7];
      }

      String formatTime(DateTime date) {
        final hour = date.hour;
        final minute = date.minute;
        final isPM = hour >= 12;
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final period = isPM ? 'مساءاً' : 'صباحاً';
        return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
      }

      // قائمة جميع المراحل المحتملة
      final allStages = [
        "مرحلة زراعة الاسنان",
        "مرحلة رفع خيط العملية",
        "متابعة حالة المريض",
        "المتابعة الثانية لحالة المريض",
        "التقاط طبعة الاسنان",
        "التركيب التجريبي الاول",
        "التركيب التجريبي الثاني",
        "التركيب النهائي الاخير",
      ];

      // إيجاد آخر مرحلة مكتملة
      int? lastCompletedIndex;
      for (int i = patientStages.length - 1; i >= 0; i--) {
        if (patientStages[i].isCompleted) {
          // البحث عن فهرس المرحلة في القائمة الكاملة
          final stageName = patientStages[i].stageName;
          final indexInAll = allStages.indexOf(stageName);
          if (indexInAll != -1) {
            lastCompletedIndex = indexInAll;
            break;
          }
        }
      }

      return Container(
        color: _kPatientProfileBg,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          itemCount: allStages.length,
          itemBuilder: (context, index) {
            final stageName = allStages[index];
            // البحث عن المرحلة في المراحل المحملة
            final existingStage = patientStages.firstWhere(
              (s) => s.stageName == stageName,
              orElse: () => ImplantStageModel(
                id: '',
                patientId: controller.patientId ?? '',
                stageName: stageName,
                scheduledAt: DateTime.now(),
                isCompleted: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            final isLast = index == allStages.length - 1;

            // تحديد إذا كانت المرحلة التالية مكتملة
            bool hasNextCompleted = false;
            if (index < allStages.length - 1) {
              final nextStageName = allStages[index + 1];
              final nextStage = patientStages.firstWhere(
                (s) => s.stageName == nextStageName,
                orElse: () => ImplantStageModel(
                  id: '',
                  patientId: controller.patientId ?? '',
                  stageName: nextStageName,
                  scheduledAt: DateTime.now(),
                  isCompleted: false,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              hasNextCompleted = nextStage.isCompleted;
            }

            // تحديد إذا كانت هذه المرحلة هي التالية للمرحلة المكتملة الأخيرة
            bool isNextToLastCompleted = false;
            if (lastCompletedIndex != null) {
              isNextToLastCompleted = index == lastCompletedIndex + 1;
            }

            // المرحلة الأولى (مرحلة زراعة الاسنان) تظهر معلومات الموعد دائماً إذا كانت موجودة
            final isFirstStage = index == 0;
            // التحقق من أن المرحلة موجودة (تم إنشاؤها) - id غير فارغ
            final stageExists = existingStage.id.isNotEmpty;

            // Never reuse empty ids — multiple placeholder stages share id ''.
            final stageKeyId = existingStage.id.isNotEmpty
                ? existingStage.id
                : 'placeholder_$stageName';
            final stageKey = controller.implantStageItemKeys.putIfAbsent(
              stageKeyId,
              () => GlobalKey(),
            );

            return KeyedSubtree(
              key: stageKey,
              child: _buildImplantStageItem(
                context: context,
                stage: existingStage,
                isLast: isLast,
                hasNextCompleted: hasNextCompleted,
                isDoctor: isDoctor,
                getDayName: getDayName,
                formatTime: formatTime,
                showAppointmentInfo:
                    existingStage.isCompleted ||
                    isNextToLastCompleted ||
                    (isFirstStage && stageExists),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildImplantStageItem({
    required BuildContext context,
    required ImplantStageModel stage,
    required bool isLast,
    required bool hasNextCompleted,
    required bool isDoctor,
    required String Function(DateTime) getDayName,
    required String Function(DateTime) formatTime,
    required bool showAppointmentInfo,
  }) {
    final dateFormat = DateFormat('d/M/yyyy');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content - قابل للضغط للطبيب فقط لتعديل التاريخ (على اليمين)
        Expanded(
          child: GestureDetector(
            onTap: isDoctor
                ? () {
                    _showEditImplantStageDateDialog(
                      context,
                      controller.patientId!,
                      stage.stageName,
                      stage.scheduledAt,
                    );
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h, top: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stage.stageName,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: stage.isCompleted
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : AppColors.textPrimary,
                      decoration: stage.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: stage.isCompleted
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : null,
                      decorationThickness: 2,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  // إظهار معلومات الموعد فقط للمراحل المكتملة والموعد التالي
                  if (showAppointmentInfo) ...[
                    SizedBox(height: 8.h),
                    Text(
                      'موعدك سيكون في',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'تاريخ ${dateFormat.format(stage.scheduledAt)} يوم ${getDayName(stage.scheduledAt)} الساعة ${formatTime(stage.scheduledAt)}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        // Timeline Line and Circle (على اليسار)
        Column(
          children: [
            // Circle - قابل للضغط للطبيب فقط لإكمال/إلغاء إكمال المرحلة
            GestureDetector(
              onTap: isDoctor
                  ? () async {
                      final implantStageController = Get.put(
                        ImplantStageController(),
                      );

                      bool success;
                      if (stage.isCompleted) {
                        // إلغاء الإكمال
                        success = await implantStageController.uncompleteStage(
                          controller.patientId!,
                          stage.stageName,
                        );
                      } else {
                        // إكمال المرحلة
                        success = await implantStageController.completeStage(
                          controller.patientId!,
                          stage.stageName,
                        );
                      }

                      if (success) {
                        // لا نعرض Snackbar للنجاح، التحديث المتفائل حدث بالفعل في الواجهة
                      } else {
                        final errorMsg =
                            implantStageController.errorMessage.value.isNotEmpty
                            ? implantStageController.errorMessage.value
                            : 'فشل تحديث حالة المرحلة';
                        
                        // Network/server-connection wording → internet dialog only.
                        await NetworkUtils.showError(errorMsg);
                      }
                    }
                  : null,
              child: Container(
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stage.isCompleted
                      ? AppColors.primary
                      : AppColors.white,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: stage.isCompleted
                    ? Icon(Icons.check, color: AppColors.white, size: 20.sp)
                    : null,
              ),
            ),
            // Line
            if (!isLast)
              Container(
                width: 2,
                height: 50.h,
                color: stage.isCompleted || hasNextCompleted
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.3),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGalleryTab() {
    return Obx(() {
      if (controller.galleryController.isLoading.value) {
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(16.w),
              sliver: SliverToBoxAdapter(
                child: Skeletonizer(
                  enabled: true,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8.w,
                      mainAxisSpacing: 8.h,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Container(color: AppColors.divider),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      }

      if (controller.galleryController.galleryImages.isEmpty) {
        return _tabFillScroll(
          Container(
            color: _kPatientProfileBg,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.divider,
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    size: 50.sp,
                    color: AppColors.textHint,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'لا توجد صور',
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ),
        );
      }

      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(16.w),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.w,
                mainAxisSpacing: 8.h,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
            final image = controller.galleryController.galleryImages[index];
            return GestureDetector(
              onTap: () {
                _showImageDetailsDialog(context, image);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Builder(
                  builder: (context) {
                    final imageUrl = ImageUtils.convertToValidUrl(
                      image.imagePath,
                    );
                    if (imageUrl != null &&
                        ImageUtils.isValidImageUrl(imageUrl)) {
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        progressIndicatorBuilder: (context, url, progress) =>
                            Container(
                              color: AppColors.divider,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.progress,
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.divider,
                          child: Icon(
                            Icons.broken_image,
                            color: AppColors.textHint,
                            size: 30.sp,
                          ),
                        ),
                      );
                    } else {
                      return Container(
                        color: AppColors.divider,
                        child: Icon(
                          Icons.broken_image,
                          color: AppColors.textHint,
                          size: 30.sp,
                        ),
                      );
                    }
                  },
                ),
              ),
            );
                },
                childCount: controller.galleryController.galleryImages.length,
              ),
            ),
          ),
        ],
      );
    });
  }

  String _getButtonText(int tabIndex) {
    switch (tabIndex) {
      case 0: // السجلات (Records)
        return 'اضافة سجل';
      case 1: // المواعيد (Appointments)
        return 'حجز موعد';
      case 2: // المعرض (Gallery)
        return 'اضافة صورة';
      case 3: // Dental Chart
        return '';
      default:
        return 'اضافة سجل';
    }
  }

  void _onButtonPressed(BuildContext context, int tabIndex) {
    switch (tabIndex) {
      case 0: // السجلات (Records)
        if (controller.patientId != null) {
          _showAddRecordDialog(context);
        }
        break;
      case 1: // المواعيد (Appointments)
        if (controller.patientId != null) {
          _showBookAppointmentDialog(context);
        }
        break;
      case 2: // المعرض (Gallery)
        if (controller.patientId != null) {
          _showAddImageDialog(context);
        }
        break;
      case 3: // Dental Chart
        break;
    }
  }

  Widget _buildDentalChartTab() {
    return Obx(() {
      final patientId = controller.patientId;
      if (patientId == null) {
        return const SizedBox.shrink();
      }

      final patient = controller.patientController.getPatientById(patientId);
      if (patient == null) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      return PatientDentalChartTab(
        patient: patient,
        controller: controller.dentalChartController,
      );
    });
  }

  /// Convert 24-hour time format to 12-hour format with ص/م
  String _convertTo12Hour(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length < 2) return time24;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1];

      if (hour == 0) {
        return '12:$minute ص';
      } else if (hour < 12) {
        return '$hour:$minute ص';
      } else if (hour == 12) {
        return '12:$minute م';
      } else {
        return '${hour - 12}:$minute م';
      }
    } catch (e) {
      return time24;
    }
  }

  void _showBookAppointmentDialog(BuildContext context) {
    int currentStep = 1;
    DateTime? selectedDate;
    String? selectedTime;
    List<File> selectedImages = [];
    final TextEditingController notesController = TextEditingController();

    // Get patient and doctor ID
    final patient = controller.patientId != null
        ? controller.patientController.getPatientById(controller.patientId!)
        : null;
    final doctorIds = patient?.doctorIds ?? [];
    final doctorId = doctorIds.isNotEmpty ? doctorIds.first : null;

    // Working hours controller
    final workingHoursController = Get.put(WorkingHoursController());

    // Available slots (will be loaded from API)
    List<String> availableSlots = [];
    bool isLoadingSlots = false;

    // Load working hours when dialog opens
    if (doctorId != null) {
      workingHoursController.loadWorkingHours(doctorId: doctorId);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: currentStep == 1
                    ? _buildStep1DateTimeSelection(
                        context,
                        selectedDate,
                        selectedTime,
                        availableSlots,
                        isLoadingSlots,
                        workingHoursController,
                        doctorId,
                        (date) async {
                          setDialogState(() {
                            selectedDate = date;
                            selectedTime = null; // Reset time when date changes
                            isLoadingSlots = true;
                          });

                          // Load available slots for selected date
                          if (doctorId != null) {
                            try {
                              final dateStr =
                                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                              final userType =
                                  (controller.authController.currentUser.value?.userType ??
                                          '')
                                      .toLowerCase();
                              final isReceptionOrAdmin =
                                  userType == 'receptionist' ||
                                      userType == 'admin';
                              final slots = isReceptionOrAdmin
                                  ? await controller.workingHoursService
                                      .getAvailableSlotsForReception(
                                        doctorId,
                                        dateStr,
                                      )
                                  : await controller.workingHoursService.getAvailableSlots(
                                      doctorId,
                                      dateStr,
                                    );
                              setDialogState(() {
                                availableSlots = slots;
                                isLoadingSlots = false;
                              });
                            } catch (e) {
                              print(
                                '❌ [PatientDetailsScreen] Error loading available slots: $e',
                              );
                              setDialogState(() {
                                availableSlots = [];
                                isLoadingSlots = false;
                              });
                              Get.snackbar(
                                'خطأ',
                                'فشل جلب الأوقات المتاحة',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: AppColors.white,
                              );
                            }
                          } else {
                            setDialogState(() {
                              availableSlots = [];
                              isLoadingSlots = false;
                            });
                          }
                        },
                        (time) {
                          setDialogState(() {
                            selectedTime = time;
                          });
                        },
                        () {
                          if (selectedDate != null && selectedTime != null) {
                            setDialogState(() {
                              currentStep = 2;
                            });
                          } else {
                            Get.snackbar(
                              'تنبيه',
                              'يرجى اختيار التاريخ والوقت',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.orange,
                              colorText: AppColors.white,
                            );
                          }
                        },
                        () => Navigator.of(context).pop(),
                        setDialogState,
                      )
                    : _buildStep2NotesImages(
                        context,
                        notesController,
                        selectedImages,
                        (images) {
                          setDialogState(() {
                            selectedImages = images;
                          });
                        },
                        (index) {
                          setDialogState(() {
                            selectedImages.removeAt(index);
                          });
                        },
                        () {
                          setDialogState(() {
                            currentStep = 1;
                          });
                        },
                        () async {
                          if (selectedDate != null && selectedTime != null) {
                            // Parse time from 12-hour format (e.g., "2:30 م" or "9:00 ص")
                            final isPM = selectedTime!.contains(' م');
                            final timeStr = selectedTime!
                                .replaceAll(' م', '')
                                .replaceAll(' ص', '')
                                .trim();
                            final timeParts = timeStr.split(':');
                            var hour = int.parse(timeParts[0]);
                            final minute = timeParts.length > 1
                                ? int.parse(timeParts[1])
                                : 0;

                            // Convert to 24-hour format
                            if (isPM && hour != 12) {
                              hour += 12;
                            } else if (!isPM && hour == 12) {
                              hour = 0;
                            }

                            // Combine date and time
                            final appointmentDateTime = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              hour,
                              minute,
                            );

                            Navigator.of(context).pop();

                            try {
                              await controller.appointmentController.addAppointment(
                                patientId: controller.patientId!,
                                scheduledAt: appointmentDateTime,
                                note: notesController.text.isNotEmpty
                                    ? notesController.text
                                    : null,
                                imageFiles: selectedImages.isNotEmpty
                                    ? selectedImages
                                    : null,
                              );

                              // Reload appointments
                              controller.appointmentController
                                  .loadPatientAppointmentsById(controller.patientId!);
                            } catch (e) {
                              print(
                                '❌ [PatientDetailsScreen] Error adding appointment: $e',
                              );
                              // لا تعرض خطأ إذا كان الخطأ في parsing فقط (الموعد تمت إضافته)
                              final errorMsg = e.toString();
                              if (!errorMsg.contains('معالجة البيانات')) {
                                Get.snackbar(
                                  'خطأ',
                                  'فشل إضافة الموعد',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: Colors.red,
                                  colorText: AppColors.white,
                                );
                              }
                            }
                          }
                        },
                      ),
              ),
            );
          },
        );
      },
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          notesController.dispose();
        } catch (e) {
          // Controller already disposed
        }
      });
    });
  }

  Widget _buildStep1DateTimeSelection(
    BuildContext context,
    DateTime? selectedDate,
    String? selectedTime,
    List<String> availableSlots,
    bool isLoadingSlots,
    WorkingHoursController workingHoursController,
    String? doctorId,
    Function(DateTime) onDateSelected,
    Function(String) onTimeSelected,
    VoidCallback onNext,
    VoidCallback onBack,
    StateSetter setState,
  ) {
    // Day names in Arabic (0=Sunday, 6=Saturday)
    final weekDays = [
      'أحد',
      'اثنين',
      'ثلاثاء',
      'أربعاء',
      'خميس',
      'جمعة',
      'سبت',
    ];

    // Use selectedDate or today as reference
    final now = selectedDate ?? DateTime.now();

    return StatefulBuilder(
      builder: (context, setCalendarState) {
        // Calculate week start (Sunday = 0)
        // If today is Sunday (weekday % 7 == 0), weekStart = now
        // Otherwise, subtract days to get to Sunday
        final weekStart = now.subtract(Duration(days: now.weekday % 7));

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Title
              Text(
                'اختر تاريخ الموعد',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 24.h),

              // Week navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setCalendarState(() {
                            final newDate = (selectedDate ?? DateTime.now())
                                .subtract(const Duration(days: 7));
                            onDateSelected(newDate);
                          });
                        },
                        child: Icon(
                          Icons.chevron_left,
                          size: 24.r,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${(selectedDate ?? DateTime.now()).year} , ${(selectedDate ?? DateTime.now()).month}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () {
                          setCalendarState(() {
                            final newDate = (selectedDate ?? DateTime.now())
                                .add(const Duration(days: 7));
                            onDateSelected(newDate);
                          });
                        },
                        child: Icon(
                          Icons.chevron_right,
                          size: 24.r,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Week calendar (7 days in a row)
              Obx(() {
                return Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 16.h,
                    horizontal: 0.w,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final day = weekStart.add(Duration(days: index));
                      final isSelected =
                          selectedDate != null &&
                          day.day == selectedDate.day &&
                          day.month == selectedDate.month &&
                          day.year == selectedDate.year;
                      final isPast = day.isBefore(
                        DateTime.now().subtract(const Duration(days: 1)),
                      );

                      // Check if this day is a holiday (not working)
                      bool isHoliday = false;
                      if (workingHoursController.workingHours.isNotEmpty) {
                        final weekday = day.weekday % 7; // 0=Sunday, 6=Saturday
                        if (weekday <
                            workingHoursController.workingHours.length) {
                          final dayWorkingHours =
                              workingHoursController.workingHours[weekday];
                          isHoliday = dayWorkingHours['isWorking'] == false;
                        }
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: (isPast || isHoliday)
                              ? null
                              : () {
                                  onDateSelected(day);
                                  setCalendarState(() {});
                                },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 2.w),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF7FC8D6)
                                  : (isPast || isHoliday)
                                  ? Colors.grey[100]
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.r),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF7FC8D6),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  weekDays[day.weekday % 7],
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isPast || isHoliday)
                                        ? Colors.grey[400]
                                        : Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : (isPast || isHoliday)
                                        ? Colors.grey[400]
                                        : Colors.black87,
                                    decoration: isHoliday
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),

              SizedBox(height: 24.h),

              // Time selection title
              Text(
                'اختر وقت الموعد',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
              SizedBox(height: 16.h),

              // Time slots grid or loading/empty state
              SizedBox(
                height: 200.h, // Fixed height for scrollable area
                child: isLoadingSlots
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.h),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : availableSlots.isEmpty
                    ? Container(
                        padding: EdgeInsets.all(24.h),
                        child: Center(
                          child: Text(
                            selectedDate == null
                                ? 'يرجى اختيار تاريخ أولاً'
                                : 'لا توجد أوقات متاحة لهذا التاريخ',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8.w,
                          mainAxisSpacing: 8.h,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: availableSlots.length,
                        itemBuilder: (context, index) {
                          final time24 = availableSlots[index];
                          final time = _convertTo12Hour(time24);
                          final isSelected = selectedTime == time;

                          return GestureDetector(
                            onTap: () {
                              onTimeSelected(time);
                              setCalendarState(() {});
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.white,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              SizedBox(height: 24.h),

              // Hint box
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.yellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.orange,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'لطفا قم بادخال الوقت والتاريخ لتسجيل موعد المريض',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text(
                        'حجز',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onBack,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text(
                        'عودة',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep2NotesImages(
    BuildContext context,
    TextEditingController notesController,
    List<File> selectedImages,
    Function(List<File>) onImagesSelected,
    Function(int) onImageRemoved,
    VoidCallback onBack,
    VoidCallback onBook,
  ) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Add Notes section
          Text(
            'اضف ملاحضاتك (اختياري)',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 150.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.divider),
            ),
            child: TextField(
              controller: notesController,
              maxLines: null,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'اكتب ملاحضاتك هنا',
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
              ),
              style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
            ),
          ),

          SizedBox(height: 24.h),

          // Add Images section
          Text(
            'اضف صور (اختياري)',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 16.h),

          GestureDetector(
            onTap: () async {
              try {
                final List<XFile>? images = await controller.imagePicker.pickMultiImage(
                  imageQuality: 85,
                );

                if (images != null && images.isNotEmpty) {
                  final List<File> newImages = images
                      .map((xfile) => File(xfile.path))
                      .toList();
                  onImagesSelected([...selectedImages, ...newImages]);
                }
              } catch (e) {
                Get.snackbar(
                  'خطأ',
                  'فشل اختيار الصور',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: AppColors.white,
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.divider.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.image_outlined, color: AppColors.textSecondary),
                  SizedBox(width: 8.w),
                  Text(
                    'اضغط هنا لإضافة صور',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Images preview grid
          if (selectedImages.isNotEmpty) ...[
            SizedBox(height: 16.h),
            SizedBox(
              height: 150.h,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 8.w,
                  childAspectRatio: 1,
                ),
                itemCount: selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: EdgeInsets.only(left: 8.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.file(
                            selectedImages[index],
                            fit: BoxFit.cover,
                            width: 120.w,
                            height: 120.h,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4.h,
                        left: 4.w,
                        child: GestureDetector(
                          onTap: () {
                            onImageRemoved(index);
                          },
                          child: Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          SizedBox(height: 24.h),

          // Hint box
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.medical_services, color: Colors.red, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'يمكنك إدخال ملاحظاتك أو إضافة صور (كلاهما اختياري)',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Text(
                    'حجز',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'عودة',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.arrow_forward,
                        color: AppColors.primary,
                        size: 20.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('تأكيد الحذف'),
          content: Text(
            'هل أنت متأكد من حذف ${controller.selectedAppointmentIds.length} موعد محدد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await controller.deleteSelectedAppointments();
              },
              child: Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showAddImageDialog(BuildContext context) {
    File? selectedImage;
    final TextEditingController noteController = TextEditingController();
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'اضافة صورة',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),

                      // Image picker button
                      GestureDetector(
                        onTap: () async {
                          if (isUploading) return;

                          try {
                            final XFile? image = await controller.imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                              maxWidth: 1920,
                              maxHeight: 1920,
                            );

                            if (image != null) {
                              setDialogState(() {
                                selectedImage = File(image.path);
                              });
                            }
                          } catch (e) {
                            print(
                              '❌ [PatientDetailsScreen] Error picking image: $e',
                            );
                            if (context.mounted) {
                              Get.snackbar(
                                'خطأ',
                                'فشل اختيار الصورة. تأكد من إعطاء الأذونات المطلوبة.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: AppColors.white,
                              );
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 200.h,
                          decoration: BoxDecoration(
                            color: AppColors.divider.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.divider,
                              width: 1.5,
                            ),
                          ),
                          child: selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 48.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'اختر صورة',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Image.file(
                                    selectedImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 200.h,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Note text field
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'الشرح (اختياري)',
                          labelStyle: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                        maxLines: 3,
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      SizedBox(height: 32.h),

                      // Buttons
                      Row(
                        children: [
                          // Back button (left)
                          Expanded(
                            child: GestureDetector(
                              onTap: isUploading
                                  ? null
                                  : () {
                                      Navigator.of(dialogContext).pop();
                                    },
                              child: Container(
                                height: 48.h,
                                decoration: BoxDecoration(
                                  color: AppColors.divider,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: Text(
                                    'عودة',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          // Add button (right)
                          Expanded(
                            child: GestureDetector(
                              onTap: isUploading || selectedImage == null
                                  ? null
                                  : () async {
                                      setDialogState(() {
                                        isUploading = true;
                                      });

                                      final success = await controller.galleryController
                                          .uploadImage(
                                            controller.patientId!,
                                            selectedImage!,
                                            noteController.text.trim().isEmpty
                                                ? null
                                                : noteController.text.trim(),
                                          );

                                      if (dialogContext.mounted) {
                                        if (success) {
                                          Navigator.of(dialogContext).pop();
                                          Get.snackbar(
                                            'نجح',
                                            'تم رفع الصورة بنجاح',
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: AppColors.primary,
                                            colorText: AppColors.white,
                                          );
                                        } else {
                                          Get.snackbar(
                                            'خطأ',
                                            controller.galleryController
                                                .errorMessage
                                                .value,
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.red,
                                            colorText: AppColors.white,
                                          );
                                          setDialogState(() {
                                            isUploading = false;
                                          });
                                        }
                                      }
                                    },
                              child: Container(
                                height: 48.h,
                                decoration: BoxDecoration(
                                  color: (isUploading || selectedImage == null)
                                      ? AppColors.divider
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: isUploading
                                      ? SizedBox(
                                          width: 20.w,
                                          height: 20.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          'اضافة',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Dispose controller after dialog is fully closed
      // Use Future.delayed to ensure the widget tree is fully unmounted
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          noteController.dispose();
        } catch (e) {
          // Controller already disposed or widget tree still using it
        }
      });
    });
  }

  void _showPatientImageDialog(BuildContext context, PatientModel patient) {
    final imageUrl = ImageUtils.convertToValidUrl(patient.imageUrl);
    final hasImage =
        imageUrl != null && ImageUtils.isValidImageUrl(imageUrl);

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black87,
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            progressIndicatorBuilder:
                                (context, url, progress) => Center(
                              child: CircularProgressIndicator(
                                value: progress.progress,
                                strokeWidth: 3,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 64.sp,
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 72.sp,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'لا توجد صورة للمريض',
                                style: AppFonts.lamaSans(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                Positioned(
                  top: 40.h,
                  right: 20.w,
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAppointmentImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black87,
            child: Stack(
              children: [
                // Full screen image with zoom
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      progressIndicatorBuilder: (context, url, progress) =>
                          Center(
                            child: CircularProgressIndicator(
                              value: progress.progress,
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                      errorWidget: (context, url, error) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 50.sp,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'فشل تحميل الصورة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 40.h,
                  right: 20.w,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                  ),
                ),
                // Save button
                Positioned(
                  top: 40.h,
                  left: 20.w,
                  child: GestureDetector(
                    onTap: () => _saveImage(context, imageUrl),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageDetailsDialog(BuildContext context, dynamic galleryImage) {
    // Parse date
    String formattedDate = '';
    try {
      final dateTime = DateTime.parse(galleryImage.createdAt);
      formattedDate = DateFormat('yyyy-MM-dd HH:mm', 'ar').format(dateTime);
    } catch (e) {
      formattedDate = galleryImage.createdAt;
    }

    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppColors.divider,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: AppColors.textPrimary,
                              size: 24.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Image with zoom
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        final imageUrl = ImageUtils.convertToValidUrl(
                          galleryImage.imagePath,
                        );
                        if (imageUrl != null &&
                            ImageUtils.isValidImageUrl(imageUrl)) {
                          _showAppointmentImageDialog(context, imageUrl);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Builder(
                          builder: (context) {
                            final imageUrl = ImageUtils.convertToValidUrl(
                              galleryImage.imagePath,
                            );
                            if (imageUrl != null &&
                                ImageUtils.isValidImageUrl(imageUrl)) {
                              return CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: 300.h,
                                progressIndicatorBuilder:
                                    (context, url, progress) => Container(
                                      width: double.infinity,
                                      height: 300.h,
                                      color: AppColors.divider,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: progress.progress,
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.primary,
                                              ),
                                        ),
                                      ),
                                    ),
                                errorWidget: (context, url, error) => Container(
                                  width: double.infinity,
                                  height: 300.h,
                                  color: AppColors.divider,
                                  child: Icon(
                                    Icons.broken_image,
                                    color: AppColors.textHint,
                                    size: 50.sp,
                                  ),
                                ),
                              );
                            } else {
                              return Container(
                                width: double.infinity,
                                height: 300.h,
                                color: AppColors.divider,
                                child: Icon(
                                  Icons.broken_image,
                                  color: AppColors.textHint,
                                  size: 50.sp,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Note (if exists)
                    if (galleryImage.note != null &&
                        galleryImage.note!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: AppColors.divider.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الشرح:',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              galleryImage.note!,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Date
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            Icons.calendar_today,
                            size: 18.sp,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Delete button
                    GestureDetector(
                      onTap: isDeleting
                          ? null
                          : () async {
                              // Show confirmation dialog
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('تأكيد الحذف'),
                                  content: Text(
                                    'هل أنت متأكد من حذف هذه الصورة؟',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text('إلغاء'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(
                                        'حذف',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && controller.patientId != null) {
                                setDialogState(() {
                                  isDeleting = true;
                                });

                                final success = await controller.galleryController
                                    .deleteImage(controller.patientId!, galleryImage.id);

                                if (context.mounted) {
                                  if (success) {
                                    Navigator.of(context).pop(); // Close dialog
                                    Get.snackbar(
                                      'نجح',
                                      'تم حذف الصورة بنجاح',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: AppColors.primary,
                                      colorText: AppColors.white,
                                    );
                                  } else {
                                    setDialogState(() {
                                      isDeleting = false;
                                    });
                                    Get.snackbar(
                                      'خطأ',
                                      controller.galleryController
                                              .errorMessage
                                              .value
                                              .isNotEmpty
                                          ? controller.galleryController
                                                .errorMessage
                                                .value
                                          : 'فشل حذف الصورة',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.red,
                                      colorText: AppColors.white,
                                    );
                                  }
                                }
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: isDeleting ? AppColors.divider : Colors.red,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: isDeleting
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: AppColors.white,
                                      size: 20.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'حذف الصورة',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDoctorImage(DoctorModel doctor, String doctorInitials) {
    // Check if imageUrl is valid and convert to valid URL
    final imageUrl = doctor.imageUrl;
    final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);

    if (validImageUrl != null && ImageUtils.isValidImageUrl(validImageUrl)) {
      return CachedNetworkImage(
        imageUrl: validImageUrl,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              bottomLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
              bottomRight: Radius.circular(16.r),
            ),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            _buildDefaultDoctorImage(doctorInitials),
        memCacheWidth: 160,
        memCacheHeight: 160,
      );
    } else {
      return _buildDefaultDoctorImage(doctorInitials);
    }
  }

  Widget _buildDefaultDoctorImage(String doctorInitials) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          bottomLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
          bottomRight: Radius.circular(16.r),
        ),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Center(
        child: Text(
          doctorInitials,
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _saveImage(BuildContext context, String imageUrl) async {
    try {
      // إظهار رسالة جاري الحفظ
      Get.rawSnackbar(
        messageText: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'جاري الحفظ...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
        animationDuration: const Duration(milliseconds: 300),
      );

      var response = await Dio().get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      
      await Gal.putImageBytes(
        Uint8List.fromList(response.data),
        name: "farah_app_${DateTime.now().millisecondsSinceEpoch}",
      );

      // إظهار رسالة النجاح
      Get.rawSnackbar(
        messageText: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'تم الحفظ في المعرض',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        animationDuration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      // إظهار رسالة الخطأ
      Get.rawSnackbar(
        messageText: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'فشل الحفظ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        animationDuration: const Duration(milliseconds: 300),
      );
    }
  }

  void _showQrCodeDialog(BuildContext context, String qrPatientId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: AppColors.textPrimary,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // QR Code
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: QrImageView(
                    data: qrPatientId,
                    version: QrVersions.auto,
                    size: 250.w,
                    backgroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 40.sp,
                  ),
                ),
                SizedBox(height: 24.h),
                // Title
                Text(
                  'نجح',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                // Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                // OK Button
                GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        'حسناً',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditImplantStageDateDialog(
    BuildContext context,
    String stagePatientId,
    String stageName,
    DateTime currentDate,
  ) {
    DateTime? selectedDate = currentDate;
    String? selectedTime;

    // تحويل الوقت الحالي إلى تنسيق 12 ساعة
    final hour = currentDate.hour;
    final minute = currentDate.minute;
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    selectedTime =
        '$displayHour:${minute.toString().padLeft(2, '0')} ${isPM ? 'م' : 'ص'}';

    // Get patient and doctor ID
    final patient = controller.patientController.getPatientById(stagePatientId);
    final doctorIds = patient?.doctorIds ?? [];
    final doctorId = doctorIds.isNotEmpty ? doctorIds.first : null;

    // Working hours controller
    final workingHoursController = Get.put(WorkingHoursController());

    // Available slots
    List<String> availableSlots = [];
    bool isLoadingSlots = false;

    // Load working hours when dialog opens
    if (doctorId != null) {
      workingHoursController.loadWorkingHours(doctorId: doctorId);
    }

    final implantStageController = Get.put(ImplantStageController());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: _buildStep1DateTimeSelection(
                  context,
                  selectedDate,
                  selectedTime,
                  availableSlots,
                  isLoadingSlots,
                  workingHoursController,
                  doctorId,
                  (date) async {
                    setDialogState(() {
                      selectedDate = date;
                      selectedTime = null; // Reset time when date changes
                      isLoadingSlots = true;
                    });

                    // Load available slots for selected date
                    if (doctorId != null) {
                      try {
                        final dateStr =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        final userType =
                            (controller.authController.currentUser.value?.userType ?? '')
                                .toLowerCase();
                        final isReceptionOrAdmin =
                            userType == 'receptionist' || userType == 'admin';
                        final slots = isReceptionOrAdmin
                            ? await controller.workingHoursService
                                .getAvailableSlotsForReception(
                                  doctorId,
                                  dateStr,
                                )
                            : await controller.workingHoursService.getAvailableSlots(
                                doctorId,
                                dateStr,
                              );
                        setDialogState(() {
                          availableSlots = slots;
                          isLoadingSlots = false;
                        });
                      } catch (e) {
                        print(
                          '❌ [PatientDetailsScreen] Error loading available slots: $e',
                        );
                        setDialogState(() {
                          availableSlots = [];
                          isLoadingSlots = false;
                        });
                        Get.snackbar(
                          'خطأ',
                          'فشل جلب الأوقات المتاحة',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: AppColors.white,
                        );
                      }
                    } else {
                      setDialogState(() {
                        availableSlots = [];
                        isLoadingSlots = false;
                      });
                    }
                  },
                  (time) {
                    setDialogState(() {
                      selectedTime = time;
                    });
                  },
                  () async {
                    if (selectedDate != null && selectedTime != null) {
                      // Parse time from 12-hour format
                      final isPM = selectedTime!.contains(' م');
                      final timeStr = selectedTime!
                          .replaceAll(' م', '')
                          .replaceAll(' ص', '')
                          .trim();
                      final timeParts = timeStr.split(':');
                      var hour = int.parse(timeParts[0]);
                      final minute = timeParts.length > 1
                          ? int.parse(timeParts[1])
                          : 0;

                      // Convert to 24-hour format
                      if (isPM && hour != 12) {
                        hour += 12;
                      } else if (!isPM && hour == 12) {
                        hour = 0;
                      }

                      // Update stage date
                      final success = await implantStageController
                          .updateStageDate(
                            stagePatientId,
                            stageName,
                            selectedDate!,
                            '$hour:${minute.toString().padLeft(2, '0')}',
                          );

                      if (success) {
                        Navigator.of(context).pop();
                        // إعادة تحميل المراحل بعد التعديل
                        implantStageController.loadStages(stagePatientId);
                        // إظهار دايلوج النجاح بعد إغلاق الدايلوج الحالي
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (context.mounted) {
                            _showSuccessDialog(
                              context,
                              'تم تحديث تاريخ المرحلة بنجاح',
                            );
                          }
                        });
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
                    } else {
                      Get.snackbar(
                        'تنبيه',
                        'يرجى اختيار التاريخ والوقت',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.orange,
                        colorText: AppColors.white,
                      );
                    }
                  },
                  () => Navigator.of(context).pop(),
                  setDialogState,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _genderDisplayLabel(String value) {
    return value == 'female' ? 'أنثى' : 'ذكر';
  }

  void _showGenderPicker({
    required BuildContext context,
    required String selectedGender,
    required ValueChanged<String> onSelected,
  }) {
    const options = [
      {'value': 'male', 'label': 'ذكر', 'icon': Icons.male_rounded},
      {'value': 'female', 'label': 'أنثى', 'icon': Icons.female_rounded},
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DEE8),
                      borderRadius: BorderRadius.circular(99.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'اختر الجنس',
                    style: AppFonts.lamaSans(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: _kPatientProfileNavy,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  ...options.map((option) {
                    final value = option['value'] as String;
                    final isSelected = selectedGender == value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: _buildGovernorateOption(
                        city: option['label'] as String,
                        isSelected: isSelected,
                        icon: option['icon'] as IconData,
                        onTap: () {
                          onSelected(value);
                          Navigator.pop(sheetContext);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGovernoratePicker({
    required BuildContext context,
    required List<String> cities,
    required String? selectedCity,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(maxHeight: 0.72.sh),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12.h),
                Container(
                  width: 42.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DEE8),
                    borderRadius: BorderRadius.circular(99.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'اختر المحافظة',
                  style: AppFonts.lamaSans(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: _kPatientProfileNavy,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'حدد محافظة المريض',
                  style: AppFonts.lamaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: _kPatientProfileGray,
                  ),
                ),
                SizedBox(height: 14.h),
                Flexible(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    itemCount: cities.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final city = cities[index];
                      final isSelected = selectedCity == city;
                      return _buildGovernorateOption(
                        city: city,
                        isSelected: isSelected,
                        onTap: () {
                          onSelected(city);
                          Navigator.pop(sheetContext);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGovernorateOption({
    required String city,
    required bool isSelected,
    required VoidCallback onTap,
    IconData icon = Icons.location_on_rounded,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? _kPatientProfileNavy : _kPatientProfileBg,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isSelected
                  ? _kPatientProfileNavy
                  : const Color(0xFFE8ECF0),
            ),
          ),
          child: Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF4A88B8),
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    city,
                    style: AppFonts.lamaSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : _kPatientProfileNavy,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20.sp,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPatientProfileDialog(
    BuildContext context,
    PatientModel patient,
    bool isReceptionist,
  ) {
    final nameController = TextEditingController(text: patient.name);
    final phoneController =
        TextEditingController(text: patient.phoneNumber);
    final ageController = TextEditingController(
      text: patient.age > 0 ? patient.age.toString() : '',
    );

    final cities = IraqGovernorates.arabicNames;
    final normalizedGender =
        (patient.gender == 'female' || patient.gender == 'أنثى')
            ? 'female'
            : 'male';
    String selectedGender = normalizedGender;
    final currentCity = IraqGovernorates.toArabic(patient.city) ?? '';
    String? selectedCity =
        cities.contains(currentCity) ? currentCity : null;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 340.w,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تعديل معلومات المريض',
                        style: AppFonts.lamaSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: _kPatientProfileNavy,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: nameController,
                        textAlign: TextAlign.right,
                        style: AppFonts.lamaSans(fontSize: 14.sp),
                        decoration: InputDecoration(
                          labelText: 'الاسم',
                          labelStyle: AppFonts.lamaSans(fontSize: 13.sp),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                      if (isReceptionist) ...[
                        SizedBox(height: 10.h),
                        TextField(
                          controller: phoneController,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.phone,
                          style: AppFonts.lamaSans(fontSize: 14.sp),
                          decoration: InputDecoration(
                            labelText: 'الهاتف',
                            labelStyle: AppFonts.lamaSans(fontSize: 13.sp),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ageController,
                              textAlign: TextAlign.right,
                              keyboardType: TextInputType.number,
                              style: AppFonts.lamaSans(fontSize: 14.sp),
                              decoration: InputDecoration(
                                labelText: 'العمر',
                                labelStyle: AppFonts.lamaSans(fontSize: 13.sp),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: GestureDetector(
                              onTap: isSaving
                                  ? null
                                  : () => _showGenderPicker(
                                        context: dialogContext,
                                        selectedGender: selectedGender,
                                        onSelected: (value) {
                                          setDialogState(
                                            () => selectedGender = value,
                                          );
                                        },
                                      ),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'الجنس',
                                  labelStyle:
                                      AppFonts.lamaSans(fontSize: 13.sp),
                                  suffixIcon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: _kPatientProfileGray,
                                    size: 22.sp,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8ECF0),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _genderDisplayLabel(selectedGender),
                                  textAlign: TextAlign.right,
                                  style: AppFonts.lamaSans(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _kPatientProfileNavy,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      GestureDetector(
                        onTap: isSaving
                            ? null
                            : () => _showGovernoratePicker(
                                  context: dialogContext,
                                  cities: cities,
                                  selectedCity: selectedCity,
                                  onSelected: (city) {
                                    setDialogState(() => selectedCity = city);
                                  },
                                ),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'المدينة',
                            labelStyle: AppFonts.lamaSans(fontSize: 13.sp),
                            suffixIcon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _kPatientProfileGray,
                              size: 22.sp,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: const BorderSide(
                                color: Color(0xFFE8ECF0),
                              ),
                            ),
                          ),
                          child: Text(
                            selectedCity ?? 'اختر المحافظة',
                            textAlign: TextAlign.right,
                            style: AppFonts.lamaSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: selectedCity != null
                                  ? _kPatientProfileNavy
                                  : _kPatientProfileGray,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: isSaving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: Container(
                                height: 42.h,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Center(
                                  child: Text(
                                    'إلغاء',
                                    style: AppFonts.lamaSans(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _kPatientProfileGray,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: GestureDetector(
                              onTap: isSaving
                                  ? null
                                  : () async {
                                      final name = nameController.text.trim();
                                      final city = selectedCity?.trim() ?? '';
                                      final age = int.tryParse(
                                        ageController.text.trim(),
                                      );
                                      final phone = phoneController.text.trim();

                                      if (name.isEmpty ||
                                          city.isEmpty ||
                                          age == null ||
                                          age <= 0) {
                                        Get.snackbar(
                                          'تنبيه',
                                          'يرجى إدخال معلومات صحيحة',
                                        );
                                        return;
                                      }

                                      if (isReceptionist &&
                                          !RegExp(r'^07\d{9}$')
                                              .hasMatch(phone)) {
                                        Get.snackbar(
                                          'تنبيه',
                                          'رقم الهاتف غير صحيح',
                                        );
                                        return;
                                      }

                                      setDialogState(() => isSaving = true);
                                      try {
                                        await controller.patientController
                                            .updatePatientProfile(
                                          patientId: patient.id,
                                          name: name,
                                          phone: isReceptionist ? phone : null,
                                          gender: selectedGender,
                                          age: age,
                                          city: city,
                                        );
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                        Get.snackbar(
                                          'نجح',
                                          'تم تحديث معلومات المريض',
                                        );
                                      } catch (_) {
                                        // الخطأ يُعرض من الـ controller
                                      } finally {
                                        if (dialogContext.mounted) {
                                          setDialogState(() => isSaving = false);
                                        }
                                      }
                                    },
                              child: Container(
                                height: 42.h,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF162D4A),
                                      Color(0xFF4A88B8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Center(
                                  child: isSaving
                                      ? SizedBox(
                                          width: 18.w,
                                          height: 18.w,
                                          child:
                                              const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'حفظ',
                                          style: AppFonts.lamaSans(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTreatmentTypeDialog(BuildContext context, dynamic patient) {
    // Treatment types (ordered). Shown in a 2-column grid to avoid empty gaps.
    final List<String> treatmentTypes = [
      'حشوات',
      'تبييض',
      'تنضيف',
      'قلع',
      'زراعة',
      'تقويم',
      'ابتسامة',
    ];

    // Get current selected treatments - نأخذ نوع العلاج الحالي فقط (آخر عنصر = الأحدث)
    Set<String> selectedTreatments = <String>{};

    // التحقق من نوع العلاج الحالي بشكل آمن
    List<String>? treatmentHistory;
    if (patient is PatientModel) {
      treatmentHistory = patient.treatmentHistory;
    } else if (patient != null) {
      try {
        final th = patient.treatmentHistory;
        if (th != null && th is List) {
          treatmentHistory = th.map((e) => e.toString()).toList();
        }
      } catch (e) {
        print('⚠️ [PatientDetailsScreen] Error accessing treatmentHistory: $e');
      }
    }

    if (treatmentHistory != null && treatmentHistory.isNotEmpty) {
      // نأخذ آخر عنصر (الأحدث) ونقسمه على "، " إذا كان يحتوي على عدة أنواع
      final currentTreatment = treatmentHistory.last;
      if (currentTreatment.isNotEmpty) {
        // تقسيم string على "، " للحصول على الأنواع الفردية
        final treatments = currentTreatment
            .split('، ')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        selectedTreatments = Set<String>.from(treatments);
      }
    }

    // التحقق من وجود "زراعة" في نوع العلاج الحالي
    bool hasImplant = selectedTreatments.contains('زراعة');
    if (!hasImplant && treatmentHistory != null) {
      for (final t in treatmentHistory) {
        if (t.contains('زراعة')) {
          hasImplant = true;
          break;
        }
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'قم بتحديد نوع علاج المريض',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: _kPatientProfileNavy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h),

                    // Treatment options (2-column grid, RTL)
                    Directionality(
                      textDirection: ui.TextDirection.rtl,
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: treatmentTypes.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16.w,
                          mainAxisSpacing: 12.h,
                          childAspectRatio: 2.9,
                        ),
                        itemBuilder: (context, index) {
                          final treatment = treatmentTypes[index];
                          final isSelected =
                              selectedTreatments.contains(treatment);
                          final isImplantSelected =
                              selectedTreatments.contains('زراعة');
                          final isDisabled =
                              isImplantSelected && treatment != 'زراعة';

                          return _buildTreatmentOption(
                            treatment,
                            isSelected,
                            isDisabled,
                            () {
                              setDialogState(() {
                                if (treatment == 'زراعة') {
                                  if (selectedTreatments.contains('زراعة')) {
                                    selectedTreatments.remove('زراعة');
                                  } else {
                                    selectedTreatments.clear();
                                    selectedTreatments.add('زراعة');
                                  }
                                  return;
                                }

                                if (selectedTreatments.contains(treatment)) {
                                  selectedTreatments.remove(treatment);
                                } else {
                                  // If "زراعة" is selected, no other types allowed.
                                  if (!selectedTreatments.contains('زراعة')) {
                                    selectedTreatments.add(treatment);
                                  }
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),

                    // رسالة توضيحية عند اختيار "زراعة" في selectedTreatments
                    Builder(
                      builder: (context) {
                        // إعادة حساب isImplantSelected للرسالة (من selectedTreatments فقط)
                        final currentIsImplantSelected = selectedTreatments
                            .contains('زراعة');
                        if (currentIsImplantSelected) {
                          return Column(
                            children: [
                              SizedBox(height: 16.h),
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: _kPatientProfileNavyDark.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: _kPatientProfileBlue.withValues(
                                      alpha: 0.35,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: _kPatientProfileBlue,
                                      size: 20.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        'نوع العلاج "زراعة" لا يمكن اختياره مع أنواع أخرى',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: _kPatientProfileBlue,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),

                    SizedBox(height: 32.h),

                    // Buttons
                    Row(
                      children: [
                        // Back button (left)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: _kPatientProfileBg,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: _kPatientProfileDivider,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'عودة',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: _kPatientProfileGray,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        // Add button (right)
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              if (selectedTreatments.isEmpty) {
                                Get.snackbar(
                                  'تنبيه',
                                  'يرجى اختيار نوع العلاج على الأقل',
                                );
                                return;
                              }

                              // إذا كان "زراعة" مختارة، التأكد من أنها فقط
                              String treatmentType;
                              if (selectedTreatments.contains('زراعة')) {
                                treatmentType = 'زراعة';
                              } else {
                                // دمج جميع العلاجات المختارة في string واحد مفصول بفواصل
                                treatmentType = selectedTreatments.join('، ');
                              }

                              final patientController =
                                  controller.patientController;

                              try {
                                // الحصول على معرف المريض بشكل آمن
                                String? actualPatientId;
                                if (patient is PatientModel) {
                                  actualPatientId = patient.id;
                                } else if (patient != null &&
                                    patient.id != null) {
                                  actualPatientId = patient.id.toString();
                                }

                                if (actualPatientId == null) {
                                  Get.snackbar('خطأ', 'معرف المريض غير صحيح');
                                  return;
                                }

                                await patientController.setTreatmentType(
                                  patientId: actualPatientId,
                                  treatmentType: treatmentType,
                                );

                                // تحديث بيانات المريض في الصفحة
                                await patientController.loadPatients();

                                // تحديث بيانات المريض الحالي في الـ controller
                                final updatedPatient = patientController
                                    .getPatientById(actualPatientId);
                                if (updatedPatient != null) {
                                  controller.patientController.selectedPatient.value =
                                      updatedPatient;
                                }

                                // إذا كان النوع "زراعة"، تحميل المراحل
                                if (treatmentType == 'زراعة' &&
                                    controller.patientId != null) {
                                  final implantStageController = Get.put(
                                    ImplantStageController(),
                                  );
                                  await implantStageController.loadStages(
                                    controller.patientId!,
                                  );
                                }

                                Navigator.of(context).pop();
                                Get.snackbar(
                                  'نجح',
                                  'تم تحديث نوع العلاج بنجاح',
                                );
                                // العرض يعاد بناؤه تلقائياً بفضل التفاعلية (Obx)
                              } catch (e) {
                                Get.snackbar(
                                  'خطأ',
                                  'حدث خطأ أثناء تحديث نوع العلاج',
                                );
                              }
                            },
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                gradient: _kPatientProfileGradient,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Center(
                                child: Text(
                                  'اضافة',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTreatmentOption(
    String treatment,
    bool isSelected,
    bool isDisabled,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isDisabled
                ? _kPatientProfileBg
                : (isSelected
                      ? _kPatientProfileNavyDark.withValues(alpha: 0.04)
                      : AppColors.white),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected
                  ? _kPatientProfileBlue
                  : _kPatientProfileDivider,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Radio circle
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected ? _kPatientProfileGradient : null,
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isDisabled
                              ? _kPatientProfileDivider
                              : _kPatientProfileGray,
                          width: 2,
                        ),
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 14.sp, color: AppColors.white)
                    : null,
              ),
              SizedBox(width: 12.w),
              // Treatment text
              Expanded(
                child: Text(
                  treatment,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isDisabled
                        ? _kPatientProfileGray.withValues(alpha: 0.6)
                        : (isSelected
                              ? _kPatientProfileNavy
                              : _kPatientProfileGray),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // عرض صورة السجل
  void _showRecordImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black87,
            child: Stack(
              children: [
                // Full screen image with zoom
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      progressIndicatorBuilder: (context, url, progress) =>
                          Center(
                            child: CircularProgressIndicator(
                              value: progress.progress,
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                      errorWidget: (context, url, error) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 50.sp,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'فشل تحميل الصورة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 40.h,
                  right: 20.w,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                  ),
                ),
                // Save button
                Positioned(
                  top: 40.h,
                  left: 20.w,
                  child: GestureDetector(
                    onTap: () => _saveImage(context, imageUrl),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // عرض خيارات السجل (تعديل/حذف)
  void _showRecordOptionsDialog(
    BuildContext context,
    MedicalRecordModel record,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'خيارات السجل',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                // زر التعديل
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showEditRecordDialog(context, record);
                  },
                  icon: Icon(Icons.edit, color: AppColors.primary),
                  label: Text(
                    'تعديل',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // زر الحذف
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDeleteRecordConfirmDialog(context, record);
                  },
                  icon: Icon(Icons.delete, color: Colors.red),
                  label: Text(
                    'حذف',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // زر الإلغاء
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // حذف السجل مع تأكيد
  void _showDeleteRecordConfirmDialog(
    BuildContext context,
    MedicalRecordModel record,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'تأكيد الحذف',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'هل أنت متأكد من حذف هذا السجل؟',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (controller.patientId != null) {
                  try {
                    await controller.medicalRecordController.deleteRecord(
                      patientId: controller.patientId!,
                      recordId: record.id,
                    );
                  } catch (e) {
                    // Error already shown in controller
                  }
                }
              },
              child: Text(
                'حذف',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // إضافة سجل جديد
  void _showAddRecordDialog(BuildContext context) {
    List<File> selectedImages = [];
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'اضافة سجل',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      // Notes field
                      TextFormField(
                        controller: noteController,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: 'أدخل الملاحظات أو التشخيص...',
                          hintStyle: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 14.sp,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: EdgeInsets.all(16.w),
                        ),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 16.h),
                      // Add images button
                      GestureDetector(
                        onTap: () async {
                          try {
                            final List<XFile> images = await controller.imagePicker
                                .pickMultiImage(imageQuality: 85);
                            if (images.isNotEmpty) {
                              setDialogState(() {
                                selectedImages.addAll(
                                  images.map((img) => File(img.path)),
                                );
                              });
                            }
                          } catch (e) {
                            print(
                              '❌ [PatientDetailsScreen] Error picking images: $e',
                            );
                            if (context.mounted) {
                              Get.snackbar(
                                'خطأ',
                                'فشل اختيار الصور. تأكد من إعطاء الأذونات المطلوبة.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: AppColors.white,
                              );
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                color: AppColors.primary,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'إضافة صور (اختياري)',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Selected images preview
                      if (selectedImages.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Container(
                          height: 100.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedImages.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: EdgeInsets.only(left: 8.w),
                                width: 100.w,
                                height: 100.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: AppColors.divider,
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.r),
                                      child: Image.file(
                                        selectedImages[index],
                                        fit: BoxFit.cover,
                                        width: 100.w,
                                        height: 100.h,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4.h,
                                      left: 4.w,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            selectedImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4.w),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      SizedBox(height: 24.h),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  side: BorderSide(color: AppColors.divider),
                                ),
                              ),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (controller.patientId != null) {
                                  // حفظ القيم قبل إغلاق الـ dialog
                                  final noteText = noteController.text.trim();
                                  final imagesToSend = selectedImages.isEmpty
                                      ? null
                                      : List<File>.from(selectedImages);

                                  // إغلاق الـ dialog أولاً
                                  Navigator.of(context).pop();

                                  // انتظار قليلاً للتأكد من إغلاق الـ dialog
                                  await Future.delayed(
                                    const Duration(milliseconds: 100),
                                  );

                                  try {
                                    await controller.medicalRecordController.addRecord(
                                      patientId: controller.patientId!,
                                      note: noteText.isEmpty ? null : noteText,
                                      imageFiles: imagesToSend,
                                    );
                                  } catch (e) {
                                    // Error already shown in controller
                                  }
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                'حفظ',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          noteController.dispose();
        } catch (e) {
          // Controller already disposed
        }
      });
    });
  }

  // تعديل سجل موجود
  void _showEditRecordDialog(BuildContext context, MedicalRecordModel record) {
    List<File> newImages = [];
    List<String> existingImages = record.images ?? [];
    Set<int> deletedImageIndices = {};
    final TextEditingController noteController = TextEditingController(
      text: record.notes ?? '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'تعديل سجل',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24.h),
                      // Notes field
                      TextFormField(
                        controller: noteController,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: 'أدخل الملاحظات أو التشخيص...',
                          hintStyle: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 14.sp,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: EdgeInsets.all(16.w),
                        ),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 16.h),
                      // Existing images
                      if (existingImages.isNotEmpty) ...[
                        Text(
                          'الصور الحالية:',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          height: 100.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: existingImages.length,
                            itemBuilder: (context, index) {
                              if (deletedImageIndices.contains(index)) {
                                return SizedBox.shrink();
                              }
                              final imageUrl = ImageUtils.convertToValidUrl(
                                existingImages[index],
                              );
                              return Container(
                                margin: EdgeInsets.only(left: 8.w),
                                width: 100.w,
                                height: 100.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: AppColors.divider,
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.r),
                                      child:
                                          imageUrl != null &&
                                              ImageUtils.isValidImageUrl(
                                                imageUrl,
                                              )
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              width: 100.w,
                                              height: 100.h,
                                              progressIndicatorBuilder:
                                                  (
                                                    context,
                                                    url,
                                                    progress,
                                                  ) => Container(
                                                    color: AppColors.divider,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            value: progress
                                                                .progress,
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (
                                                    context,
                                                    url,
                                                    error,
                                                  ) => Container(
                                                    color: AppColors.divider,
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      color: AppColors.textHint,
                                                      size: 30.sp,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              color: AppColors.divider,
                                              child: Icon(
                                                Icons.broken_image,
                                                color: AppColors.textHint,
                                                size: 30.sp,
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      top: 4.h,
                                      left: 4.w,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            deletedImageIndices.add(index);
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4.w),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 16.h),
                      ],
                      // Add new images button
                      GestureDetector(
                        onTap: () async {
                          try {
                            final List<XFile> images = await controller.imagePicker
                                .pickMultiImage(imageQuality: 85);
                            if (images.isNotEmpty) {
                              setDialogState(() {
                                newImages.addAll(
                                  images.map((img) => File(img.path)),
                                );
                              });
                            }
                          } catch (e) {
                            print(
                              '❌ [PatientDetailsScreen] Error picking images: $e',
                            );
                            if (context.mounted) {
                              Get.snackbar(
                                'خطأ',
                                'فشل اختيار الصور. تأكد من إعطاء الأذونات المطلوبة.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red,
                                colorText: AppColors.white,
                              );
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                color: AppColors.primary,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'إضافة صور جديدة',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // New images preview
                      if (newImages.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Container(
                          height: 100.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: newImages.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: EdgeInsets.only(left: 8.w),
                                width: 100.w,
                                height: 100.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: AppColors.divider,
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.r),
                                      child: Image.file(
                                        newImages[index],
                                        fit: BoxFit.cover,
                                        width: 100.w,
                                        height: 100.h,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4.h,
                                      left: 4.w,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            newImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4.w),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      SizedBox(height: 24.h),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  side: BorderSide(color: AppColors.divider),
                                ),
                              ),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (controller.patientId != null) {
                                  // حفظ القيم قبل إغلاق الـ dialog
                                  final noteText = noteController.text.trim();
                                  // إذا كان هناك صور جديدة أو تم حذف صور، نرسل الصور الجديدة فقط
                                  // Backend سيستبدل جميع الصور بالصور الجديدة
                                  final imagesToSend =
                                      newImages.isEmpty &&
                                          deletedImageIndices.isEmpty
                                      ? null
                                      : List<File>.from(newImages);

                                  // إغلاق الـ dialog أولاً
                                  Navigator.of(context).pop();

                                  // انتظار قليلاً للتأكد من إغلاق الـ dialog
                                  await Future.delayed(
                                    const Duration(milliseconds: 100),
                                  );

                                  try {
                                    await controller.medicalRecordController.updateRecord(
                                      patientId: controller.patientId!,
                                      recordId: record.id,
                                      note: noteText.isEmpty ? null : noteText,
                                      imageFiles: imagesToSend,
                                    );
                                  } catch (e) {
                                    // Error already shown in controller
                                  }
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                'حفظ',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          noteController.dispose();
        } catch (e) {
          // Controller already disposed
        }
      });
    });
  }

  Widget _buildDoctorsSection(PatientModel patient) {
    return Obx(() {
      if (controller.isLoadingDoctors.value) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'الاطباء المعالجون',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            if (controller.patientDoctors.isEmpty)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'لم يتم تحويله الى طبيب حتى الان',
                      style: TextStyle(fontSize: 14.sp, color: AppColors.error),
                      textAlign: TextAlign.right,
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.info_outline,
                      color: AppColors.error,
                      size: 20.sp,
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.patientDoctors.length,
                itemBuilder: (context, index) {
                  final doctor = controller.patientDoctors[index];
                  final doctorName = doctor.name ?? 'طبيب';
                  final doctorInitials = doctorName.isNotEmpty
                      ? doctorName
                            .split(' ')
                            .map((n) => n.isNotEmpty ? n[0] : '')
                            .take(2)
                            .join()
                      : 'ط';

                  return Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.only(
                      left: 0.w,
                      top: 10.w,
                      bottom: 10.w,
                      right: 0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        // Doctor Image on the right (in RTL) - first element
                        Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16.r),
                            child: _buildDoctorImage(doctor, doctorInitials),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Doctor info column
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 0.w,
                              top: 12.w,
                              bottom: 12.w,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Doctor name at the top
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'د. $doctorName',
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                // Specialization
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'الاختصاص : طبيب اسنان',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.right,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      );
    });
  }
}
