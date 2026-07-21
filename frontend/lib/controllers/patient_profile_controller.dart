import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:farah_sys_final/controllers/auth_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';
import 'package:farah_sys_final/core/utils/image_cropper_settings.dart';

/// Controller لشاشة الملف الشخصي للمريض — المنطق والحالة خارج الـ View.
class PatientProfileController extends GetxController {
  AuthController get authController => Get.find<AuthController>();
  PatientController get patientController => Get.find<PatientController>();
  final ImagePicker _imagePicker = ImagePicker();

  final RxBool isUploadingImage = false.obs;
  final RxInt imageTimestamp = RxInt(DateTime.now().millisecondsSinceEpoch);

  @override
  void onReady() {
    super.onReady();
    loadData();
  }

  void loadData() {
    patientController.loadMyProfile();
    patientController.loadMyDoctor();
  }

  Future<void> pickAndUploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image == null) return;

      final croppedFile = await cropProfileImage(image.path);
      if (croppedFile == null) return;

      isUploadingImage.value = true;

      await patientController.uploadMyProfileImage(croppedFile);
      imageTimestamp.value = DateTime.now().millisecondsSinceEpoch;
      Get.snackbar('نجح', 'تم تحديث الصورة بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث الصورة');
    } finally {
      isUploadingImage.value = false;
    }
  }
}
