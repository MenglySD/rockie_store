import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/provider/auth_provider.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// POST /me/change-password. Google/Facebook users without a password can
/// set one without entering a current password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverErrors = ServerErrors();
  final _currentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _hideCurrent = true;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _saving = false;

  /// After the first save tap, errors update as the user types.
  bool _submitted = false;

  @override
  void dispose() {
    _currentController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save(bool needsCurrent) async {
    if (_saving) return;
    _serverErrors.clear();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await context.read<AuthProvider>().changePassword(
        currentPassword: needsCurrent ? _currentController.text : null,
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
      );
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      showMessage(context, 'Your password has been changed. Other devices were signed out.');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      final shown = error.isValidation &&
          _serverErrors.apply(error, _formKey, fields: const ['current_password', 'password']);
      if (!shown) showApiError(context, error, onRetry: () => _save(needsCurrent));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required VoidCallback onToggle,
    String? field,
    required String? Function(String value) validate,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: hidden,
      enabled: !_saving,
      onChanged: field == null ? null : (_) => _serverErrors.clear(field),
      validator: (value) =>
          (field == null ? null : _serverErrors.of(field)) ?? validate(value ?? ''),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: hidden ? 'Show password' : 'Hide password',
          onPressed: onToggle,
          icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsCurrent = context.watch<AuthProvider>().user?.hasPassword ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          needsCurrent ? 'Change Password' : 'Set Password',
          style: const TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  if (needsCurrent) ...[
                    _passwordField(
                      controller: _currentController,
                      label: 'Current password',
                      hidden: _hideCurrent,
                      onToggle: () => setState(() => _hideCurrent = !_hideCurrent),
                      field: 'current_password',
                      validate: (value) =>
                          value.isEmpty ? 'Please enter your current password' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _passwordField(
                    controller: _passwordController,
                    label: 'New password',
                    hidden: _hidePassword,
                    onToggle: () => setState(() => _hidePassword = !_hidePassword),
                    field: 'password',
                    validate: (value) {
                      if (value.length < 8) return 'Use at least 8 characters';
                      if (needsCurrent && value == _currentController.text) {
                        return 'The new password must be different';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _passwordField(
                    controller: _confirmController,
                    label: 'Confirm new password',
                    hidden: _hideConfirm,
                    onToggle: () => setState(() => _hideConfirm = !_hideConfirm),
                    validate: (value) =>
                        value != _passwordController.text ? 'Passwords do not match' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(needsCurrent),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving ? const ButtonSpinner() : const Text('Save Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
