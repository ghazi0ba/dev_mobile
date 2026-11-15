import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/commandes/services/order_rules.dart'
    show formatPrice, formatDateTime;
import 'package:dev_mobile/features/commandes/widgets/order_widgets.dart'
    show OrdersMessage, SummaryRow;
import 'package:dev_mobile/shared/models/models.dart';

import '../services/cart_rules.dart';
import '../services/cart_service.dart';
import '../widgets/cart_widgets.dart';

/// Un panier est "abandonné" s'il n'a pas bougé depuis ce délai.
const _abandonedAfter = Duration(hours: 24);

bool _isAbandoned(CartSummary c) =>
    c.updatedAt != null &&
    DateTime.now().difference(c.updatedAt!) > _abandonedAfter;

String _when(CartSummary c) =>
    c.updatedAt == null ? "à l'instant" : formatDateTime(c.updatedAt!);

/// Admin : paniers en cours des clients (ce qu'ils n'ont pas encore commandé).
class AdminCartsScreen extends StatefulWidget {
  const AdminCartsScreen({super.key});

  @override
  State<AdminCartsScreen> createState() => _AdminCartsScreenState();
}

class _AdminCartsScreenState extends State<AdminCartsScreen> {
  final Stream<List<CartSummary>> _carts =
      CartService.instance.watchAllCarts();
  final _search = TextEditingController();
  bool _onlyAbandoned = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppHeader(subtitle: 'Paniers clients', showBack: canPop),
      body: StreamBuilder<List<CartSummary>>(
        stream: _carts,
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
          final q = _search.text.trim().toLowerCase();
          final list = all.where((c) {
            if (_onlyAbandoned && !_isAbandoned(c)) return false;
            return q.isEmpty ||
                c.customerName.toLowerCase().contains(q) ||
                c.customerEmail.toLowerCase().contains(q);
          }).toList();
          final value = all.fold<double>(0, (s, c) => s + c.estimatedTotal);
          final abandoned = all.where(_isAbandoned).length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Paniers en cours',
                      value: '${all.length}',
                      icon: Icons.shopping_bag_outlined,
                      iconBackground: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: StatCard(
                      label: 'Abandonnés',
                      value: '$abandoned',
                      icon: Icons.schedule,
                      iconBackground: AppColors.warningLight,
                      badge: const StatusBadge('+24 h', tone: BadgeTone.warning),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              SectionCard(
                child: Row(
                  children: [
                    const IconBadge(
                      icon: Icons.euro,
                      background: AppColors.successLight,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Text('Valeur des paniers (estimée)',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Text(formatPrice(value),
                        style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un client',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text('Tous (${all.length})'),
                    selected: !_onlyAbandoned,
                    onSelected: (_) => setState(() => _onlyAbandoned = false),
                  ),
                  ChoiceChip(
                    label: Text('Abandonnés ($abandoned)'),
                    selected: _onlyAbandoned,
                    onSelected: (_) => setState(() => _onlyAbandoned = true),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (list.isEmpty)
                const OrdersMessage(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Aucun panier',
                  message: 'Aucun client n\'a de panier en cours.',
                ),
              for (final c in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AdminCartDetailScreen(summary: c))),
                      leading: const IconBadge(
                        icon: Icons.person_outline,
                        background: AppColors.secondary,
                      ),
                      title: Text(
                        c.customerName.isEmpty ? c.customerEmail : c.customerName,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c.itemCount} article(s) · ${_when(c)}'),
                          if (_isAbandoned(c))
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: StatusBadge('Abandonné',
                                  tone: BadgeTone.warning),
                            ),
                        ],
                      ),
                      trailing: Text(formatPrice(c.estimatedTotal),
                          style: AppTheme.serif(
                              size: 16,
                              weight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Admin : contenu du panier d'un client (lecture seule + vider).
class AdminCartDetailScreen extends StatefulWidget {
  const AdminCartDetailScreen({super.key, required this.summary});
  final CartSummary summary;

  @override
  State<AdminCartDetailScreen> createState() => _AdminCartDetailScreenState();
}

class _AdminCartDetailScreenState extends State<AdminCartDetailScreen> {
  late final Stream<List<CartLine>> _cart =
      CartService.instance.watchCart(widget.summary.userId);
  bool _busy = false;

  Future<void> _clear() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Vider ce panier ?',
      message: 'Le client ne retrouvera plus ces articles dans son panier.',
      confirmLabel: 'Oui, vider',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CartService.instance.adminClear(widget.summary.userId);
      messenger.showSnackBar(const SnackBar(content: Text('Panier vidé')));
      navigator.pop();
    } on CartException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Panier du client')),
      body: StreamBuilder<List<CartLine>>(
        stream: _cart,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final lines = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.customerName.isEmpty ? 'Client' : s.customerName,
                        style: text.titleLarge),
                    if (s.customerEmail.isNotEmpty)
                      Text(s.customerEmail, style: text.bodyMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      s.updatedAt == null
                          ? 'Modifié à l\'instant'
                          : 'Modifié le ${formatDateTime(s.updatedAt!)}',
                      style: text.bodySmall,
                    ),
                    if (_isAbandoned(s))
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: StatusBadge('Panier abandonné',
                            tone: BadgeTone.warning),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (lines.isEmpty)
                const OrdersMessage(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Panier vide',
                  message: 'Le client a commandé ou vidé son panier.',
                ),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: CartLineTile(line: l),
                ),
              if (lines.isNotEmpty) ...[
                SectionCard(
                  child: Column(
                    children: [
                      SummaryRow('Articles', '${CartRules.itemCount(lines)}'),
                      SummaryRow('Total au prix actuel',
                          formatPrice(CartRules.total(lines)),
                          strong: true),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.errorLight,
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: _busy ? null : _clear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Vider ce panier'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
