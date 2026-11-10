import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

/// Écran d'entrée du module Avis.
/// Remplacez le contenu de [body] par vos propres écrans.
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppHeader(subtitle: 'Avis'),
      body: ModulePlaceholder(
        module: 'Avis',
        icon: Icons.star_outline_rounded,
        todo: [
          'Widget « avis d\'un produit » à intégrer dans la fiche produit',
          'Client : laisser une note (1–5) et un commentaire',
          'Un seul avis par client et par produit',
          'Mettre à jour ratingAverage / ratingCount du produit',
          'Admin : modérer (supprimer) les avis',
        ],
      ),
    );
  }
}
