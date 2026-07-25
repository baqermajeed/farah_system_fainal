import 'package:get/get.dart';
import 'package:farah_sys_final/core/routes/app_routes.dart';
import 'package:farah_sys_final/controllers/doctor_home_controller.dart';
import 'package:farah_sys_final/controllers/doctor_chats_screen_controller.dart';
import 'package:farah_sys_final/controllers/doctor_stats_controller.dart';
import 'package:farah_sys_final/controllers/patient_controller.dart';

class DoctorShellController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final RxSet<int> loadedTabs = <int>{0}.obs;

  void selectTab(int index) {
    if (index == 2) return;
    if (index == currentIndex.value) return;
    loadedTabs.add(index);
    currentIndex.value = index;
    switch (index) {
      case 0:
        Get.find<DoctorHomeController>().refreshDashboard();
        break;
      case 1:
        _ensureChatsController().loadChatList();
        break;
      case 3:
        _ensureStatsController().loadStats();
        break;
    }
  }

  DoctorChatsScreenController _ensureChatsController() {
    if (!Get.isRegistered<DoctorChatsScreenController>()) {
      Get.lazyPut<DoctorChatsScreenController>(
        () => DoctorChatsScreenController(),
      );
    }
    return Get.find<DoctorChatsScreenController>();
  }

  DoctorStatsController _ensureStatsController() {
    if (!Get.isRegistered<DoctorStatsController>()) {
      Get.lazyPut<DoctorStatsController>(() => DoctorStatsController());
    }
    return Get.find<DoctorStatsController>();
  }

  Future<void> onAddPatient() async {
    await Get.toNamed(AppRoutes.addPatient);
    Get.find<PatientController>().refreshDoctorPatients();
    Get.find<DoctorHomeController>().refreshDashboard();
  }
}
