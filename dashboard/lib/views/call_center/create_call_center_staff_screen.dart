import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/create_call_center_staff_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_back_button.dart';

class CreateCallCenterStaffScreen extends StatefulWidget {
  const CreateCallCenterStaffScreen({super.key});

  @override
  State<CreateCallCenterStaffScreen> createState() =>
      _CreateCallCenterStaffScreenState();
}

class _CreateCallCenterStaffScreenState
    extends State<CreateCallCenterStaffScreen> {
  late final CreateCallCenterStaffController _c;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _imageUrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c = Get.put(CreateCallCenterStaffController());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _username.dispose();
    _password.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    try {
      await _c.create(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      );
      if (mounted) {
        Get.back(result: true);
        Get.snackbar(
          'تم بنجاح',
          'تم إنشاء حساب موظف مركز الاتصالات',
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          colorText: AppColors.success,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
          borderRadius: 16,
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
        );
      }
    } catch (_) {
      // handled via controller error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'إضافة موظف مركز اتصالات',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: const [
            Padding(
              padding: EdgeInsets.only(left: 16),
              child: AppBackButton(),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_rounded,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.divider.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _ModernInput(
                        controller: _name,
                        label: 'اسم الموظف',
                        icon: Icons.badge_rounded,
                      ),
                      const SizedBox(height: 16),
                      _ModernInput(
                        controller: _phone,
                        label: 'رقم الهاتف',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _ModernInput(
                        controller: _username,
                        label: 'اسم المستخدم (للدخول)',
                        icon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 16),
                      _ModernInput(
                        controller: _password,
                        label: 'كلمة المرور',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                      ),
                      const SizedBox(height: 16),
                      _ModernInput(
                        controller: _imageUrl,
                        label: 'رابط الصورة (اختياري)',
                        icon: Icons.image_rounded,
                        keyboardType: TextInputType.url,
                        requiredField: false,
                      ),
                      const SizedBox(height: 24),
                      Obx(() {
                        final err = _c.error.value;
                        if (err == null || err.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  err,
                                  style: GoogleFonts.cairo(
                                      color: AppColors.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      Obx(() {
                        return SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _c.saving.value ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _c.saving.value
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.white),
                                  )
                                : Text(
                                    'إنشاء الحساب',
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        );
                      }),
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
}

class _ModernInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final bool requiredField;

  const _ModernInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.requiredField = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.6)),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
      validator: (v) {
        if (!requiredField) return null;
        return (v == null || v.trim().isEmpty) ? 'مطلوب' : null;
      },
    );
  }
}

