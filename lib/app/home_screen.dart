import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/commandes/screens/order_detail_screen.dart';
import 'package:dev_mobile/features/commandes/services/order_rules.dart'
    show formatDateTime, formatPrice;
import 'package:dev_mobile/features/commandes/services/order_service.dart';
import 'package:dev_mobile/features/commandes/widgets/order_widgets.dart'
    show OrderStatusBadge;
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';
import 'package:dev_mobile/shared/models/models.dart';

/// Tableau de bord admin (maquette "Accueil"), avec les vrais chiffres
/// de Firestore, mis à jour en direct :
/// produits, stock, catégories, marques, commandes à traiter, alertes stock.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Stream<List<Product>> _products = FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((q) => q.docs.map((d) => Product.fromMap(d.id, d.data())).toList());

  final Stream<int> _categoryCount = FirebaseFirestore.instance
      .collection('categories')
      .snapshots()
      .map((q) => q.size);

  final Stream<List<CustomerOrder>> _orders =
  OrderService.instance.watchAllOrders();

  /// "Bonjour X," le jour, "Bonsoir X," à partir de 18 h.
  static String _greeting(AppUser? user) {
    final hello = DateTime.now().hour >= 18 ? 'Bonsoir' : 'Bonjour';
    final name = user?.firstName.trim() ?? '';
    return name.isEmpty ? '$hello,' : '$hello $name,';
  }

  void _openOrder(String id) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Accueil'),
      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, productSnap) => StreamBuilder<int>(
          stream: _categoryCount,
          builder: (context, categorySnap) =>
              StreamBuilder<List<CustomerOrder>>(
                stream: _orders,
                builder: (context, orderSnap) {
                  final error =
                      productSnap.error ?? categorySnap.error ?? orderSnap.error;
                  if (error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text('Impossible de charger les statistiques.\n$error',
                            textAlign: TextAlign.center),
                      ),
                    );
                  }
                  final loading = !productSnap.hasData ||
                      !categorySnap.hasData ||
                      !orderSnap.hasData;
                  final stats = _Stats(
                    products: productSnap.data ?? const [],
                    categories: categorySnap.data ?? 0,
                    orders: orderSnap.data ?? const [],
                  );

                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      // Message d'accueil
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _greeting(CurrentUser.maybeOf(context)),
                                        style: text.headlineSmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    const Icon(Icons.auto_awesome,
                                        size: 18, color: AppColors.accent),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text('Voici un aperçu de votre stock aujourd\'hui.',
                                    style: text.bodyMedium),
                              ],
                            ),
                          ),
                          const StatusBadge('BOUTIQUE ACTIVE',
                              tone: BadgeTone.success, showDot: true),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _HeroBanner(product: stats.newest),
                      const SizedBox(height: AppSpacing.md),

                      // Chiffres clés
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSpacing.sm + 4,
                        crossAxisSpacing: AppSpacing.sm + 4,
                        childAspectRatio: 1.35,
                        children: [
                          StatCard(
                            label: 'Produits',
                            value: loading ? '…' : '${stats.productCount}',
                            icon: Icons.spa_outlined,
                            badge: stats.addedThisMonth > 0
                                ? StatusBadge('+${stats.addedThisMonth} ce mois',
                                tone: BadgeTone.success)
                                : const StatusBadge('Références'),
                          ),
                          StatCard(
                            label: 'Stock disponible',
                            value: loading ? '…' : '${stats.units}',
                            icon: Icons.inventory_2_outlined,
                            iconBackground: AppColors.successLight,
                            badge: const StatusBadge('Unités'),
                          ),
                          StatCard(
                            label: 'Catégories',
                            value: loading ? '…' : '${stats.categories}',
                            icon: Icons.category_outlined,
                            iconBackground: AppColors.secondary,
                            badge: const StatusBadge('Rayons'),
                          ),
                          StatCard(
                            label: 'Marques',
                            value: loading ? '…' : '${stats.brands}',
                            icon: Icons.verified_outlined,
                            badge: const StatusBadge('Partenaires',
                                tone: BadgeTone.success),
                          ),
                          StatCard(
                            label: 'Commandes à traiter',
                            value: loading ? '…' : '${stats.pendingOrders}',
                            icon: Icons.hourglass_top_rounded,
                            iconBackground: AppColors.warningLight,
                            badge: stats.pendingOrders > 0
                                ? const StatusBadge('En attente',
                                tone: BadgeTone.warning)
                                : const StatusBadge('À jour',
                                tone: BadgeTone.success),
                          ),
                          StatCard(
                            label: 'Valeur du stock',
                            value: loading
                                ? '…'
                                : formatPrice(stats.stockValue)
                                .replaceAll(',00', ''),
                            icon: Icons.euro,
                            iconBackground: AppColors.successLight,
                            badge: const StatusBadge('Prix de vente'),
                          ),
                        ],
                      ),

                      // Alertes stock
                      if (!loading && stats.alerts.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        SectionCard(
                          title: 'Alertes stock (${stats.alerts.length})',
                          icon: Icons.warning_amber_rounded,
                          child: Column(
                            children: [
                              for (final p in stats.alerts.take(5))
                                _StockAlertRow(product: p),
                              if (stats.alerts.length > 5)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '+ ${stats.alerts.length - 5} autre(s) — '
                                        'voir l\'onglet Produits',
                                    style: text.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      // Dernières commandes
                      if (!loading && stats.latestOrders.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        SectionCard(
                          title: 'Dernières commandes',
                          icon: Icons.receipt_long_outlined,
                          child: Column(
                            children: [
                              for (final o in stats.latestOrders)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () => _openOrder(o.id),
                                  title: Text(
                                    o.customerName.isEmpty
                                        ? 'Commande ${o.shortId}'
                                        : '${o.customerName} · ${o.shortId}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                      '${formatPrice(o.total)} · ${_when(o)}'),
                                  trailing: OrderStatusBadge(o.status),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}

String _when(CustomerOrder o) =>
    o.createdAt == null ? "à l'instant" : formatDateTime(o.createdAt!);

/// Calculs du tableau de bord.
class _Stats {
  _Stats({
    required this.products,
    required this.categories,
    required List<CustomerOrder> orders,
  })  : pendingOrders =
      orders.where((o) => o.status == OrderStatus.enAttente).length,
        latestOrders = orders.take(3).toList(); // déjà triées, récentes d'abord

  final List<Product> products;
  final int categories;
  final int pendingOrders;
  final List<CustomerOrder> latestOrders;

  int get productCount => products.length;

  int get units =>
      products.fold<int>(0, (int total, p) => total + (p.stock > 0 ? p.stock : 0));

  double get stockValue => products.fold<double>(
      0, (double total, p) => total + p.price * (p.stock > 0 ? p.stock : 0));

  /// Marques différentes (sans tenir compte des majuscules).
  int get brands => products
      .map((p) => p.brand.trim().toLowerCase())
      .where((b) => b.isNotEmpty)
      .toSet()
      .length;

  /// Produits créés depuis le 1er du mois.
  int get addedThisMonth {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    return products
        .where((p) => p.createdAt != null && !p.createdAt!.isBefore(start))
        .length;
  }

  /// Ruptures puis stocks faibles, du plus urgent au moins urgent.
  List<Product> get alerts =>
      products.where((p) => !p.inStock || p.lowStock).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));

  /// Produit le plus récent (pour la bannière).
  Product? get newest {
    if (products.isEmpty) return null;
    final far = DateTime(1970);
    return products.reduce((a, b) =>
    (a.createdAt ?? far).isAfter(b.createdAt ?? far) ? a : b);
  }
}

class _StockAlertRow extends StatelessWidget {
  const _StockAlertRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final out = !product.inStock;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(product.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(
            out ? 'Rupture' : '${product.stock} restant(s)',
            tone: out ? BadgeTone.error : BadgeTone.warning,
            showDot: true,
          ),
        ],
      ),
    );
  }
}

/// Bannière : le produit le plus récent du catalogue, avec sa photo.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.product});
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final imageUrl = p?.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: SizedBox(
        height: 170,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFFD9C7B8), AppColors.primaryDark],
                ),
              ),
            ),
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            // Voile sombre pour que le texte reste lisible sur la photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB3000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p == null ? 'CATALOGUE' : 'DERNIÈRE NOUVEAUTÉ',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.accent),
                  ),
                  Text(
                    p?.name ?? 'Votre catalogue est vide',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.serif(size: 22, color: Colors.white),
                  ),
                  Text(
                    p == null
                        ? 'Ajoutez un premier produit depuis l\'onglet Produits'
                        : [
                      if (p.brand.isNotEmpty) p.brand,
                      formatPrice(p.price),
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}