import 'package:flutter/material.dart';

import 'package:dev_mobile/app/shells.dart';
import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/utilisateurs/screens/login_screen.dart';

/// ÉCRAN TEMPORAIRE pour le développement.
/// Permet à chacun d'ouvrir l'espace admin ou client sans connexion.
/// Le module Utilisateurs le remplacera par un AuthGate (redirection selon le rôle).
class DevLauncher extends StatelessWidget {
  const DevLauncher({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Mode développement'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Choisir un espace', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => _open(context, const AdminShell()),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Espace Admin'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _open(context, const ClientShell()),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Espace Client'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _open(
              context,
              LoginScreen(
                onLoggedIn: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AdminShell()),
                ),
              ),
            ),
            icon: const Icon(Icons.login),
            label: const Text('Écran de connexion'),
          ),
        ],
      ),
    );
  }
}
