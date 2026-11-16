import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/panier/services/cart_service.dart';
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../services/order_service.dart';
import '../widgets/order_widgets.dart';
import 'checkout_screen.dart';
import 'order_detail_screen.dart';

/// Client : historique de ses commandes + accès à la validation du panier.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String? _uid;
  Stream<List<CustomerOrder>>? _orders;
  bool _filling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = CurrentUser.of(context).id;
    if (uid != _uid) {
      _uid = uid;
      _orders = OrderService.instance.watchMyOrders(uid);
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _fillTestCart() async {
    setState(() => _filling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await CartService.instance.fillTestCart(CurrentUser.of(context));
      messenger.showSnackBar(SnackBar(
          content: Text(n == 0
              ? 'Aucun produit en stock dans Firestore.'
              : '$n produit(s) ajouté(s) au panier de test.')));
    } on CartException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Mes commandes'),
      body: StreamBuilder<List<CustomerOrder>>(
        stream: _orders,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: OrdersMessage(
                icon: Icons.error_outline,
                title: 'Chargement impossible',
                message: '${snap.error}',
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final orders = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              SectionCard(
                child: Row(
                  children: [
                    const IconBadge(
                      icon: Icons.shopping_bag_outlined,
                      background: AppColors.secondary,
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    const Expanded(
                      child: Text('Votre panier est prêt ?\n'
                          'Validez-le pour passer commande.'),
                    ),
                    TextButton(
                      key: const Key('open-checkout'),
                      onPressed: () => _open(const CheckoutScreen()),
                      child: const Text('Commander'),
                    ),
                  ],
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _filling ? null : _fillTestCart,
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('Debug : remplir un panier de test'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('${orders.length} commande(s)',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              if (orders.isEmpty)
                const OrdersMessage(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucune commande',
                  message: 'Vos commandes apparaîtront ici.',
                ),
              for (final o in orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                  child: OrderCard(
                    order: o,
                    onTap: () => _open(OrderDetailScreen(orderId: o.id)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
