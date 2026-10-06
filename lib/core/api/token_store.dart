import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Jetons JWT conservés dans le stockage sécurisé du téléphone.
class TokenStore {
  static const _access = 'access_token';
  static const _refresh = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? accessToken;
  String? refreshToken;

  Future<void> load() async {
    accessToken = await _storage.read(key: _access);
    refreshToken = await _storage.read(key: _refresh);
  }

  Future<void> save(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    await _storage.write(key: _access, value: access);
    await _storage.write(key: _refresh, value: refresh);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }

  bool get hasTokens => accessToken != null && refreshToken != null;
}
