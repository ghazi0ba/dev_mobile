import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';
import 'package:dev_mobile/shared/models/models.dart';

/// Tableau de bord admin (maquette "Accueil").
/// Écran de référence : montre comment utiliser le thème et les composants.
/// Le message d'accueil utilise le prénom de l'utilisateur connecté.
/// Les chiffres sont des exemples ; ils seront branchés sur Firestore plus tard.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// "Bonjour Nadia," le jour, "Bonsoir Nadia," à partir de 18 h.
  static String _greeting(AppUser? user) {
    final hello = DateTime.now().hour >= 18 ? 'Bonsoir' : 'Bonjour';
    final name = user?.firstName.trim() ?? '';
    return name.isEmpty ? '$hello,' : '$hello $name,';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Accueil'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _greeting(CurrentUser.maybeOf(context)),
                            style: text.headlineSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(Icons.auto_awesome,
                            size: 18, color: AppColors.accent),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Voici un aperçu de votre stock aujourd\'hui.',
                        style: text.bodyMedium),
                  ],
                ),
              ),
              const StatusBadge('BOUTIQUE ACTIVE',
                  tone: BadgeTone.success, showDot: true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _HeroBanner(),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm + 4,
            crossAxisSpacing: AppSpacing.sm + 4,
            childAspectRatio: 1.35,
            children: const [
              StatCard(
                label: 'Produits',
                value: '128',
                icon: Icons.spa_outlined,
                badge: StatusBadge('+4 ce mois', tone: BadgeTone.success),
              ),
              StatCard(
                label: 'Stock disponible',
                value: '846',
                icon: Icons.inventory_2_outlined,
                iconBackground: AppColors.successLight,
                badge: StatusBadge('Unités'),
              ),
              StatCard(
                label: 'Catégories',
                value: '12',
                icon: Icons.category_outlined,
                iconBackground: AppColors.secondary,
                badge: StatusBadge('Rayons'),
              ),
              StatCard(
                label: 'Marques',
                value: '8',
                icon: Icons.verified_outlined,
                badge: StatusBadge('Partenaires', tone: BadgeTone.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: Container(
        height: 170,
        // Remplacer par une image : DecorationImage(image: AssetImage(...), fit: BoxFit.cover)
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFD9C7B8), AppColors.primaryDark],
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CATALOGUE OFFICINAL',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.accent),
            ),
            Text('Aura Botanica Écrin',
                style: AppTheme.serif(size: 22, color: Colors.white)),
            const Text(
              'Gamme fraîchement certifiée Bio',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
