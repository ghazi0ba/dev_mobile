import 'package:flutter/material.dart';

import 'package:dev_mobile/app/home_screen.dart';
import 'package:dev_mobile/features/avis/screens/reviews_screen.dart';
import 'package:dev_mobile/features/commandes/screens/orders_screen.dart';
import 'package:dev_mobile/features/panier/screens/cart_screen.dart';
import 'package:dev_mobile/features/produits/screens/products_screen.dart';
import 'package:dev_mobile/features/utilisateurs/screens/account_screen.dart';

/// Un onglet de la barre de navigation du bas.
class NavTab {
  const NavTab(this.label, this.icon, this.selectedIcon, this.screen);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}

/// Espace administrateur (gérant de la boutique).
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TabShell(tabs: [
      NavTab('Accueil', Icons.home_outlined, Icons.home, HomeScreen()),
      NavTab('Produits', Icons.inventory_2_outlined, Icons.inventory_2,
          ProductsScreen()),
      NavTab('Commandes', Icons.receipt_long_outlined, Icons.receipt_long,
          OrdersScreen()),
      NavTab('Avis', Icons.star_outline_rounded, Icons.star_rounded,
          ReviewsScreen()),
      NavTab('Menu', Icons.more_horiz, Icons.more_horiz, AccountScreen()),
    ]);
  }
}

/// Espace client (acheteur).
class ClientShell extends StatelessWidget {
  const ClientShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TabShell(tabs: [
      NavTab('Boutique', Icons.storefront_outlined, Icons.storefront,
          ProductsScreen()),
      NavTab('Panier', Icons.shopping_bag_outlined, Icons.shopping_bag,
          CartScreen()),
      NavTab('Commandes', Icons.receipt_long_outlined, Icons.receipt_long,
          OrdersScreen()),
      NavTab('Profil', Icons.person_outline, Icons.person, AccountScreen()),
    ]);
  }
}

class _TabShell extends StatefulWidget {
  const _TabShell({required this.tabs});
  final List<NavTab> tabs;

  @override
  State<_TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<_TabShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (final t in widget.tabs) t.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in widget.tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
