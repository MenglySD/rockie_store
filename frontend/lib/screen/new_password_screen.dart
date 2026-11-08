import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/repositories/auth_repository.dart';
import 'package:rockie_store/screen/login_screen.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// Step 3 of 3: new password → POST /auth/reset-password → login screen.
class NewPasswordScreen extends StatefulWidget {
  final String email;
  final String resetToken;

  const NewPasswordScreen({
    super.key,
    required this.email,
    required this.resetToken,
  });

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _serverErrors = ServerErrors();
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _saving = false;

  /// After the first "Update Password" tap, errors update as the user types.
  bool _submitted = false;

  bool get _longEnough => _passwordController.text.length >= 8;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_saving) return;
    _serverErrors.clear();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await context.read<AuthRepository>().resetPassword(
        email: widget.email,
        resetToken: widget.resetToken,
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: mainColor, size: 44),
          title: const Text('Password updated'),
          content: const Text(
            'Your password has been reset. Please log in with your new password.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Go to login'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      final shown =
          error.isValidation &&
          _serverErrors.apply(error, _formKey, fields: const ['password']);
      if (!shown) {
        // e.g. reset_token expired: the user has to request a new code.
        showApiError(context, error, onRetry: _updatePassword);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// A requirement line that turns green with a check once it is met.
  Widget _requirement(String text, bool met) {
    final color = met ? const Color(0xFF2E9E5B) : const Color(0xFF6B6B6B);
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    );
  }

  InputDecoration _decoration(String hint, bool hidden, VoidCallback onTap) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB6BBC4)),
      filled: true,
      fillColor: const Color(0xFFF0F3F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: IconButton(
        tooltip: hidden ? 'Show password' : 'Hide password',
        onPressed: onTap,
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        color: const Color(0xFFB5B7BA),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9FF),
      body: SafeArea(
        // Scrolls when the keyboard is open or the screen is short; otherwise
        // the card stays centred.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                // Back button at the top, card in the middle.
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.fromLTRB(24, 25, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x160B0B0B),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _submitted
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'Create New Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF172033),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your new password must be different from\npreviously used passwords.',
                            textAlign: TextAlign.center,
                            style: TextStyle(height: 1.45),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'New Password',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _hidePassword,
                            enabled: !_saving,
                            onChanged: (_) =>
                                setState(() => _serverErrors.clear('password')),
                            decoration: _decoration(
                              'Enter new password',
                              _hidePassword,
                              () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                            ),
                            validator: (value) {
                              final serverError = _serverErrors.of('password');
                              if (serverError != null) return serverError;
                              if ((value ?? '').length < 8) {
                                return 'Password must contain at least 8 characters.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Confirm New Password',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _hideConfirmation,
                            enabled: !_saving,
                            onChanged: (_) => setState(() {}),
                            onFieldSubmitted: (_) => _updatePassword(),
                            decoration: _decoration(
                              'Confirm new password',
                              _hideConfirmation,
                              () => setState(
                                () => _hideConfirmation = !_hideConfirmation,
                              ),
                            ),
                            validator: (value) =>
                                value != _passwordController.text
                                ? 'Passwords do not match.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F3FF),
                              border: Border.all(
                                color: const Color(0xFFE4DCEA),
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Password Requirements:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _requirement(
                                  'At least 8 characters long',
                                  _longEnough,
                                ),
                                const SizedBox(height: 3),
                                _requirement(
                                  'Both passwords match',
                                  _confirmPasswordController.text.isNotEmpty &&
                                      _confirmPasswordController.text ==
                                          _passwordController.text,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _updatePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _saving
                                  ? const ButtonSpinner()
                                  : const Text(
                                      'Update Password',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
