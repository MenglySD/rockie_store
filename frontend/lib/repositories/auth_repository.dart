import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/models/user.dart';
import 'package:rockie_store/services/api_client.dart';

class AuthResult {
  final String token;
  final User user;
  const AuthResult(this.token, this.user);
}

class AuthRepository {
  final ApiClient _api;
  AuthRepository(this._api);

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    Gender? gender,
  }) async {
    final body = await _api.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'gender': gender?.value,
      'device_name': 'flutter-app',
    });
    return _saveToken(body);
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final body = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
      'device_name': 'flutter-app',
    });
    return _saveToken(body);
  }

  /// Google/Facebook: exchange a Firebase ID token for a Sanctum token.
  Future<AuthResult> loginWithFirebase(String idToken) async {
    final body = await _api.post('/auth/firebase', data: {
      'id_token': idToken,
      'device_name': 'flutter-app',
    });
    return _saveToken(body);
  }

  /// Revokes this device's token on the server, then forgets it locally.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } finally {
      await _api.tokens.clear();
    }
  }

  Future<bool> hasToken() async => (await _api.tokens.read()) != null;

  Future<void> clearToken() => _api.tokens.clear();

  // ---- Forgot password (OTP) ----

  Future<String> forgotPassword(String email) async {
    final body = await _api.post('/auth/forgot-password', data: {'email': email});
    return asString(asMap(body)['message']);
  }

  /// Returns the short-lived reset token.
  Future<String> verifyOtp({required String email, required String otp}) async {
    final body = await _api.post('/auth/verify-otp', data: {'email': email, 'otp': otp});
    return asString(asMap(asMap(body)['data'])['reset_token']);
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _api.post('/auth/reset-password', data: {
      'email': email,
      'reset_token': resetToken,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  Future<AuthResult> _saveToken(dynamic body) async {
    final data = asMap(asMap(body)['data']);
    final token = asString(data['token']);
    await _api.tokens.write(token);
    return AuthResult(token, User.fromJson(asMap(data['user'])));
  }
}
