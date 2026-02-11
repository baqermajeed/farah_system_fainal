import 'package:get/get.dart';

import '../services/admin_service.dart';

class CreateCallCenterStaffController extends GetxController {
  final _admin = AdminService();

  final RxBool saving = false.obs;
  final RxnString error = RxnString();

  Future<void> create({
    required String name,
    required String phone,
    required String username,
    required String password,
    String? imageUrl,
  }) async {
    saving.value = true;
    error.value = null;
    try {
      await _admin.createCallCenterStaff(
        phone: phone,
        username: username,
        password: password,
        name: name,
        imageUrl: imageUrl,
      );
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      saving.value = false;
    }
  }
}

