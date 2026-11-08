import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/api_ui.dart';
import 'package:rockie_store/helpers/session.dart';
import 'package:rockie_store/provider/auth_provider.dart';
import 'package:rockie_store/screen/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isScaleUp = false;
  Timer? _startTimer;

  /// Set when the server could not be reached while checking the saved token.
  Object? _error;

  @override
  void initState() {
    super.initState();
    _startTimer = Timer(const Duration(milliseconds: 500), _startAnimation);
  }

  void _startAnimation() {
    if (!mounted) return;
    setState(() => _isScaleUp = true);
    _restoreSession();
  }

  /// Saved token → GET /me → home. No token or 401 → login.
  Future<void> _restoreSession() async {
    setState(() => _error = null);
    try {
      // Keep the splash visible for at least 2 seconds, as before.
      final minimumDelay = Future<void>.delayed(const Duration(seconds: 2));
      final status = await context.read<AuthProvider>().restoreSession();
      await minimumDelay;
      if (!mounted) return;
      if (status == SessionStatus.signedIn) {
        openHome(context);
      } else {
        _openLogin();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _openLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image - fills the entire screen
          Positioned.fill(
            child: Image.asset('assets/images/bgSplash.jpg', fit: BoxFit.cover),
          ),

          // Logo + text in the center
          Positioned(
            top: 250,
            left: 50,
            right: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: _isScaleUp ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  child: Image.asset(
                    'assets/images/logo.png',
                    // width: 250,
                    height: 70,
                    // fit: BoxFit.contain,
                  ),
                ),

                SizedBox(height: 12),

                Text(
                  'Shop Everything',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 18,
                    // fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'You Love',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontSize: 14,
                    // fontWeight: FontWeight.bold,
                  ),
                ),

              //loading
                SizedBox(height: 170),
                if (_error == null) ...[
                  CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ] else ...[
                  Text(
                    errorMessage(_error!),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                  SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _restoreSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: BorderSide(color: Colors.deepOrange),
                    ),
                    child: Text('Retry'),
                  ),
                ],

                
              ],
            ),
          ),
        ],
      ),
    );
  }
}
