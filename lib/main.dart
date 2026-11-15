import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/utilisateurs/screens/auth_gate.dart';
import 'features/utilisateurs/widgets/current_user_scope.dart';
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
    // SessionScope au-dessus de MaterialApp : CurrentUser.of(context)
    // fonctionne dans tous les écrans, y compris ceux ouverts avec push().
    return SessionScope(
      child: MaterialApp(
        title: 'CosmaPlus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Connexion → espace admin ou client selon le rôle.
        // En debug, l'écran de connexion propose aussi le "Mode développement".
        home: const AuthGate(),
      ),
    );
  }
}
