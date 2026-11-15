import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/commandes/services/order_rules.dart'
    show formatPrice;
import 'package:dev_mobile/features/commandes/widgets/order_widgets.dart'
    show ProductThumb;
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../screens/cart_screen.dart';
import '../services/cart_rules.dart';
import '../services/cart_service.dart';

/// Bouton « Ajouter au panier », à placer dans la fiche produit (module Produits) :
///
/// ```dart
/// import 'package:dev_mobile/features/panier/widgets/cart_widgets.dart';
///
/// AddToCartButton(product: product)              // bouton pleine largeur
/// AddToCartButton(product: product, compact: true) // icône (cartes produits)
/// ```
/// Masqué pour les admins (ils ne commandent pas).
class AddToCartButton extends StatefulWidget {
  const AddToCartButton({
    super.key,
    required this.product,
    this.quantity = 1,
    this.compact = false,
  });

  final Product product;
  final int quantity;
  final bool compact;

  @override
  State<AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<AddToCartButton> {
  bool _busy = false;

  Future<void> _add() async {
    final user = CurrentUser.maybeOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (user == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Connectez-vous pour ajouter au panier.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await CartService.instance
          .add(user, widget.product, quantity: widget.quantity);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('« ${widget.product.name} » ajouté au panier'),
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () => navigator.push(MaterialPageRoute(
                builder: (_) => const CartScreen(showBack: true))),
          ),
        ));
    } on CartException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = CurrentUser.maybeOf(context);
    if (user?.isAdmin ?? false) return const SizedBox.shrink();

    final outOfStock = !widget.product.inStock;
    final onPressed = (_busy || outOfStock) ? null : _add;
    const spinner = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));

    if (widget.compact) {
      return IconButton.filled(
        tooltip: outOfStock ? 'Rupture de stock' : 'Ajouter au panier',
        onPressed: onPressed,
        icon: _busy ? spinner : const Icon(Icons.add_shopping_cart, size: 20),
      );
    }
    return FilledButton.icon(
      key: Key('add-to-cart-${widget.product.id}'),
      onPressed: onPressed,
      icon: _busy ? spinner : const Icon(Icons.add_shopping_cart),
      label: Text(outOfStock ? 'Rupture de stock' : 'Ajouter au panier'),
    );
  }
}

/// Sélecteur de quantité : [ − ]  2  [ + ]
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon,
                size: 18,
                color: onTap == null ? AppColors.textHint : AppColors.primary),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            value <= 1 ? Icons.delete_outline : Icons.remove,
            enabled ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          button(
            Icons.add,
            enabled && value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Une ligne du panier.
/// [onQuantity] null = lecture seule (vue admin).
class CartLineTile extends StatelessWidget {
  const CartLineTile({
    super.key,
    required this.line,
    this.onQuantity,
    this.onRemove,
    this.busy = false,
  });

  final CartLine line;
  final ValueChanged<int>? onQuantity;
  final VoidCallback? onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final product = line.product;
    final warning = CartRules.warningFor(line);
    final blocking = line.blocksCheckout;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: line.isUnavailable || line.isOutOfStock ? 0.4 : 1,
              child: ProductThumb(product?.imageUrl, size: 64),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product != null && product.brand.isNotEmpty)
                    Text(product.brand.toUpperCase(), style: text.labelSmall),
                  Text(
                    product?.name ?? 'Produit supprimé',
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product != null)
                    Text(
                      '${formatPrice(product.price)}'
                      '${product.volume.isEmpty ? '' : ' · ${product.volume}'}',
                      style: text.bodySmall,
                    ),
                  if (warning != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: StatusBadge(
                        warning,
                        tone: blocking ? BadgeTone.error : BadgeTone.warning,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      if (onQuantity != null && !line.isUnavailable)
                        QuantityStepper(
                          value: line.quantity,
                          max: line.maxQuantity < line.quantity
                              ? line.quantity
                              : line.maxQuantity,
                          enabled: !busy,
                          onChanged: onQuantity!,
                        )
                      else
                        Text('Quantité : ${line.quantity}',
                            style: text.bodyMedium),
                      const Spacer(),
                      Text(
                        formatPrice(line.subtotal),
                        style: AppTheme.serif(
                            size: 18,
                            weight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Retirer',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.close, color: AppColors.textHint),
              ),
          ],
        ),
      ),
    );
  }
}
