import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';

import '../services/order_rules.dart';
import '../services/order_service.dart';
import '../widgets/order_widgets.dart';
import 'order_detail_screen.dart';

/// Validation du panier : récapitulatif, livraison, paiement, confirmation.
///
/// Pour le module Panier :
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const CheckoutScreen()),
/// );
/// ```
/// Sans [lines], l'écran lit le panier dans `carts/{uid}/items`.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.lines});

  /// Articles à commander. Si null : lus depuis Firestore.
  final List<CheckoutLine>? lines;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();

  late Future<List<CheckoutLine>> _lines;
  bool _prefilled = false;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final user = CurrentUser.of(context);
    _address.text = user.address ?? '';
    _phone.text = user.phone ?? '';
    _lines = widget.lines != null
        ? Future.value(widget.lines!)
        : OrderService.instance.loadCart(user.id);
  }

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _error = null;
        _lines = OrderService.instance.loadCart(CurrentUser.of(context).id);
      });

  Future<void> _confirm(List<CheckoutLine> lines, double total) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Confirmer la commande ?',
      message: 'Montant à régler à la livraison : ${formatPrice(total)}.',
      confirmLabel: 'Oui, commander',
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await OrderService.instance.placeOrder(
        customer: CurrentUser.of(context),
        lines: lines,
        shippingAddress: _address.text,
        phone: _phone.text,
        note: _note.text,
      );
      messenger.showSnackBar(
          const SnackBar(content: Text('Commande envoyée ! Merci.')));
      navigator.pushReplacement(MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: id)));
    } on OrderException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Valider ma commande')),
      body: FutureBuilder<List<CheckoutLine>>(
        future: _lines,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return Center(
              child: OrdersMessage(
                icon: Icons.error_outline,
                title: 'Panier indisponible',
                message: '${snap.error}',
                action: OutlinedButton(
                    onPressed: _reload, child: const Text('Réessayer')),
              ),
            );
          }
          final lines = snap.data ?? const <CheckoutLine>[];
          if (lines.isEmpty) {
            return Center(
              child: OrdersMessage(
                icon: Icons.shopping_bag_outlined,
                title: 'Votre panier est vide',
                message: 'Ajoutez des produits depuis la boutique.',
                action: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Retour')),
              ),
            );
          }
          return _buildForm(lines);
        },
      ),
    );
  }

  Widget _buildForm(List<CheckoutLine> lines) {
    final user = CurrentUser.of(context);
    final total = OrderRules.totalOf(lines.map((l) => l.toOrderLine()));
    final blocked = lines.any((l) => !l.enoughStock);
    final itemCount = lines.fold<int>(0, (s, l) => s + l.quantity);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SectionCard(
            title: 'Articles ($itemCount)',
            icon: Icons.shopping_bag_outlined,
            child: Column(
              children: [
                for (final l in lines)
                  OrderLineTile(
                    name: l.product.name,
                    unitPrice: l.product.price,
                    quantity: l.quantity,
                    imageUrl: l.product.imageUrl,
                    warning: l.enoughStock
                        ? null
                        : l.product.stock == 0
                            ? 'Rupture de stock : retirez-le du panier'
                            : 'Stock insuffisant : il en reste ${l.product.stock}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Livraison',
            icon: Icons.local_shipping_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: user.fullName,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Destinataire',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('checkout-phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    return digits.length < 8
                        ? 'Numéro de téléphone obligatoire'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('checkout-address'),
                  controller: _address,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Adresse de livraison *',
                    hintText: 'N°, rue, ville, code postal',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Adresse de livraison obligatoire'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (facultatif)',
                    hintText: 'Étage, code d\'accès, horaires…',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Paiement',
            icon: Icons.payments_outlined,
            child: Row(
              children: [
                const Icon(Icons.radio_button_checked, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paiement à la livraison',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Espèces ou carte, au livreur.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            child: Column(
              children: [
                SummaryRow('Sous-total', formatPrice(total)),
                const SummaryRow('Livraison', 'Offerte'),
                const Divider(),
                SummaryRow('Total', formatPrice(total), strong: true),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorBox(_error!, onRetry: _reload),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('confirm-order'),
            onPressed: (_busy || blocked) ? null : () => _confirm(lines, total),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(blocked
                ? 'Corrigez les articles en rouge'
                : 'Confirmer la commande · ${formatPrice(total)}'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message, {required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message,
              style: const TextStyle(color: AppColors.error, fontSize: 13)),
          TextButton(
            onPressed: onRetry,
            child: const Text('Actualiser le panier'),
          ),
        ],
      ),
    );
  }
}
