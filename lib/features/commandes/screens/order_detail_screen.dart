import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../services/order_rules.dart';
import '../services/order_service.dart';
import '../widgets/order_widgets.dart';

/// Détail d'une commande, mis à jour en direct.
/// - client : suivi + annulation tant que la commande est "en attente"
/// - admin  : infos client + boutons pour faire avancer le statut
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final Stream<CustomerOrder?> _order =
      OrderService.instance.watchOrder(widget.orderId);
  OrderStatus? _busyWith;

  Future<void> _run(OrderStatus target, Future<void> Function() action,
      String success) async {
    setState(() => _busyWith = target);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on OrderException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busyWith = null);
    }
  }

  Future<void> _adminMove(CustomerOrder order, OrderStatus to) async {
    final cancelling = to == OrderStatus.annulee;
    final ok = await showConfirmDialog(
      context,
      title: '${OrderRules.actionLabel(to)} ?',
      message: switch (to) {
        OrderStatus.confirmee =>
          'Le stock des ${order.itemCount} article(s) sera retiré du catalogue.',
        OrderStatus.annulee => order.stockReserved
            ? 'La commande sera annulée et les articles remis en stock.'
            : 'La commande sera annulée.',
        _ => 'Le client verra le nouveau statut « ${to.label} ».',
      },
      confirmLabel: cancelling ? 'Oui, annuler' : 'Oui, continuer',
      destructive: cancelling,
    );
    if (!ok || !mounted) return;
    await _run(
      to,
      () => OrderService.instance.updateStatus(order.id, to),
      'Commande ${order.shortId} : ${to.label.toLowerCase()}',
    );
  }

  Future<void> _clientCancel(CustomerOrder order) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Annuler ma commande ?',
      message: 'Commande ${order.shortId} · ${formatPrice(order.total)}',
      confirmLabel: 'Oui, annuler',
      cancelLabel: 'Non, la garder',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(
      OrderStatus.annulee,
      () => OrderService.instance.cancelByClient(order),
      'Commande annulée',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = CurrentUser.maybeOf(context)?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la commande')),
      body: StreamBuilder<CustomerOrder?>(
        stream: _order,
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
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final order = snap.data;
          if (order == null) {
            return const Center(
              child: OrdersMessage(
                icon: Icons.search_off,
                title: 'Commande introuvable',
                message: 'Elle a peut-être été supprimée.',
              ),
            );
          }
          return _buildBody(order, isAdmin);
        },
      ),
    );
  }

  Widget _buildBody(CustomerOrder order, bool isAdmin) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // En-tête
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Commande ${order.shortId}',
                        style: text.titleLarge),
                  ),
                  OrderStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                order.createdAt == null
                    ? 'Passée à l\'instant'
                    : 'Passée le ${formatDateTime(order.createdAt!)}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(formatPrice(order.total),
                  style: AppTheme.serif(
                      size: 28,
                      weight: FontWeight.w700,
                      color: AppColors.primary)),
              Text('${order.itemCount} article(s) · paiement à la livraison',
                  style: text.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Actions
        ..._actions(order, isAdmin),

        // Articles
        SectionCard(
          title: 'Articles',
          icon: Icons.shopping_bag_outlined,
          child: Column(
            children: [
              for (final l in order.lines)
                OrderLineTile(
                  name: l.name,
                  unitPrice: l.unitPrice,
                  quantity: l.quantity,
                  imageUrl: l.imageUrl,
                ),
              const Divider(),
              SummaryRow('Sous-total', formatPrice(order.total)),
              const SummaryRow('Livraison', 'Offerte'),
              SummaryRow('Total', formatPrice(order.total), strong: true),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Livraison / client
        SectionCard(
          title: isAdmin ? 'Client & livraison' : 'Livraison',
          icon: Icons.local_shipping_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLine(Icons.person_outline,
                  order.customerName.isEmpty ? '—' : order.customerName),
              if (isAdmin && order.customerEmail.isNotEmpty)
                _InfoLine(Icons.alternate_email, order.customerEmail),
              _InfoLine(Icons.phone_outlined,
                  order.customerPhone.isEmpty ? '—' : order.customerPhone),
              _InfoLine(Icons.home_outlined,
                  order.shippingAddress.isEmpty ? '—' : order.shippingAddress),
              if (order.note.isNotEmpty)
                _InfoLine(Icons.notes_outlined, order.note),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Historique
        SectionCard(
          title: 'Suivi',
          icon: Icons.timeline,
          child: StatusTimeline(order: order),
        ),
        if (isAdmin) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            order.stockReserved
                ? 'Stock retiré du catalogue pour cette commande.'
                : 'Stock non encore retiré (retiré à la confirmation).',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  List<Widget> _actions(CustomerOrder order, bool isAdmin) {
    final busy = _busyWith != null;
    Widget spinner() => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2));

    if (isAdmin) {
      final next = OrderRules.nextStatuses(order.status);
      if (next.isEmpty) return const [];
      return [
        for (final to in next) ...[
          if (to == OrderStatus.annulee)
            OutlinedButton.icon(
              key: Key('order-action-${to.name}'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.errorLight,
                foregroundColor: AppColors.error,
              ),
              onPressed: busy ? null : () => _adminMove(order, to),
              icon: _busyWith == to ? spinner() : Icon(to.icon),
              label: Text(OrderRules.actionLabel(to)),
            )
          else
            FilledButton.icon(
              key: Key('order-action-${to.name}'),
              onPressed: busy ? null : () => _adminMove(order, to),
              icon: _busyWith == to ? spinner() : Icon(to.icon),
              label: Text(OrderRules.actionLabel(to)),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
      ];
    }

    if (!OrderRules.canClientCancel(order)) return const [];
    return [
      OutlinedButton.icon(
        key: const Key('client-cancel'),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.errorLight,
          foregroundColor: AppColors.error,
        ),
        onPressed: busy ? null : () => _clientCancel(order),
        icon: busy ? spinner() : const Icon(Icons.cancel_outlined),
        label: const Text('Annuler ma commande'),
      ),
      const SizedBox(height: AppSpacing.md),
    ];
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
