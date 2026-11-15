import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/commandes/screens/checkout_screen.dart';
import 'package:dev_mobile/features/commandes/services/order_rules.dart'
    show formatPrice;
import 'package:dev_mobile/features/commandes/widgets/order_widgets.dart'
    show OrdersMessage, SummaryRow;
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../services/cart_rules.dart';
import '../services/cart_service.dart';
import '../widgets/cart_widgets.dart';
import 'admin_carts_screen.dart';
import 'test_products_sheet.dart';

/// Onglet "Panier" (client) ; pour un admin : les paniers en cours des clients.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key, this.showBack = false});

  /// true quand l'écran est ouvert par-dessus un autre (bouton "Voir").
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final user = CurrentUser.maybeOf(context);
    if (user == null) {
      return const Scaffold(
        appBar: AppHeader(subtitle: 'Panier'),
        body: Center(child: Text('Connectez-vous pour voir le panier.')),
      );
    }
    if (user.isAdmin) return const AdminCartsScreen();
    return _ClientCart(user: user, showBack: showBack);
  }
}

class _ClientCart extends StatefulWidget {
  const _ClientCart({required this.user, required this.showBack});
  final AppUser user;
  final bool showBack;

  @override
  State<_ClientCart> createState() => _ClientCartState();
}

class _ClientCartState extends State<_ClientCart> {
  late Stream<List<CartLine>> _cart =
      CartService.instance.watchCart(widget.user.id);
  final Set<String> _busy = {};

  /// Lignes retirées par glissement : masquées tout de suite
  /// (Dismissible exige qu'elles disparaissent avant la mise à jour Firestore).
  final Set<String> _hidden = {};

  @override
  void didUpdateWidget(covariant _ClientCart old) {
    super.didUpdateWidget(old);
    if (old.user.id != widget.user.id) {
      _cart = CartService.instance.watchCart(widget.user.id);
    }
  }

  CartService get _service => CartService.instance;

  Future<void> _guarded(String key, Future<void> Function() action) async {
    setState(() => _busy.add(key));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on CartException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _remove(CartLine line, {bool swiped = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (swiped) setState(() => _hidden.add(line.productId));
    try {
      await _service.remove(widget.user, line.productId);
    } on CartException catch (e) {
      if (mounted) setState(() => _hidden.remove(line.productId));
      messenger.showSnackBar(SnackBar(
          content: Text(e.message), backgroundColor: AppColors.error));
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('« ${line.product?.name ?? 'Produit'} » retiré'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            if (mounted) setState(() => _hidden.remove(line.productId));
            _service.restore(widget.user, line.item);
          },
        ),
      ));
  }

  Future<void> _clear() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Vider le panier ?',
      message: 'Tous les articles seront retirés.',
      confirmLabel: 'Oui, vider',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _guarded('*', () => _service.clear(widget.user));
  }

  void _checkout() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));

  void _openTestProducts() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const TestProductsSheet(),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CartLine>>(
      stream: _cart,
      builder: (context, snap) {
        // Une fois la suppression confirmée par Firestore, on n'a plus
        // besoin de masquer la ligne (elle peut être rajoutée plus tard).
        if (snap.hasData) {
          _hidden.removeWhere(
              (id) => !snap.data!.any((l) => l.productId == id));
        }
        final lines = (snap.data ?? const <CartLine>[])
            .where((l) => !_hidden.contains(l.productId))
            .toList();
        return Scaffold(
          appBar: AppHeader(
            subtitle: 'Mon panier',
            showBack: widget.showBack,
            actions: [
              if (lines.isNotEmpty)
                IconButton(
                  tooltip: 'Vider le panier',
                  onPressed: _busy.isEmpty ? _clear : null,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: _body(snap, lines),
          bottomNavigationBar:
              lines.isEmpty ? null : _CheckoutBar(lines: lines, onCheckout: _checkout),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<List<CartLine>> snap, List<CartLine> lines) {
    if (snap.hasError) {
      return Center(
        child: OrdersMessage(
          icon: Icons.error_outline,
          title: 'Panier indisponible',
          message: '${snap.error}',
        ),
      );
    }
    if (!snap.hasData) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (lines.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: OrdersMessage(
            icon: Icons.shopping_bag_outlined,
            title: 'Votre panier est vide',
            message: 'Ajoutez des soins depuis l\'onglet Boutique.',
            action: kDebugMode
                ? OutlinedButton.icon(
                    onPressed: _openTestProducts,
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('Debug : ajouter des produits'),
                  )
                : null,
          ),
        ),
      );
    }
    final count = CartRules.itemCount(lines);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('$count article(s)',
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
            child: Dismissible(
              key: ValueKey(line.productId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
              onDismissed: (_) => _remove(line, swiped: true),
              child: CartLineTile(
                line: line,
                busy: _busy.contains(line.productId) || _busy.contains('*'),
                onQuantity: (q) => q <= 0
                    ? _remove(line)
                    : _guarded(line.productId,
                        () => _service.setQuantity(widget.user, line, q)),
                onRemove: () => _remove(line),
              ),
            ),
          ),
        if (kDebugMode)
          TextButton.icon(
            onPressed: _openTestProducts,
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Debug : ajouter des produits'),
          ),
      ],
    );
  }
}

/// Barre du bas : total + bouton Commander.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.lines, required this.onCheckout});
  final List<CartLine> lines;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final total = CartRules.total(lines);
    final ok = CartRules.canCheckout(lines);
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SummaryRow('Livraison', 'Offerte'),
              SummaryRow('Total', formatPrice(total), strong: true),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('cart-checkout'),
                onPressed: ok ? onCheckout : null,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: Text(ok
                    ? 'Commander · ${formatPrice(total)}'
                    : 'Corrigez les articles en rouge'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
