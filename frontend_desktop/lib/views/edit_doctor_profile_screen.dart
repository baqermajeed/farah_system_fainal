import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';
import 'package:frontend_desktop/core/constants/app_strings.dart';
import 'package:frontend_desktop/core/widgets/custom_button.dart';
import 'package:frontend_desktop/core/widgets/custom_text_field.dart';
import 'package:frontend_desktop/core/widgets/back_button_widget.dart';
import 'package:frontend_desktop/controllers/auth_controller.dart';
import 'package:frontend_desktop/services/auth_service.dart';

class EditDoctorProfileScreen extends StatefulWidget {
  const EditDoctorProfileScreen({super.key});

  @override
  State<EditDoctorProfileScreen> createState() =>
      _EditDoctorProfileScreenState();
}

class _EditDoctorProfileScreenState extends State<EditDoctorProfileScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final AuthService _authService = AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() {
    final user = _authController.currentUser.value;
    _nameController.text = user?.name ?? '';
    _phoneController.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty) {
      _showResultDialog(
        context,
        isSuccess: false,
        message: 'يرجى إدخال الاسم',
      );
      return;
    }

    if (_phoneController.text.isEmpty) {
      _showResultDialog(
        context,
        isSuccess: false,
        message: 'يرجى إدخال رقم الهاتف',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
      );

      // تحديث معلومات المستخدم في AuthController بدون تبديل الشاشة
      await _authController.checkLoggedInUser(navigate: false);

      // العودة إلى الصفحة السابقة أولاً
      Get.back();

      // إظهار dialog النجاح بعد العودة
      Future.delayed(
        const Duration(milliseconds: 300),
        () {
          _showResultDialog(
            Get.context!,
            isSuccess: true,
            message: 'تم حفظ التغييرات بنجاح',
          );
        },
      );
    } catch (e) {
      // العودة إلى الصفحة السابقة أولاً
      Get.back();

      // إظهار dialog الفشل بعد العودة
      Future.delayed(
        const Duration(milliseconds: 300),
        () {
          _showResultDialog(
            Get.context!,
            isSuccess: false,
            message: 'فشل حفظ التغييرات: ${e.toString()}',
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            children: [
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  // Back button always on the LEFT
                  const BackButtonWidget(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'تعديل الملف الشخصي',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Empty space on the RIGHT to keep title centered
                  SizedBox(width: 40.w),
                ],
              ),
              SizedBox(height: 32.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 8.h),
                  CustomTextField(
                    controller: _nameController,
                    hintText: 'أدخل الاسم',
                    textAlign: TextAlign.right,
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    AppStrings.phoneNumber,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 8.h),
                  CustomTextField(
                    controller: _phoneController,
                    hintText: 'أدخل رقم الهاتف',
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              SizedBox(height: 48.h),
              CustomButton(
                text: 'حفظ التغييرات',
                onPressed: _isLoading ? null : _saveChanges,
                width: double.infinity,
                isLoading: _isLoading,
                backgroundColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultDialog(
    BuildContext context, {
    required bool isSuccess,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
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
              onPressed: () {
                Navigator.of(context).pop();
              },
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
        );
      },
    );
  }
}
