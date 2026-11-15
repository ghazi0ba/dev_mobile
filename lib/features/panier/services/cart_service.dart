import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dev_mobile/shared/models/models.dart';

import 'cart_rules.dart';

/// Erreur lisible à afficher à l'utilisateur.
class CartException implements Exception {
  const CartException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Accès Firestore du module Panier.
///
/// - `carts/{uid}/items/{productId}` : un document par produit, champ `quantity`
/// - `carts/{uid}` : résumé (nombre d'articles, total estimé…) pour l'admin
///
/// Les prix ne sont jamais stockés dans le panier : ils sont relus dans `products`.
class CartService {
  CartService({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  static final CartService instance = CartService();

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _carts =>
      _db.collection('carts');
  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _carts.doc(uid).collection('items');
  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  // ─── Lecture ──────────────────────────────────────────────────────────────

  /// Contenu du panier avec les produits à jour (dans l'ordre d'ajout).
  Stream<List<CartLine>> watchCart(String uid) =>
      _items(uid).snapshots().asyncMap(_withProducts);

  /// Nombre total d'unités dans le panier (pour un badge).
  Stream<int> watchItemCount(String uid) => _items(uid).snapshots().map(
        (q) => q.docs.fold<int>(
        0, (int total, doc) => total + _toInt(doc.data()['quantity'])),
      );

  Future<List<CartLine>> _withProducts(
      QuerySnapshot<Map<String, dynamic>> snap) async {
    final items = snap.docs
        .map((d) => CartItem.fromMap(d.id, d.data()))
        .where((i) => i.quantity > 0)
        .toList()
      ..sort((a, b) {
        final far = DateTime(9999);
        return (a.addedAt ?? far).compareTo(b.addedAt ?? far);
      });
    final products = await Future.wait(
      items.map((i) => _products.doc(i.productId).get()),
    );
    return [
      for (var i = 0; i < items.length; i++)
        CartLine(
          items[i],
          products[i].exists
              ? Product.fromMap(products[i].id, products[i].data()!)
              : null,
        ),
    ];
  }

  // ─── Client ───────────────────────────────────────────────────────────────

  /// Ajoute [quantity] unités d'un produit (refusé au-delà du stock).
  Future<void> add(AppUser user, Product product, {int quantity = 1}) async {
    final itemRef = _items(user.id).doc(product.id);
    final error = await _guard(() => _db.runTransaction<String?>((tx) async {
          final p = await tx.get(_products.doc(product.id));
          if (!p.exists) return 'Ce produit n\'est plus disponible.';
          final stock = _toInt(p.data()!['stock']);
          final item = await tx.get(itemRef);
          final current = item.exists ? _toInt(item.data()!['quantity']) : 0;

          final next = CartRules.quantityAfterAdd(
            current: current,
            adding: quantity,
            stock: stock,
          );
          if (next == null) {
            if (stock <= 0) return 'Ce produit est en rupture de stock.';
            return current > 0
                ? 'Vous avez déjà $current dans votre panier : '
                    'il n\'en reste que ${CartRules.maxFor(stock)}.'
                : 'Il n\'en reste que ${CartRules.maxFor(stock)}.';
          }
          tx.set(
            itemRef,
            {
              'quantity': next,
              if (!item.exists) 'addedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          return null;
        }));
    if (error != null) throw CartException(error);
    await refreshSummary(user);
  }

  /// Change la quantité d'un article (0 = retirer).
  Future<void> setQuantity(AppUser user, CartLine line, int quantity) async {
    if (quantity <= 0) return remove(user, line.productId);
    final max = line.maxQuantity;
    if (quantity > max) {
      throw CartException(max == 0
          ? 'Ce produit est en rupture de stock.'
          : 'Il n\'en reste que $max.');
    }
    await _guard(() => _items(user.id)
        .doc(line.productId)
        .set({'quantity': quantity}, SetOptions(merge: true)));
    await refreshSummary(user);
  }

  Future<void> remove(AppUser user, String productId) async {
    await _guard(() => _items(user.id).doc(productId).delete());
    await refreshSummary(user);
  }

  /// Remet un article retiré (bouton "Annuler" après une suppression).
  Future<void> restore(AppUser user, CartItem item) async {
    await _guard(() => _items(user.id).doc(item.productId).set({
          'quantity': item.quantity,
          'addedAt': item.addedAt ?? FieldValue.serverTimestamp(),
        }));
    await refreshSummary(user);
  }

  /// Vide tout le panier.
  Future<void> clear(AppUser user) async {
    await _deleteItems(user.id);
    await refreshSummary(user);
  }

  /// Retire les produits commandés (appelé par le module Commandes).
  Future<void> removeOrdered(AppUser user, Iterable<String> productIds) async {
    final batch = _db.batch();
    for (final id in productIds) {
      batch.delete(_items(user.id).doc(id));
    }
    await _guard(batch.commit);
    await refreshSummary(user);
  }

  /// Recalcule le résumé `carts/{uid}` (supprimé si le panier est vide).
  /// Un échec ici n'empêche jamais l'action du client.
  Future<void> refreshSummary(AppUser user) async {
    try {
      final lines = await _withProducts(await _items(user.id).get());
      final ref = _carts.doc(user.id);
      if (lines.isEmpty) {
        await ref.delete();
        return;
      }
      await ref.set({
        ...CartSummary(
          userId: user.id,
          customerName: user.fullName,
          customerEmail: user.email,
          itemCount: CartRules.itemCount(lines),
          lineCount: lines.length,
          estimatedTotal: CartRules.total(lines),
        ).toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Résumé non critique.
    }
  }

  // ─── Admin ────────────────────────────────────────────────────────────────

  /// Paniers non vides, les plus récemment modifiés d'abord.
  Stream<List<CartSummary>> watchAllCarts() => _carts.snapshots().map((q) {
        final far = DateTime(1970);
        return q.docs
            .map((d) => CartSummary.fromMap(d.id, d.data()))
            .where((c) => !c.isEmpty)
            .toList()
          ..sort((a, b) =>
              (b.updatedAt ?? far).compareTo(a.updatedAt ?? far));
      });

  /// L'admin vide le panier d'un client.
  Future<void> adminClear(String uid) async {
    await _deleteItems(uid);
    await _guard(() => _carts.doc(uid).delete());
  }

  // ─── Outil de test (mode debug) ───────────────────────────────────────────

  /// Ajoute 1 unité de quelques produits en stock.
  Future<int> fillTestCart(AppUser user, {int count = 3}) async {
    final products = await _guard(() =>
        _products.where('stock', isGreaterThan: 0).limit(count).get());
    var added = 0;
    for (final p in products.docs) {
      try {
        await add(user, Product.fromMap(p.id, p.data()));
        added++;
      } on CartException {
        // déjà au maximum : on passe au suivant
      }
    }
    return added;
  }

  // ─── Utilitaires ──────────────────────────────────────────────────────────

  Future<void> _deleteItems(String uid) async {
    final items = await _guard(() => _items(uid).get());
    final batch = _db.batch();
    for (final d in items.docs) {
      batch.delete(d.reference);
    }
    await _guard(batch.commit);
  }

  static int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw CartException(switch (e.code) {
        'permission-denied' => "Vous n'avez pas les droits pour cette action.",
        'unavailable' => 'Pas de connexion internet. Réessayez.',
        _ => 'Une erreur est survenue (${e.code}).',
      });
    }
  }
}
