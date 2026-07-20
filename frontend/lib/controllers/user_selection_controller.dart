import 'package:get/get.dart';

import '../core/routes/app_routes.dart';

/// Controller لشاشة اختيار نوع المستخدم.
class UserSelectionController extends GetxController {
  final Rxn<String> selectedUserType = Rxn<String>();

  void selectUserType(String type) {
    selectedUserType.value = type;
  }

  void navigateNext() {
    switch (selectedUserType.value) {
      case 'patient':
        Get.toNamed(AppRoutes.patientLogin);
        break;
      case 'doctor':
        Get.toNamed(AppRoutes.doctorLogin);
        break;
      case 'receptionist':
        Get.toNamed(AppRoutes.receptionLogin);
        break;
    }
  }
}
