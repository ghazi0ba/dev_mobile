import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

/// Écran d'entrée du module Produits.
/// Remplacez le contenu de [body] par vos propres écrans.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppHeader(subtitle: 'Produits'),
      body: ModulePlaceholder(
        module: 'Produits',
        icon: Icons.inventory_2_outlined,
        todo: [
          'Liste des produits avec recherche et filtres (catégorie, prix, stock, labels)',
          'Fiche produit (détail)',
          'Admin : ajouter / modifier / supprimer un produit (showConfirmDialog)',
          'Admin : gestion des catégories',
          'Ajuster le stock',
        ],
      ),
    );
  }
}
