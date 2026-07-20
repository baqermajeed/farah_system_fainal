import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/services/auth_service.dart';

/// Controller لشاشة تعديل الملف الشخصي لموظف الاستقبال.
class EditReceptionProfileController extends GetxController {
  final AuthService _authService = AuthService();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final RxBool isLoading = false.obs;

  AuthController get authController => Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    loadCurrentData();
  }

  void loadCurrentData() {
    final user = authController.currentUser.value;
    nameController.text = user?.name ?? '';
    phoneController.text = user?.phoneNumber ?? '';
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  Future<void> saveChanges() async {
    if (nameController.text.isEmpty) {
      showResultDialog(isSuccess: false, message: 'يرجى إدخال الاسم');
      return;
    }

    if (phoneController.text.isEmpty) {
      showResultDialog(isSuccess: false, message: 'يرجى إدخال رقم الهاتف');
      return;
    }

    isLoading.value = true;

    try {
      await _authService.updateProfile(
        name: nameController.text,
        phone: phoneController.text,
      );

      // تحديث معلومات المستخدم في AuthController
      await authController.checkLoggedInUser(navigate: false);

      // العودة إلى الصفحة السابقة أولاً
      Get.back();

      // إظهار dialog النجاح بعد العودة
      Future.delayed(const Duration(milliseconds: 300), () {
        showResultDialog(isSuccess: true, message: 'تم حفظ التغييرات بنجاح');
      });
    } catch (e) {
      // العودة إلى الصفحة السابقة أولاً
      Get.back();

      // إظهار dialog الفشل بعد العودة
      Future.delayed(const Duration(milliseconds: 300), () {
        showResultDialog(
          isSuccess: false,
          message: 'فشل حفظ التغييرات: ${e.toString()}',
        );
      });
    } finally {
      isLoading.value = false;
    }
  }

  void showResultDialog({required bool isSuccess, required String message}) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 28.sp,
            ),
            SizedBox(width: 12.w),
            Text(
              isSuccess ? 'نجح' : 'فشل',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 16.sp, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'حسناً',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
