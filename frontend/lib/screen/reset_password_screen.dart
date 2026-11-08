import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/repositories/auth_repository.dart';
import 'package:rockie_store/screen/otp_verify_screen.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// Step 1 of 3: enter email → POST /auth/forgot-password.
class ResetPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ResetPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _serverErrors = ServerErrors();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_sending) return;
    _serverErrors.clear();
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    final email = _emailController.text.trim();
    try {
      await context.read<AuthRepository>().forgotPassword(email);
      if (!mounted) return;
      // Same message whether or not the account exists.
      showMessage(context, 'If this email exists, we sent a code.');
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: email)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      final shown = error.isValidation &&
          _serverErrors.apply(error, _formKey, fields: const ['email']);
      if (!shown) showApiError(context, error, onRetry: _sendCode);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: const Color(0xFFF9F7FF),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: const Color(0xFF4C4545),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: mainColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Reset Password',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Enter your email address and we'll send you a\n6-digit code to reset your password.",
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Color(0xFF36333A),
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        'Email Address',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        enabled: !_sending,
                        onChanged: (_) => _serverErrors.clear('email'),
                        onFieldSubmitted: (_) => _sendCode(),
                        validator: (value) {
                          final serverError = _serverErrors.of('email');
                          if (serverError != null) return serverError;
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Please enter your email address.';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'email',
                          hintStyle: const TextStyle(color: Color(0xFFB2B2B2)),
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _sending ? null : _sendCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: mainColor.withValues(alpha: .35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _sending
                              ? const ButtonSpinner()
                              : const Text(
                                  'Send Code →',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
