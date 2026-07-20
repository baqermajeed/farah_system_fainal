import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';
import 'package:farah_sys_final/core/constants/app_strings.dart';
import 'package:farah_sys_final/core/constants/iraq_governorates.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';

/// Controller لشاشة تعديل الملف الشخصي للمريض — المنطق والحالة خارج الـ View.
class EditPatientProfileController extends GetxController {
  AuthController get authController => Get.find<AuthController>();
  PatientController get patientController => Get.find<PatientController>();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  final Rx<String?> selectedGender = Rx<String?>(null);
  final Rx<String?> selectedCity = Rx<String?>(null);
  final RxBool isUploadingImage = false.obs;
  final RxInt imageTimestamp = RxInt(DateTime.now().millisecondsSinceEpoch);

  List<String> get cities => IraqGovernorates.arabicNames;

  bool get isLoading => patientController.isLoading.value;

  @override
  void onReady() {
    super.onReady();
    loadCurrentData();
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    ageController.dispose();
    super.onClose();
  }

  Future<void> loadCurrentData() async {
    if (patientController.myProfile.value == null) {
      await patientController.loadMyProfile();
    }
    if (authController.currentUser.value == null) {
      await authController.checkLoggedInUser();
    }

    final user = authController.currentUser.value;
    final profile = patientController.myProfile.value;

    // بيانات العرض/التعديل من الملف الطبي النشط (فرد العائلة)
    nameController.text = profile?.name ?? user?.name ?? '';
    phoneController.text =
        user?.phoneNumber ?? profile?.phoneNumber ?? '';
    ageController.text = (profile?.age ?? user?.age ?? 0).toString();

    final gender = profile?.gender ?? user?.gender;
    if (gender == 'male') {
      selectedGender.value = AppStrings.male;
    } else if (gender == 'female') {
      selectedGender.value = AppStrings.female;
    } else {
      selectedGender.value = gender;
    }

    final cityFromData = profile?.city ?? user?.city;
    var city = IraqGovernorates.toArabic(cityFromData);
    if (city != null && !cities.contains(city)) {
      city = null;
    }
    selectedCity.value = city;
  }

  void setGender(String gender) {
    selectedGender.value = gender;
  }

  void setCity(String city) {
    selectedCity.value = city;
  }

  Future<bool> saveProfile() async {
    if (nameController.text.isEmpty) {
      return false;
    }

    String? genderValue;
    if (selectedGender.value == AppStrings.male) {
      genderValue = 'male';
    } else if (selectedGender.value == AppStrings.female) {
      genderValue = 'female';
    } else {
      genderValue = selectedGender.value;
    }

    final cityValue = IraqGovernorates.toEnglish(selectedCity.value);

    await patientController.updateMyProfile(
      name: nameController.text,
      gender: genderValue,
      age: int.tryParse(ageController.text),
      city: cityValue,
    );

    return true;
  }

  Future<void> pickAndUploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'تعديل الصورة',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'تعديل الصورة',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (croppedFile == null) return;

      isUploadingImage.value = true;

      await patientController.uploadMyProfileImage(File(croppedFile.path));
      imageTimestamp.value = DateTime.now().millisecondsSinceEpoch;
      Get.snackbar('نجح', 'تم تحديث الصورة بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث الصورة');
    } finally {
      isUploadingImage.value = false;
    }
  }
}
