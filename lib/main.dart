import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/shells.dart';
import 'core/theme/app_theme.dart';
import 'features/utilisateurs/screens/login_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CosmaPlusApp());
}

class CosmaPlusApp extends StatelessWidget {
  const CosmaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CosmaPlus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Always start with login screen
      home: const _LoginWrapper(),
    );
  }
}

/// Wrapper to properly handle navigation after login
class _LoginWrapper extends StatelessWidget {
  const _LoginWrapper();

  @override
  Widget build(BuildContext context) {
    return LoginScreen(
      onLoggedIn: () {
        // Navigate to admin shell after successful login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminShell()),
        );
      },
    );
  }
}
