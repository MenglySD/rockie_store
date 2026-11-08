import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/provider/app_provider.dart';
import 'package:rockie_store/provider/auth_provider.dart';
import 'package:rockie_store/provider/cart_provider.dart';
import 'package:rockie_store/provider/home_provider.dart';
import 'package:rockie_store/screen/home_screen.dart';
import 'package:rockie_store/screen/login_screen.dart';

/// After login/register: load the cart and open the home screen.
void openHome(BuildContext context) {
  context.read<HomeProvider>().onTap(0);
  context.read<CartProvider>().load();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (route) => false,
  );
}

/// Logout button: revoke the token, sign out of Firebase/Google/Facebook,
/// clear the cart and go to the login screen.
Future<void> logout(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final cart = context.read<CartProvider>();
  final home = context.read<HomeProvider>();
  final navigator = Navigator.of(context);

  await auth.logout();
  cart.clear();
  home.onTap(0);
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

bool _handlingExpiry = false;

/// Wired to [ApiClient.onUnauthorized]: any 401 on an authenticated request
/// clears the token and sends the user to login once.
Future<void> handleSessionExpired() async {
  final context = navigatorKey.currentContext;
  if (_handlingExpiry || context == null) return;
  final auth = context.read<AuthProvider>();
  if (!auth.isSignedIn) return;

  _handlingExpiry = true;
  try {
    final cart = context.read<CartProvider>();
    final home = context.read<HomeProvider>();
    await auth.clearSession();
    cart.clear();
    home.onTap(0);
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    final messenger = navigatorKey.currentContext == null
        ? null
        : ScaffoldMessenger.maybeOf(navigatorKey.currentContext!);
    messenger?.showSnackBar(
      const SnackBar(content: Text('Your session has expired. Please log in again.')),
    );
  } finally {
    _handlingExpiry = false;
  }
}
