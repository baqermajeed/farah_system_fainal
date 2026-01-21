import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _kTokenKey = 'access_token';
  static const _kRefreshTokenKey = 'refresh_token';

  Future<String?> readToken() => _storage.read(key: _kTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshTokenKey);

  Future<void> writeToken(String token) => _storage.write(key: _kTokenKey, value: token);

  Future<void> writeRefreshToken(String refreshToken) => _storage.write(key: _kRefreshTokenKey, value: refreshToken);

  Future<void> writeTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _kTokenKey, value: accessToken);
    await _storage.write(key: _kRefreshTokenKey, value: refreshToken);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _kTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
  }
}


