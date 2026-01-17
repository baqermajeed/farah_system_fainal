import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/core/widgets/custom_button.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/core/widgets/loading_widget.dart';
import 'package:farah_sys_final/core/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:farah_sys_final/core/widgets/back_button_widget.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final patientController = Get.find<PatientController>();

    // تحميل الملف الشخصي فقط بدون أي إعادة توجيه
    patientController.loadMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final patientController = Get.find<PatientController>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    const BackButtonWidget(),
                    Expanded(
                      child: Center(
                        child: Text(
                          AppStrings.profile,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final user = authController.currentUser.value;
                        final profile = patientController.myProfile.value;
                        final patientId =
                            user?.id ?? profile?.id ?? 'demo_patient_1';
                        final qrCodeData = profile?.qrCodeData ?? patientId;
                        final patientName =
                            user?.name ?? profile?.name ?? 'مريض';
                        Get.toNamed(
                          AppRoutes.qrCode,
                          arguments: {
                            'patientId': patientId,
                            'qrCodeData': qrCodeData,
                            'patientName': patientName,
                          },
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.qr_code,
                          color: AppColors.primary,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              // Profile Image
              Obx(() {
                final user = authController.currentUser.value;
                final imageUrl = user?.imageUrl;
                final validImageUrl = ImageUtils.convertToValidUrl(imageUrl);

                if (validImageUrl != null &&
                    ImageUtils.isValidImageUrl(validImageUrl)) {
                  return CircleAvatar(
                    radius: 60.r,
                    backgroundColor: AppColors.primaryLight,
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: validImageUrl,
                        fit: BoxFit.cover,
                        width: 120.w,
                        height: 120.w,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (context, url) =>
                            Container(color: AppColors.primaryLight),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          size: 60.sp,
                          color: AppColors.white,
                        ),
                        memCacheWidth: 240,
                        memCacheHeight: 240,
                      ),
                    ),
                  );
                }

                return CircleAvatar(
                  radius: 60.r,
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(
                    Icons.person,
                    size: 60.sp,
                    color: AppColors.white,
                  ),
                );
              }),
              SizedBox(height: 32.h),
              Obx(() {
                if (patientController.isLoading.value &&
                    patientController.myProfile.value == null) {
                  return const LoadingWidget(message: 'جاري تحميل البيانات...');
                }

                final profile = patientController.myProfile.value;
                final user = authController.currentUser.value;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          user?.name ?? profile?.name ?? 'غير محدد',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        AppStrings.phoneNumber,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          user?.phoneNumber ??
                              profile?.phoneNumber ??
                              'غير محدد',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        AppStrings.governorate,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          profile?.city ?? user?.city ?? 'غير محدد',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppStrings.gender,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                    vertical: 16.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Text(
                                    profile?.gender ??
                                        user?.gender ??
                                        'غير محدد',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppStrings.age,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                    vertical: 16.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Text(
                                    '${profile?.age ?? user?.age ?? 0}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 32.h),
                      CustomButton(
                        text: 'تعديل الملف الشخصي',
                        onPressed: () async {
                          await Get.toNamed(AppRoutes.editPatientProfile);
                          // إعادة تحميل البيانات عند العودة من صفحة التعديل
                          _loadData();
                        },
                        backgroundColor: AppColors.primary,
                        width: double.infinity,
                        icon: Icon(
                          Icons.edit,
                          color: AppColors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      CustomButton(
                        text: AppStrings.logout,
                        onPressed: () async {
                          await authController.logout();
                        },
                        backgroundColor: AppColors.error,
                        width: double.infinity,
                        icon: Icon(
                          Icons.exit_to_app,
                          color: AppColors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(height: 32.h),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
