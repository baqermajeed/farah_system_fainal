import 'package:get/get.dart';

import '../services/admin_service.dart';

class CreateDoctorController extends GetxController {
  final _admin = AdminService();

  final RxBool saving = false.obs;
  final RxnString error = RxnString();

  Future<void> create({
    required String name,
    required String phone,
    required String username,
    required String password,
  }) async {
    saving.value = true;
    error.value = null;
    try {
      await _admin.createDoctor(
        phone: phone,
        username: username,
        password: password,
        name: name,
      );
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      saving.value = false;
    }
  }
}


