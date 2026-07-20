import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_constants.dart';

/// تخزين آمن للتوكنات فقط (مثل قريب).
/// بيانات المستخدم لا تُحفظ هنا — تبقى في ذاكرة AuthController.currentUser.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    try {
      await Future.wait([
        _storage.write(key: ApiConstants.tokenKey, value: accessToken),
        _storage.write(key: ApiConstants.refreshTokenKey, value: refreshToken),
      ]);
    } catch (e) {
      print('⚠️ Warning: Could not save tokens to storage: $e');
    }
  }

  Future<void> saveAccessToken(String accessToken) async {
    try {
      await _storage.write(key: ApiConstants.tokenKey, value: accessToken);
    } catch (e) {
      print('⚠️ Warning: Could not save access token to storage: $e');
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: ApiConstants.tokenKey);
    } catch (e) {
      print('⚠️ Warning: Could not read access token from storage: $e');
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: ApiConstants.refreshTokenKey);
    } catch (e) {
      print('⚠️ Warning: Could not read refresh token from storage: $e');
      return null;
    }
  }

  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: ApiConstants.tokenKey),
        _storage.delete(key: ApiConstants.refreshTokenKey),
      ]);
    } catch (e) {
      print('⚠️ Warning: Could not clear tokens from storage: $e');
    }
  }

  /// مسح التوكنات + معرف المريض النشط (جلسة فرح).
  Future<void> clearSession() async {
    try {
      await Future.wait([
        _storage.delete(key: ApiConstants.tokenKey),
        _storage.delete(key: ApiConstants.refreshTokenKey),
        _storage.delete(key: ApiConstants.activePatientIdKey),
      ]);
    } catch (e) {
      print('⚠️ Warning: Could not clear session from storage: $e');
    }
  }

  Future<bool> hasTokens() async {
    final access = await getAccessToken();
    return access != null && access.isNotEmpty;
  }

  Future<void> saveActivePatientId(String patientId) async {
    try {
      await _storage.write(
        key: ApiConstants.activePatientIdKey,
        value: patientId,
      );
    } catch (e) {
      print('⚠️ Warning: Could not save active patient id: $e');
    }
  }

  Future<String?> getActivePatientId() async {
    try {
      return await _storage.read(key: ApiConstants.activePatientIdKey);
    } catch (e) {
      print('⚠️ Warning: Could not read active patient id: $e');
      return null;
    }
  }
}
