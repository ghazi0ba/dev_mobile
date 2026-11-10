import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

/// Écran d'entrée du module Panier.
/// Remplacez le contenu de [body] par vos propres écrans.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppHeader(subtitle: 'Panier'),
      body: ModulePlaceholder(
        module: 'Panier',
        icon: Icons.shopping_bag_outlined,
        todo: [
          'Ajouter un produit au panier (bouton à fournir au module Produits)',
          'Modifier la quantité, supprimer un article',
          'Calcul du total (prix relus depuis products)',
          'Vérifier le stock disponible',
          'Bouton « Commander » → module Commandes',
        ],
      ),
    );
  }
}
