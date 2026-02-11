import 'package:get/get.dart';

import '../models/call_center_staff.dart';
import '../services/admin_service.dart';

class CallCenterStaffController extends GetxController {
  final _admin = AdminService();

  final RxBool loading = false.obs;
  final RxnString error = RxnString();
  final RxList<CallCenterStaff> staff = <CallCenterStaff>[].obs;

  Future<void> loadStaff() async {
    loading.value = true;
    error.value = null;
    try {
      final list = await _admin.getCallCenterStaff();
      staff.assignAll(list);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }
}

