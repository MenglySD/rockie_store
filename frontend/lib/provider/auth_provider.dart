import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rockie_store/models/user.dart';
import 'package:rockie_store/repositories/auth_repository.dart';
import 'package:rockie_store/repositories/profile_repository.dart';
import 'package:rockie_store/services/api_exception.dart';

enum SessionStatus { signedIn, signedOut }

/// Holds the signed-in Laravel user. Email/password goes to Laravel only;
/// Firebase is used just to obtain Google/Facebook ID tokens.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _auth;
  final ProfileRepository _profile;

  AuthProvider(this._auth, this._profile);

  User? _user;
  User? get user => _user;
  bool get isSignedIn => _user != null;

  /// On app start: valid token → signed in; no token or 401 → signed out.
  /// Network errors are rethrown so the splash screen can offer a retry.
  Future<SessionStatus> restoreSession() async {
    if (!await _auth.hasToken()) return SessionStatus.signedOut;
    try {
      _user = await _profile.me();
      notifyListeners();
      return SessionStatus.signedIn;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await clearSession();
        return SessionStatus.signedOut;
      }
      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _auth.login(email: email.trim(), password: password);
    _setUser(result.user);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    Gender? gender,
  }) async {
    final result = await _auth.register(
      name: name.trim(),
      email: email.trim(),
      password: password,
      passwordConfirmation: passwordConfirmation,
      gender: gender,
    );
    _setUser(result.user);
  }

  /// After a successful Firebase Google/Facebook sign-in.
  Future<void> loginWithFirebaseUser(firebase.User firebaseUser) async {
    final idToken = await firebaseUser.getIdToken(true);
    if (idToken == null) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Could not get a sign-in token from Firebase. Please try again.',
      );
    }
    try {
      final result = await _auth.loginWithFirebase(idToken);
      _setUser(result.user);
    } catch (_) {
      // Don't leave a Firebase session without a Laravel session.
      await _signOutSocial();
      rethrow;
    }
  }

  Future<void> refreshUser() async => _setUser(await _profile.me());

  Future<void> updateProfile({required String name, Gender? gender}) async {
    _setUser(await _profile.update(name: name, gender: gender));
  }

  Future<void> updateAvatar(List<int> bytes, String filename) async {
    _setUser(await _profile.uploadAvatar(bytes, filename));
  }

  Future<void> removeAvatar() async {
    _setUser(await _profile.removeAvatar());
  }

  Future<void> changePassword({
    String? currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _profile.changePassword(
      currentPassword: currentPassword,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  /// Revokes the API token (best effort), forgets it, and signs out of
  /// Firebase/Google/Facebook so the next login starts clean.
  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (_) {
      // Offline or token already invalid: the local token is cleared anyway.
      await _auth.clearToken();
    }
    await _signOutSocial();
    _user = null;
    notifyListeners();
  }

  /// Called when the server rejects the token (401).
  Future<void> clearSession() async {
    await _auth.clearToken();
    await _signOutSocial();
    _user = null;
    notifyListeners();
  }

  void _setUser(User user) {
    _user = user;
    notifyListeners();
  }

  Future<void> _signOutSocial() async {
    try {
      await firebase.FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      try {
        await FacebookAuth.instance.logOut();
      } catch (_) {}
    }
  }
}
