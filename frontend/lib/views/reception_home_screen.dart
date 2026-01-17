import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class ReceptionHomeScreen extends StatefulWidget {
  const ReceptionHomeScreen({super.key});

  @override
  State<ReceptionHomeScreen> createState() => _ReceptionHomeScreenState();
}

class _ReceptionHomeScreenState extends State<ReceptionHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchQuery.value = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final patientController = Get.find<PatientController>();

    // Load patients on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      patientController.loadPatients();
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFF),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Right Profile Avatar (على اليمين في RTL)
                  GestureDetector(
                    onTap: () {
                      Get.toNamed(AppRoutes.receptionProfile);
                    },
                    child: Obx(() {
                      final user = authController.currentUser.value;
                      final imageUrl = user?.imageUrl;
                      final validImageUrl = ImageUtils.convertToValidUrl(
                        imageUrl,
                      );

                      return Container(
                        width: 50.w,
                        height: 50.w,
                        padding: EdgeInsets.all(1.w), // المسافة بين الإطار والصورة
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF5B97D0),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: (validImageUrl != null &&
                                  ImageUtils.isValidImageUrl(validImageUrl))
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: validImageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.primary),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.person,
                                      color: AppColors.white,
                                      size: 20.sp,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  color: AppColors.white,
                                  size: 20.sp,
                                ),
                        ),
                      );
                    }),
                  ),
                  // Center Title
                  Text(
                    'الصفحة الرئيسية',
                    style: GoogleFonts.cairo(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF505558),
                    ),
                  ),
                  // Left Icons (على اليسار في RTL)
                  Row(
                    children: [
                      // Barcode Icon
                      GestureDetector(
                        onTap: () {
                          Get.toNamed(AppRoutes.qrScanner);
                        },
                        child: Image.asset(
                          'assets/images/barcode.png',
                          width: 30.sp,
                          height: 30.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Add Patient (بدل زر الدردشة)
                      GestureDetector(
                        onTap: () {
                          Get.toNamed(AppRoutes.addPatient);
                        },
                        child: Padding(
                          padding: EdgeInsets.all(8.w),
                          child: Icon(
                            Icons.person_add,
                            color: AppColors.primary,
                            size: 30.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Search Bar with Calendar Icon
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 6.h),
              child: Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: SizedBox(
                      height: 45.h, // ✅ نفس ارتفاع شريط الطبيب
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            width: 1,
                            color: const Color(0x80649FCC), // #649FCC 50%
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.divider.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => _searchQuery.value = value,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: 'ابحث عن مريض...',
                            hintStyle: GoogleFonts.cairo(
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            // RTL: نستخدم prefixIcon حتى يظهر يمين الحقل
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 0, minHeight: 0),
                            prefixIcon: Padding(
                              padding: EdgeInsetsDirectional.only(start: 12.w),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: AppColors.textSecondary,
                                    size: 24.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    width: 1.5.w,
                                    height: 24.h,
                                    decoration: BoxDecoration(
                                      color: const Color(0x80649FCC),
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Calendar Icon with green dot (on the right in RTL)
                  GestureDetector(
                    onTap: () {
                      Get.toNamed(AppRoutes.appointments);
                    },
                    child: Stack(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.divider.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            color: AppColors.primary,
                            size: 24.sp,
                          ),
                        ),
                        Positioned(
                          right: 8.w,
                          top: 8.h,
                          child: Container(
                            width: 8.w,
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // All Patients Section
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.h, top: 8.h),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'جميع المرضى',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.cairo(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    // All Patients Vertical List
                    Obx(() {
                      final allPatients = _searchQuery.value.isEmpty
                          ? patientController.patients
                          : patientController.searchPatients(
                              _searchQuery.value,
                            );

                      if (patientController.isLoading.value) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.h),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }

                      if (allPatients.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(32.h),
                          alignment: Alignment.center,
                          child: Text(
                            'لا يوجد مرضى',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: allPatients.length,
                        itemBuilder: (context, index) {
                          final patient = allPatients[index];
                          return _buildPatientCard(patient);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(PatientModel patient) {
    return GestureDetector(
      onTap: () {
        final patientController = Get.find<PatientController>();
        patientController.selectPatient(patient);
        Get.toNamed(
          AppRoutes.patientDetails,
          arguments: {'patientId': patient.id},
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.only(left: 20.w, right: 0.w, top: 2.h, bottom: 2.h),
        // Match doctor "All Patients" card sizing to avoid overflow on small devices
        constraints: BoxConstraints(minHeight: 72.h),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // Patient Image (على اليمين في RTL - أول عنصر) - match doctor card
                Transform.translate(
                  offset: Offset(-8.w, 0),
                  child: Container(
                    width: 55.w,
                    height: 60.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: Builder(
                        builder: (context) {
                          final imageUrl = patient.imageUrl;
                          final validImageUrl =
                              ImageUtils.convertToValidUrl(imageUrl);

                          if (validImageUrl != null &&
                              ImageUtils.isValidImageUrl(validImageUrl)) {
                            return CachedNetworkImage(
                              imageUrl: validImageUrl,
                              fit: BoxFit.cover,
                              width: 55.w,
                              height: 60.h,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              memCacheWidth: 160,
                              memCacheHeight: 170,
                              placeholder: (context, url) => Container(
                                width: 55.w,
                                height: 60.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.r),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.secondary,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: AppColors.white,
                                  size: 30.sp,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 55.w,
                                height: 60.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.r),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.secondary,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: AppColors.white,
                                  size: 30.sp,
                                ),
                              ),
                            );
                          }

                          return Container(
                            width: 55.w,
                            height: 60.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.r),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.secondary,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              color: AppColors.white,
                              size: 30.sp,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                // Patient Details - match doctor card typography
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: [
                        RichText(
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              TextSpan(
                                text: 'الاسم : ',
                                style: GoogleFonts.cairo(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF505558),
                                ),
                              ),
                              TextSpan(
                                text: patient.name,
                                style: GoogleFonts.cairo(
                                  color: AppColors.primary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'العمر : ${patient.age} سنة',
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF505558),
                          ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'نوع العلاج : ${patient.treatmentHistory != null && patient.treatmentHistory!.isNotEmpty ? patient.treatmentHistory!.last : 'لا يوجد'}',
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF505558),
                          ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Keep receptionist-specific red dot indicator for patients without doctors
            if (patient.doctorIds.isEmpty)
              Positioned(
                right: 8.w,
                top: 8.h,
                child: Container(
                  width: 12.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
