import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/helpers/session.dart';
import 'package:rockie_store/provider/app_provider.dart';
import 'package:rockie_store/firebase_options.dart';
import 'package:rockie_store/screen/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Any 401 on an authenticated request → clear the token and show login.
  apiClient.onUnauthorized = handleSessionExpired;

  runApp(MultiProvider(providers: providers, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rockie Store',
      navigatorKey: navigatorKey,
      home: SplashScreen(),
      theme: ThemeData(fontFamily: 'Poppins'),
    );
  }
}
