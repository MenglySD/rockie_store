import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the Laravel Sanctum token in the platform keychain/keystore.
class TokenStorage {
  static const _key = 'api_token';
  final FlutterSecureStorage _storage;

  // Cached so the Dio interceptor does not hit the keystore on every request.
  String? _cached;
  bool _loaded = false;

  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> read() async {
    if (!_loaded) {
      _cached = await _storage.read(key: _key);
      _loaded = true;
    }
    return _cached;
  }

  Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}
