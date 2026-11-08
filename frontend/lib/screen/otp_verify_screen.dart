import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/repositories/auth_repository.dart';
import 'package:rockie_store/screen/new_password_screen.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// Step 2 of 3: enter the 6-digit code → POST /auth/verify-otp → reset_token.
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key, required this.email});

  final String email;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  static const _length = 6;
  static const _resendSeconds = 60;

  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _focusNodes = List.generate(_length, (_) => FocusNode());

  bool _verifying = false;
  bool _resending = false;
  String? _error;
  int _secondsLeft = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  String get _code => _controllers.map((controller) => controller.text).join();

  void _onChanged(String value, int index) {
    if (_error != null) setState(() => _error = null);

    // Typing into a box that already has a digit: keep only the new digit.
    if (value.length == 2) {
      final digit = value.characters.last;
      _controllers[index].value = TextEditingValue(
        text: digit,
        selection: const TextSelection.collapsed(offset: 1),
      );
      value = digit;
    }

    // Paste (or autofill) of several digits into one box.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '').characters.take(_length).toList();
      for (var i = 0; i < _length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      if (digits.length == _length) {
        _focusNodes[_length - 1].unfocus();
        _verify();
      } else {
        _focusNodes[digits.length].requestFocus();
      }
      return;
    }
    if (value.isNotEmpty && index < _length - 1) _focusNodes[index + 1].requestFocus();
    if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
    if (_code.length == _length) {
      FocusScope.of(context).unfocus();
      _verify();
    }
  }

  void _clearCode() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final code = _code;
    if (code.length != _length) {
      setState(() => _error = 'Please enter the 6-digit verification code.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final resetToken = await context.read<AuthRepository>().verifyOtp(
        email: widget.email,
        otp: code,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NewPasswordScreen(email: widget.email, resetToken: resetToken),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isValidation || error.type == ApiErrorType.rateLimited) {
        // Wrong code, expired code or too many attempts.
        setState(() => _error = error.fieldError('otp') ?? error.message);
        _clearCode();
      } else {
        showApiError(context, error, onRetry: _verify);
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _secondsLeft > 0) return;
    setState(() => _resending = true);
    try {
      await context.read<AuthRepository>().forgotPassword(widget.email);
      if (!mounted) return;
      _clearCode();
      setState(() => _error = null);
      _startCountdown();
      showMessage(context, 'If this email exists, we sent a new code.');
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error, onRetry: _resend);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _countdownLabel =>
      '00:${_secondsLeft.clamp(0, 59).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0 && !_resending;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: const Color(0xFFFAF8FF),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: Color(0xFFFFD8D0), shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_unread_rounded, color: mainColor, size: 30),
              ),
              const SizedBox(height: 23),
              const Text(
                'Verification Code',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter the 6-digit code sent to your email',
                style: TextStyle(fontSize: 14, color: mainColor),
              ),
              Text(widget.email, style: const TextStyle(fontSize: 14, color: Color(0xFF172033))),
              const SizedBox(height: 40),
              AutofillGroup(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(right: index == _length - 1 ? 0 : 8),
                      child: SizedBox(
                        width: 46,
                        height: 58,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          autofocus: index == 0,
                          enabled: !_verifying,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          // Allow a full code so pasting into any box works.
                          maxLength: _length,
                          autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                          onChanged: (value) => _onChanged(value, index),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFE7E7E7),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: _error == null
                                  ? BorderSide.none
                                  : const BorderSide(color: Colors.red),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(color: Color(0xFF246BFD), width: 2),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 49,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  child: _verifying
                      ? const ButtonSpinner()
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text('Verify'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 20)],
                        ),
                ),
              ),
              const SizedBox(height: 66),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive the code? ", style: TextStyle(color: mainColor)),
                  TextButton(
                    onPressed: canResend ? _resend : null,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text(
                      _resending
                          ? 'Sending...'
                          : _secondsLeft > 0
                          ? 'Resend Code ($_countdownLabel)'
                          : 'Resend Code',
                      style: TextStyle(
                        color: canResend ? mainColor : const Color(0xFFFF8A70),
                        fontWeight: canResend ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
