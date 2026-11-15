import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/commandes/services/order_rules.dart'
    show formatPrice;
import 'package:dev_mobile/features/commandes/widgets/order_widgets.dart'
    show ProductThumb;
import 'package:dev_mobile/shared/models/models.dart';

import '../widgets/cart_widgets.dart';

/// OUTIL DE TEST (mode debug uniquement) : liste les produits de Firestore
/// avec un bouton « Ajouter au panier », en attendant le module Produits.
class TestProductsSheet extends StatelessWidget {
  const TestProductsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final products = snap.data!.docs
              .map((d) => Product.fromMap(d.id, d.data()))
              .toList();
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
            children: [
              Text('Produits de test', style: text.titleLarge),
              Text('${products.length} produit(s) dans Firestore',
                  style: text.bodySmall),
              const SizedBox(height: AppSpacing.md),
              if (products.isEmpty)
                const Text('Ajoutez des produits dans la console Firebase '
                    '(collection products : name, price, stock).'),
              for (final p in products)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      leading: ProductThumb(p.imageUrl, size: 44),
                      title: Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${formatPrice(p.price)} · stock ${p.stock}'),
                      trailing: AddToCartButton(product: p, compact: true),
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
