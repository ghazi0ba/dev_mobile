import 'package:flutter/material.dart';

import 'package:dev_mobile/app/shells.dart';
import 'package:dev_mobile/core/widgets/widgets.dart';

/// ÉCRAN TEMPORAIRE pour le développement.
/// Permet à chacun d'ouvrir l'espace admin ou client sans connexion.
/// Accessible en debug depuis l'écran de connexion ("Mode développement").
/// Sans connexion, Firestore refusera les lectures protégées par les règles :
/// pour tester avec des données, connectez-vous avec un compte de test.
class DevLauncher extends StatelessWidget {
  const DevLauncher({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Mode développement', showBack: true),
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
        ],
      ),
    );
  }
}
