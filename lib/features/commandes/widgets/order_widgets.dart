import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../services/order_rules.dart';

/// Couleur et icône de chaque statut.
extension OrderStatusStyle on OrderStatus {
  BadgeTone get tone => switch (this) {
        OrderStatus.enAttente => BadgeTone.warning,
        OrderStatus.confirmee => BadgeTone.brand,
        OrderStatus.expediee => BadgeTone.neutral,
        OrderStatus.livree => BadgeTone.success,
        OrderStatus.annulee => BadgeTone.error,
      };

  IconData get icon => switch (this) {
        OrderStatus.enAttente => Icons.hourglass_top_rounded,
        OrderStatus.confirmee => Icons.task_alt_rounded,
        OrderStatus.expediee => Icons.local_shipping_outlined,
        OrderStatus.livree => Icons.inventory_rounded,
        OrderStatus.annulee => Icons.cancel_outlined,
      };
}

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge(this.status, {super.key});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) =>
      StatusBadge(status.label, tone: status.tone, showDot: true);
}

/// Miniature d'un produit (image ou icône par défaut).
class ProductThumb extends StatelessWidget {
  const ProductThumb(this.imageUrl, {super.key, this.size = 52});
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.surfaceMuted,
      child: Icon(Icons.spa_outlined,
          color: AppColors.textHint, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? placeholder
          : Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Une ligne d'article : image, nom, quantité × prix, sous-total.
class OrderLineTile extends StatelessWidget {
  const OrderLineTile({
    super.key,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
    this.warning,
  });

  final String name;
  final double unitPrice;
  final int quantity;
  final String? imageUrl;

  /// Message en rouge sous l'article (ex. stock insuffisant).
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          ProductThumb(imageUrl),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('$quantity × ${formatPrice(unitPrice)}',
                    style: text.bodySmall),
                if (warning != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(warning!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12)),
                  ),
              ],
            ),
          ),
          Text(formatPrice(unitPrice * quantity),
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Ligne "libellé ........ valeur" (récapitulatif).
class SummaryRow extends StatelessWidget {
  const SummaryRow(this.label, this.value, {super.key, this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = strong
        ? AppTheme.serif(size: 22, weight: FontWeight.w700, color: AppColors.primary)
        : text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: strong
                    ? text.titleMedium
                    : text.bodyMedium),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Carte d'une commande dans une liste.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showCustomer = false,
  });

  final CustomerOrder order;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = order.lines.isEmpty ? null : order.lines.first;
    final others = order.lines.length - 1;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Commande ${order.shortId}',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  OrderStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                order.createdAt == null
                    ? 'À l\'instant'
                    : formatDateTime(order.createdAt!),
                style: text.bodySmall,
              ),
              if (showCustomer) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.customerName.isEmpty
                            ? order.customerEmail
                            : order.customerName,
                        style: text.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  ProductThumb(first?.imageUrl, size: 44),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      first == null
                          ? 'Aucun article'
                          : others > 0
                              ? '${first.name} + $others autre(s)'
                              : first.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatPrice(order.total),
                          style: AppTheme.serif(
                              size: 18,
                              weight: FontWeight.w700,
                              color: AppColors.primary)),
                      Text('${order.itemCount} article(s)',
                          style: text.bodySmall),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Historique des statuts sous forme de frise verticale.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final events = order.history;
    if (events.isEmpty) {
      return Text('Statut actuel : ${order.status.label}', style: text.bodyMedium);
    }
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  IconBadge(
                    icon: events[i].status.icon,
                    size: 32,
                    background: i == events.length - 1
                        ? AppColors.primary
                        : AppColors.secondary,
                    color: i == events.length - 1
                        ? Colors.white
                        : AppColors.primary,
                  ),
                  if (i < events.length - 1)
                    Container(width: 2, height: 22, color: AppColors.border),
                ],
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(events[i].status.label,
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '${formatDateTime(events[i].at)}'
                        '${events[i].by == 'admin' ? ' · par la boutique' : events[i].by == 'client' ? ' · par le client' : ''}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Message centré (liste vide, erreur…).
class OrdersMessage extends StatelessWidget {
  const OrdersMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, size: 64, background: AppColors.secondary),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
