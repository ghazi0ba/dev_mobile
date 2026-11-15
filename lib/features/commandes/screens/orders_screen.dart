import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';

import 'admin_orders_screen.dart';
import 'my_orders_screen.dart';

/// Onglet "Commandes" : vue admin (toutes les commandes) ou client (les siennes).
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = CurrentUser.maybeOf(context);
    if (user == null) {
      // "Mode développement" sans connexion.
      return const Scaffold(
        appBar: AppHeader(subtitle: 'Commandes'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Connectez-vous pour voir les commandes.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return user.isAdmin ? const AdminOrdersScreen() : const MyOrdersScreen();
  }
}
