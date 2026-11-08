import 'package:dio/dio.dart';
import 'package:rockie_store/models/json.dart';
import 'package:rockie_store/models/user.dart';
import 'package:rockie_store/services/api_client.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  Future<User> me() async {
    final body = await _api.get('/me');
    return User.fromJson(asMap(asMap(body)['data']));
  }

  Future<User> update({required String name, Gender? gender}) async {
    final body = await _api.patch('/me', data: {
      'name': name,
      'gender': gender?.value,
    });
    return User.fromJson(asMap(asMap(body)['data']));
  }

  /// Uploads a new profile photo (JPG, PNG or WebP, up to 5 MB).
  Future<User> uploadAvatar(List<int> bytes, String filename) async {
    final body = await _api.post('/me/avatar', data: FormData.fromMap({
      'avatar': MultipartFile.fromBytes(bytes, filename: filename),
    }));
    return User.fromJson(asMap(asMap(body)['data']));
  }

  Future<User> removeAvatar() async {
    final body = await _api.delete('/me/avatar');
    return User.fromJson(asMap(asMap(body)['data']));
  }

  Future<void> changePassword({
    String? currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _api.post('/me/change-password', data: {
      'current_password': ?currentPassword,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  /// Contact form. Works signed in or as a guest.
  Future<void> sendSupportMessage({
    required String name,
    required String email,
    String? subject,
    required String message,
  }) async {
    await _api.post('/support/messages', data: {
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
    });
  }
}
