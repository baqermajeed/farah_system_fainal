import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/widgets/empty_state_widget.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:farah_sys_final/widgets/app_avatar.dart';
import 'package:google_fonts/google_fonts.dart';

class DoctorPatientsListScreen extends StatefulWidget {
  const DoctorPatientsListScreen({super.key});

  @override
  State<DoctorPatientsListScreen> createState() =>
      _DoctorPatientsListScreenState();
}

class _DoctorPatientsListScreenState extends State<DoctorPatientsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;

  // Extract MongoDB ObjectId timestamp (first 8 hex chars = seconds since epoch).
  int _objectIdSeconds(String id) {
    if (id.length < 8) return 0;
    return int.tryParse(id.substring(0, 8), radix: 16) ?? 0;
  }

  List<PatientModel> _sortNewestFirst(Iterable<PatientModel> patients) {
    final sorted = List<PatientModel>.from(patients);
    sorted.sort((a, b) => _objectIdSeconds(b.id).compareTo(_objectIdSeconds(a.id)));
    return sorted;
  }

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
    final patientController = Get.find<PatientController>();

    // Load patients on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      patientController.loadPatients();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Row(
                textDirection: TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button always on the LEFT
                  BackButtonWidget(
                    onTap: () {
                      // If this screen is the root (e.g. navigated via offAll),
                      // Get.back() won't do anything. Fallback to doctor home.
                      final nav = Navigator.of(context);
                      if (nav.canPop()) {
                        nav.pop();
                      } else {
                        Get.offAllNamed(AppRoutes.doctorHome);
                      }
                    },
                  ),
                  // Title in center
                  Expanded(
                    child: Center(
                      child: Text(
                        'جميع المرضى',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Add patient button on the RIGHT
                  GestureDetector(
                    onTap: () async {
                      final result = await Get.toNamed(AppRoutes.addPatient);
                      // Reload patients when returning from add patient screen
                      patientController.loadPatients();
                      // عرض dialog النجاح أو الفشل
                      if (result != null) {
                        _showResultDialog(result as bool);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.person_add,
                        color: AppColors.primary,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مريض...',
                    hintStyle: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                      size: 24.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            // Patients List
            Expanded(
              child: Obx(() {
                if (patientController.isLoading.value) {
                  return const LoadingWidget(message: 'جاري تحميل المرضى...');
                }

                final filteredPatientsRaw = _searchQuery.value.isEmpty
                    ? patientController.patients
                    : patientController.searchPatients(_searchQuery.value);
                final filteredPatients = _sortNewestFirst(filteredPatientsRaw);

                if (filteredPatients.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.people_outline,
                    title: 'لا يوجد مرضى',
                    subtitle: _searchQuery.value.isEmpty
                        ? 'لم يتم إضافة أي مريض بعد'
                        : 'لم يتم العثور على نتائج',
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patient = filteredPatients[index];
                    return _buildPatientCard(patient);
                  },
                );
              }),
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
        constraints: BoxConstraints(minHeight: 72.h),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          children: [
            // Patient Image (مطابق لتصميم الصفحة الرئيسية)
            Transform.translate(
              offset: Offset(-8.w, 0),
            child: AppAvatar(
              imageUrl: patient.imageUrl,
              size: 55.w,
              cornerRadius: 10.r,
              backgroundColor: AppColors.white,
              borderColor: AppColors.divider,
              borderWidth: 1,
            ),
            ),
            SizedBox(width: 16.w),
            // Patient Details + chat icon (مطابق لتصميم الصفحة الرئيسية)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.rtl,
                        children: [
                          // الاسم مع تلوين مختلف
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    GestureDetector(
                      onTap: () async {
                        await Get.toNamed(
                          AppRoutes.chat,
                          arguments: {'patientId': patient.id},
                        );
                      },
                      child: Image.asset(
                        'assets/images/message.png',
                        width: 25.sp,
                        height: 25.sp,
                      fit: BoxFit.contain,
                      ),
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

  void _showResultDialog(bool success) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Container(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                  size: 64.sp,
                ),
                SizedBox(height: 16.h),
                // Title
                Text(
                  success ? 'نجح' : 'فشل',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                // Message
                Text(
                  success
                      ? 'تم إضافة المريض بنجاح'
                      : 'حدث خطأ أثناء إضافة المريض',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 24.h),
                // OK Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'موافق',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
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
}
