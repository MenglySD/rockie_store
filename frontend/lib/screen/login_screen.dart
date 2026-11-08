import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/session.dart';
import 'package:rockie_store/provider/auth_provider.dart';
import 'package:rockie_store/screen/signup_screen.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';
import 'package:rockie_store/screen/reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverErrors = ServerErrors();
  bool _isPasswordHidden = true;
  bool _isGoogleSigningIn = false;
  bool _isFacebookSigningIn = false;
  bool _isSigningIn = false;
  bool _googleSignInInitialized = false;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool get _isBusy => _isSigningIn || _isGoogleSigningIn || _isFacebookSigningIn;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeFacebookRedirectSignIn();
      });
    }
  }

  Future<void> _completeFacebookRedirectSignIn() async {
    try {
      final result = await FirebaseAuth.instance.getRedirectResult();
      if (result.user != null) await _exchangeFirebaseUser(result.user!);
    } on FirebaseAuthException catch (error) {
      _showFacebookSignInError(
        'Facebook sign-in failed (${error.code}): '
        '${error.message ?? 'Please check your Facebook and Firebase configuration.'}',
      );
    } on ApiException catch (error) {
      _showFacebookSignInError(error.message);
    } on Exception catch (error) {
      _showFacebookSignInError('Facebook sign-in failed: $error');
    }
  }

  /// Sends the Firebase ID token to Laravel and stores the returned API token.
  Future<void> _exchangeFirebaseUser(User user) async {
    await context.read<AuthProvider>().loginWithFirebaseUser(user);
    if (mounted) openHome(context);
  }

  /// Email/password goes only to Laravel (POST /auth/login).
  Future<void> _signInWithEmailAndPassword() async {
    if (_isBusy) return;
    _serverErrors.clear();
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSigningIn = true);

    try {
      await context.read<AuthProvider>().login(
        email: _textController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) openHome(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      final shownUnderField = error.isValidation &&
          _serverErrors.apply(error, _formKey, fields: const ['email', 'password']);
      if (!shownUnderField) showApiError(context, error, onRetry: _signInWithEmailAndPassword);
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  void togglePassword() {
    setState(() {
      _isPasswordHidden = !_isPasswordHidden;
    });
  }

  Future<void> _signInWithGoogle() async {
    if (_isBusy) return;
    setState(() => _isGoogleSigningIn = true);

    try {
      UserCredential credentialResult;
      if (kIsWeb) {
        credentialResult = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        if (!_googleSignInInitialized) {
          await GoogleSignIn.instance.initialize();
          _googleSignInInitialized = true;
        }

        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null) {
          throw FirebaseAuthException(
            code: 'missing-google-id-token',
            message: 'Google sign-in did not return an ID token.',
          );
        }

        final credential = GoogleAuthProvider.credential(idToken: idToken);
        credentialResult = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      await _exchangeFirebaseUser(credentialResult.user!);
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _showGoogleSignInError(
          error.description ?? 'Google sign-in failed. Please try again.',
        );
      }
    } on FirebaseAuthException catch (error) {
      _showGoogleSignInError(
        error.message ?? 'Google sign-in failed. Please try again.',
      );
    } on ApiException catch (error) {
      _showGoogleSignInError(error.message);
    } on Exception catch (error) {
      _showGoogleSignInError('Google sign-in failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isGoogleSigningIn = false);
      }
    }
  }

  Future<void> _signInWithFacebook() async {
    if (_isBusy) return;
    setState(() => _isFacebookSigningIn = true);

    try {
      if (kIsWeb) {
        // Continues in _completeFacebookRedirectSignIn after the redirect.
        await FirebaseAuth.instance.signInWithRedirect(FacebookAuthProvider());
        return;
      }

      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
        loginTracking: LoginTracking.enabled,
      );

      if (result.status == LoginStatus.cancelled) return;
      if (result.status != LoginStatus.success) {
        throw FirebaseAuthException(
          code: 'facebook-sign-in-failed',
          message: result.message ?? 'Facebook sign-in failed. Please try again.',
        );
      }

      final accessToken = result.accessToken;
      if (accessToken == null) {
        throw FirebaseAuthException(
          code: 'missing-facebook-access-token',
          message: 'Facebook sign-in did not return an access token.',
        );
      }

      final credential = FacebookAuthProvider.credential(
        accessToken.tokenString,
      );
      final credentialResult = await FirebaseAuth.instance.signInWithCredential(credential);
      await _exchangeFirebaseUser(credentialResult.user!);
    } on FirebaseAuthException catch (error) {
      _showFacebookSignInError(
        'Facebook sign-in failed (${error.code}): '
        '${error.message ?? 'Please check your Facebook and Firebase configuration.'}',
      );
    } on ApiException catch (error) {
      _showFacebookSignInError(error.message);
    } on Exception catch (error) {
      _showFacebookSignInError('Facebook sign-in failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isFacebookSigningIn = false);
      }
    }
  }

  // Also logged (adb logcat / debug console) so setup problems can be read
  // after the snackbar is gone.
  void _showFacebookSignInError(String message) {
    debugPrint('[login] $message');
    showMessage(context, message);
  }

  void _showGoogleSignInError(String message) {
    debugPrint('[login] $message');
    showMessage(context, message);
  }

  @override
  void dispose() {
    _textController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image(
                      height: 50,
                      image: AssetImage('assets/images/logo.png'),
                    ),

                    SizedBox(height: 28),
                    Text(
                      'Welcome back!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),

                    SizedBox(height: 8),
                    SizedBox(height: 32),
                    Text('Email address'),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _textController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_isBusy,
                      onChanged: (_) => _serverErrors.clear('email'),
                      decoration: InputDecoration(
                        hintText: 'Enter your email address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        final serverError = _serverErrors.of('email');
                        if (serverError != null) return serverError;
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Please enter your email address.';
                        }
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 18),

                    Text('Password'),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isPasswordHidden,
                      textInputAction: TextInputAction.done,
                      enabled: !_isBusy,
                      onChanged: (_) => _serverErrors.clear('password'),
                      onFieldSubmitted: (_) => _signInWithEmailAndPassword(),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        suffixIcon: IconButton(
                          tooltip: _isPasswordHidden
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _isPasswordHidden
                                ? Icons.visibility_off
                                : Icons.visibility_outlined,
                          ),
                          onPressed: togglePassword,
                        ),
                      ),
                      validator: (value) =>
                          _serverErrors.of('password') ??
                          (value == null || value.isEmpty
                              ? 'Please enter your password.'
                              : null),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ResetPasswordScreen(
                                initialEmail: _textController.text.trim(),
                              ),
                            ),
                          );
                        },
                        child: Text('Forgot password?'),
                      ),
                    ),
                    SizedBox(height: 4),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isBusy ? null : _signInWithEmailAndPassword,
                        child: _isSigningIn
                            ? const ButtonSpinner()
                            : const Text('Login'),
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?"),
                        TextButton(
                          onPressed: _isBusy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => SignUpScreen()),
                                  );
                                },
                          child: Text('Register account'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR WITH',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1F2937),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isBusy ? null : _signInWithGoogle,
                        icon: Image.asset(
                          'assets/images/icon/google.png',
                          height: 24,
                          width: 24,
                        ),
                        label: _isGoogleSigningIn
                            ? const ButtonSpinner(color: mainColor)
                            : const Text('Log in with Google'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1877F2),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isBusy ? null : _signInWithFacebook,
                        icon: Image.asset(
                          'assets/images/icon/communication.png',
                          height: 24,
                          width: 24,
                        ),
                        label: _isFacebookSigningIn
                            ? const ButtonSpinner(color: Color(0xFF1877F2))
                            : const Text('Log in with Facebook'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
