import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/dev_launcher.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      // TODO(module Utilisateurs) : remplacer DevLauncher par l'AuthGate.
      home: const DevLauncher(),
    );
  }
}
