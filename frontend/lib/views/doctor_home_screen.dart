import 'package:flutter/material.dart';
import 'package:farah_sys_final/core/theme/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/doctor_home_controller.dart';
import 'package:farah_sys_final/models/patient_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:farah_sys_final/widgets/portrait_network_image.dart';

class DoctorHomeScreen extends GetView<DoctorHomeController> {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
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
                      Get.toNamed(AppRoutes.doctorProfile);
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
        color: Colors.black.withOpacity(0.15), // 25%
        offset: Offset(0, 4), // Y = 4
        blurRadius: 4, // Blur = 4
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
                Text(
  'الصفحة الرئيسية',
  style: AppFonts.lamaSans(
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

                      // Chat Icon with notification dot
                      GestureDetector(
                        onTap: controller.openChatsAndRefresh,
                        child: Obx(() {
                          final hasUnread = controller.totalUnreadCount > 0;
                          return Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.w),
                                child: Image.asset(
                                  'assets/images/message.png',
                                  width: 35.sp,
                                  height: 35.sp,
                                  fit: BoxFit.contain,
                                  // color: AppColors.primary,
                                ),
                              ),
                              if (hasUnread)
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  child: Container(
                                    width: 10.w,
                                    height: 10.h,
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }),
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
                  // 
                  Expanded(
  child: SizedBox(
    height: 45.h, // ✅ ارتفاع الشريط
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          width: 1, // ✅ stroke 1
          color: const Color(0x80649FCC), // ✅ #649FCC 50%
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
        controller: controller.searchController,
        onChanged: (value) => controller.searchQuery.value = value,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: 'ابحث عن مريض...',
          hintStyle: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textSecondary,
          ),
          border: InputBorder.none,
          isDense: true,

          // ✅ نخلي ارتفاع النص مضبوط داخل 45
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),

          // ✅ يمين (RTL): أيقونة البحث ثم الخط العمودي، وبعدها النص
          // في RTL الأفضل استخدام prefixIcon لأنه يظهر في بداية الحقل (يمين)
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
                    color: const Color(0x80649FCC), // نفس لون الستروك 50%
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
                  // Calendar Icon (على اليمين في RTL)
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
                    // Recent Patients Section
                    Padding(
                      // ✅ محاذاة العنوان مع بداية كروت المرضى (لأن أول كارت عليه right: 12.w)
                      padding: EdgeInsets.only(bottom: 16.h, right: 12.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'اخر المرضى',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          // Scroll arrow (optional) - على اليسار في RTL
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16.sp,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    // Recent Patients Horizontal List
                    // يعرض فقط المرضى المرتبطين بالطبيب الحالي (من patientController.patients)
                    Obx(() {
                      // patientController.patients يحتوي فقط على المرضى المرتبطين بالطبيب
                      // (يتم جلبهم من /doctor/patients في loadPatients())
                      final allPatients = controller.filteredPatients;
                      final recentPatients = allPatients.take(5).toList();

                      if (recentPatients.isEmpty) {
                        return Container(
                          height: 150.h,
                          alignment: Alignment.center,
                          child: Text(
                            'لا يوجد مرضى حديثين',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      return SizedBox(
                        height: 155.h,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          reverse:
                              false, // RTL - لا نحتاج reverse لأن العناصر تبدأ من اليمين تلقائياً
                          itemCount: recentPatients.length,
                          itemBuilder: (context, index) {
                            final patient = recentPatients[index];
                            return Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: _buildRecentPatientCard(patient),
                            );
                          },
                        ),
                      );
                    }),
                    SizedBox(height: 32.h),
                    // All Patients Section
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.h),
                      child: GestureDetector(
                        onTap: () {
                          Get.toNamed(AppRoutes.doctorPatientsList);
                        },

                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'جميع المرضى',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            // Scroll arrow (optional) - على اليسار في RTL
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16.sp,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // All Patients Vertical List
                    // يعرض فقط المرضى المرتبطين بالطبيب الحالي (من patientController.patients)
                    Obx(() {
                      // patientController.patients يحتوي فقط على المرضى المرتبطين بالطبيب
                      // (يتم جلبهم من /doctor/patients في loadPatients())
                      final allPatients = controller.filteredPatients;

                      if (controller.isLoading.value) {
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
                          return _buildAllPatientCard(patient);
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

  Widget _buildRecentPatientCard(PatientModel patient) {
    return GestureDetector(
      onTap: () => controller.openPatient(patient),
      child: Container(
        width: 100.w,
        height: 150.h,
        padding: EdgeInsets.only(top: 6.w, bottom: 6.h),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.divider.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Patient Image
            PortraitNetworkImage(
              imageUrl: patient.imageUrl,
              borderRadius: BorderRadius.circular(12.r),
              width: 90.w,
              height: 100.h,
            ),
            SizedBox(height: 4.h),
            // Patient Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  // Patient Name
                  Text(
                    patient.name.split(' ').first, // First name only
                    style: AppFonts.lamaSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF649FCC),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  SizedBox(height: 2.h),
                  // Treatment Type
                  Text(
                    patient.treatmentHistory != null &&
                            patient.treatmentHistory!.isNotEmpty
                        ? patient.treatmentHistory!.last
                        : 'لا يوجد',
                    style: AppFonts.lamaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF505558),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllPatientCard(PatientModel patient) {
    return GestureDetector(
      onTap: () => controller.openPatient(patient),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.only(left: 20.w, right: 0.w, top: 2.h, bottom: 2.h),
        // Avoid tiny BottomOverflow on some devices due to font/layout rounding.
        // Keep the same visual size, but allow the card to grow if needed.
        constraints: BoxConstraints(minHeight: 72.h),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          children: [
            // Patient Image (على اليمين في RTL - أول عنصر)
            Transform.translate(
              offset: Offset(-8.w, 0),
              child: PortraitNetworkImage(
                imageUrl: patient.imageUrl,
                width: 55.w,
                  aspectRatio: 55 / 60,
                borderRadius: BorderRadius.circular(10.r),
                
              ),
            ),
            SizedBox(width: 16.w),
            // Patient Details and Chat Icon in a Row with padding
            Expanded(
              child: Padding(
                // ✅ تقليل المسافات العمودية لتفادي overflow مع height: 72.h
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Row(
                  children: [
                    // Patient Details (في المنتصف)
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
                                  style: AppFonts.lamaSans(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF505558),
                                  ),
                                ),
                                TextSpan(
                                  text: patient.name,
                                  style: AppFonts.lamaSans(
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
                            style: AppFonts.lamaSans(
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
                            style: AppFonts.lamaSans(
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
                    SizedBox(width: 16.w),
                    // Chat Icon with notification dot (على اليسار في RTL - آخر عنصر)
                    GestureDetector(
                      onTap: () => controller.openPatientChatAndRefresh(patient.id),
                      child: Obx(() {
                        final unreadCount = controller.unreadCounts[patient.id] ?? 0;
                        return Stack(
                          children: [
                            Image.asset(
                              'assets/images/message.png',
                              width: 25.sp,
                              height: 25.sp,
                            fit: BoxFit.contain,
                              //  color: AppColors.primary,
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 10.w,
                                  height: 10.h,
                                  decoration: BoxDecoration(
                                    color: Colors.pink,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
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
}
