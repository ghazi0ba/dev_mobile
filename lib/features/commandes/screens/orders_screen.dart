import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

/// Écran d'entrée du module Commandes.
/// Remplacez le contenu de [body] par vos propres écrans.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppHeader(subtitle: 'Commandes'),
      body: ModulePlaceholder(
        module: 'Commandes',
        icon: Icons.receipt_long_outlined,
        todo: [
          'Client : passer commande à partir du panier (paiement à la livraison)',
          'Client : historique et détail de ses commandes',
          'Admin : liste de toutes les commandes, filtre par statut',
          'Admin : changer le statut (en attente → confirmée → expédiée → livrée)',
          'Décrémenter le stock dans une transaction Firestore',
        ],
      ),
    );
  }
}
