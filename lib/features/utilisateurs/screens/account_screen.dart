import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

/// Écran d'entrée du module Utilisateurs.
/// Remplacez le contenu de [body] par vos propres écrans.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppHeader(subtitle: 'Menu'),
      body: ModulePlaceholder(
        module: 'Utilisateurs',
        icon: Icons.person_outline,
        todo: [
          'Inscription / connexion avec Firebase Auth (LoginScreen est prêt côté design)',
          'Créer le document users/{uid} à l\'inscription (rôle client par défaut)',
          'AuthGate : rediriger vers l\'espace admin ou client selon le rôle',
          'Écran Menu/Profil : infos, modification, déconnexion',
          'Admin : liste des utilisateurs et gestion des rôles',
        ],
      ),
    );
  }
}
