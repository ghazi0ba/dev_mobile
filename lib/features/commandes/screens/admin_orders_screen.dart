import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/panier/screens/admin_carts_screen.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../services/order_rules.dart';
import '../services/order_service.dart';
import '../widgets/order_widgets.dart';
import 'order_detail_screen.dart';

/// Admin : toutes les commandes, avec statistiques, recherche et filtre par statut.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final Stream<List<CustomerOrder>> _orders =
      OrderService.instance.watchAllOrders();
  final _search = TextEditingController();
  OrderStatus? _filter; // null = toutes

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CustomerOrder> _apply(List<CustomerOrder> all) {
    final q = _search.text.trim().toLowerCase().replaceAll('#', '');
    return all.where((o) {
      if (_filter != null && o.status != _filter) return false;
      if (q.isEmpty) return true;
      return o.id.toLowerCase().startsWith(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerEmail.toLowerCase().contains(q) ||
          o.customerPhone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Commandes'),
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
          final all = snap.data!;
          final count = {
            for (final s in OrderStatus.values)
              s: all.where((o) => o.status == s).length,
          };
          final delivered = OrderRules.totalOf(all
              .where((o) => o.status == OrderStatus.livree)
              .expand((o) => o.lines));
          final list = _apply(all);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'À traiter',
                      value: '${count[OrderStatus.enAttente]}',
                      icon: Icons.hourglass_top_rounded,
                      iconBackground: AppColors.warningLight,
                      badge: const StatusBadge('En attente',
                          tone: BadgeTone.warning),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: StatCard(
                      label: 'À expédier',
                      value: '${count[OrderStatus.confirmee]}',
                      icon: Icons.local_shipping_outlined,
                      iconBackground: AppColors.secondary,
                      badge: const StatusBadge('Confirmées',
                          tone: BadgeTone.brand),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              SectionCard(
                child: Row(
                  children: [
                    const IconBadge(
                      icon: Icons.payments_outlined,
                      background: AppColors.successLight,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Text('Chiffre d\'affaires livré',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Text(formatPrice(delivered),
                        style: AppTheme.serif(
                            size: 20, weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Card(
                child: ListTile(
                  key: const Key('open-admin-carts'),
                  leading: const IconBadge(
                    icon: Icons.shopping_bag_outlined,
                    background: AppColors.secondary,
                  ),
                  title: const Text('Paniers en cours'),
                  subtitle: const Text('Ce que les clients n\'ont pas encore commandé'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminCartsScreen())),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'N° de commande, client, email, téléphone',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Toutes (${all.length})', null),
                    for (final s in OrderStatus.values)
                      _chip('${s.label} (${count[s]})', s),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (list.isEmpty)
                const OrdersMessage(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucune commande',
                  message: 'Aucune commande ne correspond à ce filtre.',
                ),
              for (final o in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                  child: OrderCard(
                    order: o,
                    showCustomer: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: o.id))),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, OrderStatus? status) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == status,
          onSelected: (_) => setState(() => _filter = status),
        ),
      );
}
