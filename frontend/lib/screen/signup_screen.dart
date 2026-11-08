import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/session.dart';
import 'package:rockie_store/models/user.dart';
import 'package:rockie_store/provider/auth_provider.dart';
import 'package:rockie_store/screen/login_screen.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _serverErrors = ServerErrors();
  Gender? _gender;
  bool _acceptTerms = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _isSigningUp = false;

  /// After the first "Sign Up" tap, errors update as the user types.
  bool _submitted = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_isSigningUp) return;
    _serverErrors.clear();
    setState(() => _submitted = true);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !_acceptTerms) {
      if (!_acceptTerms) {
        showMessage(context, 'Please accept the Terms and Conditions.');
      }
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSigningUp = true);
    try {
      // POST /auth/register → the token is stored securely by the repository.
      await context.read<AuthProvider>().register(
        name: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
        gender: _gender,
      );
      if (mounted) openHome(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      final shownUnderField = error.isValidation &&
          _serverErrors.apply(
            error,
            _formKey,
            fields: const ['name', 'email', 'password', 'gender'],
          );
      if (!shownUnderField) showApiError(context, error, onRetry: _signUp);
    } finally {
      if (mounted) {
        setState(() => _isSigningUp = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB5B5B5), fontSize: 14),
      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF707070)),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
    );
  }

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF303030),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 110),
                    Image.asset('assets/images/logo.png', height: 44),
                    const SizedBox(height: 16),
                    const Text(
                      'Create an account to start shopping.',
                      style: TextStyle(color: Color(0xFF333333), fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 408),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDCE5FF)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x16000000),
                            blurRadius: 15,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _label('Full Name'),
                            TextFormField(
                              controller: _fullNameController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                hint: 'Name',
                                icon: Icons.person_outline,
                              ),
                              onChanged: (_) => _serverErrors.clear('name'),
                              validator: (value) =>
                                  _serverErrors.of('name') ??
                                  (value == null || value.trim().isEmpty
                                      ? 'Enter your full name'
                                      : value.trim().length > 255
                                      ? 'Name is too long'
                                      : null),
                            ),
                            const SizedBox(height: 16),
                            _label('Email Address'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                hint: 'Email',
                                icon: Icons.email_outlined,
                              ),
                              onChanged: (_) => _serverErrors.clear('email'),
                              validator: (value) {
                                final serverError = _serverErrors.of('email');
                                if (serverError != null) return serverError;
                                final email = value?.trim() ?? '';
                                if (!RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(email)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _label('Password'),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                hint: 'Password',
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFFD3D3D3),
                                  ),
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                ),
                              ),
                              onChanged: (_) => _serverErrors.clear('password'),
                              validator: (value) =>
                                  _serverErrors.of('password') ??
                                  (value == null || value.length < 8
                                      ? 'Use at least 8 characters'
                                      : null),
                            ),
                            const SizedBox(height: 16),
                            _label('Confirm Password'),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _hideConfirmation,
                              onFieldSubmitted: (_) => _signUp(),
                              decoration: _inputDecoration(
                                hint: 'Password',
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _hideConfirmation
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFFD3D3D3),
                                  ),
                                  onPressed: () => setState(
                                    () =>
                                        _hideConfirmation = !_hideConfirmation,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value != _passwordController.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _label('Gender (optional)'),
                            DropdownButtonFormField<Gender>(
                              initialValue: _gender,
                              decoration: _inputDecoration(
                                hint: 'Select gender',
                                icon: Icons.wc_outlined,
                              ),
                              items: Gender.values
                                  .map(
                                    (gender) => DropdownMenuItem(
                                      value: gender,
                                      child: Text(gender.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isSigningUp
                                  ? null
                                  : (value) => setState(() {
                                      _gender = value;
                                      _serverErrors.clear('gender');
                                    }),
                              validator: (_) => _serverErrors.of('gender'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _acceptTerms,
                                    activeColor: mainColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFD9D9D9),
                                    ),
                                    onChanged: (value) => setState(
                                      () => _acceptTerms = value ?? false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'I agree to the ',
                                  style: TextStyle(fontSize: 12),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    foregroundColor: mainColor,
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Terms and Conditions',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isSigningUp ? null : _signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isSigningUp
                                    ? const ButtonSpinner()
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Sign Up',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward, size: 18),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account? ',
                                  style: TextStyle(fontSize: 12),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
                                        ),
                                      ),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: mainColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
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
