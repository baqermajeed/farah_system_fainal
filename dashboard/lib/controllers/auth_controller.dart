import 'package:get/get.dart';

import '../models/user_me.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';

class AuthController extends GetxController {
  final _authService = AuthService();
  final _storage = SecureStorageService();

  final RxBool booting = true.obs;
  final RxBool loggingIn = false.obs;
  final RxnString error = RxnString();

  final RxnString token = RxnString();
  final Rxn<UserMe> me = Rxn<UserMe>();

  bool get isAuthed => token.value != null && me.value != null;
  bool get isAdmin => me.value?.isAdmin == true;

  Future<void> bootstrap() async {
    booting.value = true;
    error.value = null;
    try {
      final saved = await _storage.readToken();
      if (saved == null || saved.isEmpty) {
        token.value = null;
        me.value = null;
        return;
      }
      token.value = saved;
      ApiClient.instance.setToken(saved);

      final user = await _authService.me();
      if (!user.isAdmin) {
        await logout(message: 'هذا الحساب ليس مدير (admin).');
        return;
      }
      me.value = user;
    } catch (e) {
      // token قد يكون منتهي/غير صالح
      await logout(message: 'انتهت الجلسة أو التوكن غير صالح.');
    } finally {
      booting.value = false;
    }
  }

  Future<void> login({required String username, required String password}) async {
    loggingIn.value = true;
    error.value = null;
    try {
      final tokens = await _authService.staffLogin(username: username, password: password);
      final accessToken = tokens['access_token']!;
      final refreshToken = tokens['refresh_token']!;
      
      token.value = accessToken;
      ApiClient.instance.setToken(accessToken);
      await _storage.writeTokens(accessToken, refreshToken);

      final user = await _authService.me();
      if (!user.isAdmin) {
        await logout(message: 'تم تسجيل الدخول لكن الحساب ليس مدير (admin).');
        return;
      }
      me.value = user;
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      loggingIn.value = false;
    }
  }

  Future<void> logout({String? message}) async {
    await _storage.clearToken();
    ApiClient.instance.setToken(null);
    token.value = null;
    me.value = null;
    error.value = message;
  }
}


