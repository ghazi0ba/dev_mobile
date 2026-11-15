import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dev_mobile/shared/models/models.dart';

import 'order_rules.dart';

/// Un article prêt à être commandé : le produit (relu depuis Firestore)
/// et la quantité choisie dans le panier.
class CheckoutLine {
  const CheckoutLine(this.product, this.quantity);

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;
  bool get enoughStock => product.stock >= quantity;

  OrderLine toOrderLine() => OrderLine(
        productId: product.id,
        name: product.name,
        unitPrice: product.price,
        quantity: quantity,
        imageUrl: product.imageUrl,
      );
}

/// Erreur lisible à afficher à l'utilisateur.
class OrderException implements Exception {
  const OrderException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Accès Firestore du module Commandes.
///
/// Collections utilisées :
/// - `orders/{id}`                     les commandes
/// - `carts/{uid}/items/{productId}`   le panier (champ `quantity`), lu à la validation
/// - `products/{id}`                   prix et stock relus au moment de commander
class OrderService {
  OrderService({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  static final OrderService instance = OrderService();

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');
  CollectionReference<Map<String, dynamic>> _cartItems(String uid) =>
      _db.collection('carts').doc(uid).collection('items');

  // ─── Lecture ──────────────────────────────────────────────────────────────

  /// Commandes d'un client, les plus récentes d'abord.
  /// (Tri fait ici pour éviter de créer un index composite dans Firestore.)
  Stream<List<CustomerOrder>> watchMyOrders(String uid) => _orders
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((q) => _sortNewestFirst(q.docs.map(_fromDoc).toList()));

  /// Toutes les commandes (admin), les plus récentes d'abord.
  Stream<List<CustomerOrder>> watchAllOrders() => _orders
      .snapshots()
      .map((q) => _sortNewestFirst(q.docs.map(_fromDoc).toList()));

  /// Une commande en temps réel (null si elle n'existe pas).
  Stream<CustomerOrder?> watchOrder(String id) => _orders
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? _fromDoc(d) : null);

  /// Contenu du panier `carts/{uid}/items`, avec les produits à jour.
  /// Les produits supprimés du catalogue sont ignorés.
  Future<List<CheckoutLine>> loadCart(String uid) => _guard(() async {
        final items = await _cartItems(uid).get();
        final lines = <CheckoutLine>[];
        for (final item in items.docs) {
          final quantity = _toInt(item.data()['quantity']);
          if (quantity <= 0) continue;
          final product = await _products.doc(item.id).get();
          if (!product.exists) continue;
          lines.add(
            CheckoutLine(Product.fromMap(product.id, product.data()!), quantity),
          );
        }
        return lines;
      });

  // ─── Client ───────────────────────────────────────────────────────────────

  /// Crée la commande (statut "en attente", paiement à la livraison)
  /// puis vide les articles commandés du panier. Retourne l'id de la commande.
  ///
  /// Les prix et le stock sont relus dans une transaction : on commande
  /// toujours au prix actuel, et jamais plus que le stock disponible.
  Future<String> placeOrder({
    required AppUser customer,
    required List<CheckoutLine> lines,
    required String shippingAddress,
    required String phone,
    String note = '',
    bool clearCart = true,
  }) async {
    if (lines.isEmpty) throw const OrderException('Votre panier est vide.');
    final ref = _orders.doc();

    final problem = await _guard(() => _db.runTransaction<String?>((tx) async {
          final fresh = <OrderLine>[];
          final stock = <String, int>{};
          for (final line in lines) {
            final snap = await tx.get(_products.doc(line.product.id));
            if (!snap.exists) continue;
            final product = Product.fromMap(snap.id, snap.data()!);
            stock[product.id] = product.stock;
            fresh.add(CheckoutLine(product, line.quantity).toOrderLine());
          }

          final problems = OrderRules.stockProblems(
            lines.map((l) => l.toOrderLine()),
            stock,
          );
          if (problems.isNotEmpty) return _describe(problems);

          final now = DateTime.now();
          final order = CustomerOrder(
            id: ref.id,
            userId: customer.id,
            lines: fresh,
            total: OrderRules.totalOf(fresh),
            shippingAddress: shippingAddress.trim(),
            customerName: customer.fullName,
            customerEmail: customer.email,
            customerPhone: phone.trim(),
            note: note.trim(),
            history: [
              OrderEvent(status: OrderStatus.enAttente, at: now, by: 'client'),
            ],
          );
          tx.set(ref, {
            ...order.toMap(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return null;
        }));

    if (problem != null) throw OrderException(problem);

    if (clearCart) {
      try {
        final batch = _db.batch();
        for (final line in lines) {
          batch.delete(_cartItems(customer.id).doc(line.product.id));
        }
        await batch.commit();
      } catch (_) {
        // La commande est passée : un panier non vidé n'est pas bloquant.
      }
    }
    return ref.id;
  }

  /// Le client annule sa commande tant qu'elle est "en attente".
  Future<void> cancelByClient(CustomerOrder order) async {
    if (!OrderRules.canClientCancel(order)) {
      throw const OrderException(
        'Cette commande a déjà été confirmée par la boutique : '
        'contactez-nous pour l\'annuler.',
      );
    }
    try {
      await _orders.doc(order.id).update({
        'status': OrderStatus.annulee.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([
          OrderEvent(
            status: OrderStatus.annulee,
            at: DateTime.now(),
            by: 'client',
          ).toMap(),
        ]),
      });
    } on FirebaseException catch (e) {
      // Les règles refusent si l'admin a confirmé entre-temps.
      throw OrderException(e.code == 'permission-denied'
          ? 'Cette commande ne peut plus être annulée.'
          : _firebaseMessage(e));
    }
  }

  // ─── Admin ────────────────────────────────────────────────────────────────

  /// Change le statut d'une commande.
  /// - confirmee : retire le stock (refusé si stock insuffisant)
  /// - annulee   : remet le stock si il avait été retiré
  Future<void> updateStatus(String orderId, OrderStatus to) async {
    final problem = await _guard(() => _db.runTransaction<String?>((tx) async {
          final orderRef = _orders.doc(orderId);
          final snap = await tx.get(orderRef);
          if (!snap.exists) return 'Commande introuvable.';
          final order = _fromDoc(snap);

          if (!OrderRules.canMove(order.status, to)) {
            return 'Cette commande est déjà « ${order.status.label} ».';
          }
          final reserve = OrderRules.reservesStock(order, to);
          final release = OrderRules.releasesStock(order, to);

          // Quantité totale par produit.
          final qty = <String, int>{};
          for (final l in order.lines) {
            qty[l.productId] = (qty[l.productId] ?? 0) + l.quantity;
          }

          // Toutes les lectures avant les écritures (obligatoire en transaction).
          final stock = <String, int>{};
          if (reserve || release) {
            for (final id in qty.keys) {
              final p = await tx.get(_products.doc(id));
              if (p.exists) stock[id] = _toInt(p.data()!['stock']);
            }
          }

          if (reserve) {
            final merged = [
              for (final e in qty.entries)
                OrderLine(
                  productId: e.key,
                  name: order.lines
                      .firstWhere((l) => l.productId == e.key)
                      .name,
                  unitPrice: 0,
                  quantity: e.value,
                ),
            ];
            final problems = OrderRules.stockProblems(merged, stock);
            if (problems.isNotEmpty) {
              return 'Impossible de confirmer : ${_describe(problems)}';
            }
            for (final e in qty.entries) {
              tx.update(_products.doc(e.key),
                  {'stock': FieldValue.increment(-e.value)});
            }
          }

          if (release) {
            for (final e in qty.entries) {
              if (!stock.containsKey(e.key)) continue; // produit supprimé
              tx.update(_products.doc(e.key),
                  {'stock': FieldValue.increment(e.value)});
            }
          }

          tx.update(orderRef, {
            'status': to.name,
            'stockReserved': reserve ? true : (release ? false : order.stockReserved),
            'updatedAt': FieldValue.serverTimestamp(),
            'history': FieldValue.arrayUnion([
              OrderEvent(status: to, at: DateTime.now(), by: 'admin').toMap(),
            ]),
          });
          return null;
        }));

    if (problem != null) throw OrderException(problem);
  }

  // ─── Outil de test (mode debug) ───────────────────────────────────────────

  /// Remplit le panier avec quelques produits en stock (1 unité chacun),
  /// pour tester les commandes avant que le module Panier soit prêt.
  Future<int> fillTestCart(String uid, {int count = 3}) => _guard(() async {
        final products = await _products
            .where('stock', isGreaterThan: 0)
            .limit(count)
            .get();
        final batch = _db.batch();
        for (final p in products.docs) {
          batch.set(_cartItems(uid).doc(p.id), {
            'quantity': 1,
            'addedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        return products.docs.length;
      });

  // ─── Utilitaires ──────────────────────────────────────────────────────────

  CustomerOrder _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      CustomerOrder.fromMap(d.id, d.data()!);

  static List<CustomerOrder> _sortNewestFirst(List<CustomerOrder> orders) {
    // Une commande qui vient d'être créée n'a pas encore sa date serveur.
    final far = DateTime(9999);
    return orders
      ..sort((a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
  }

  static int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  static String _describe(Map<String, String> problems) => problems.entries
      .map((e) => '« ${e.key} » ${e.value}')
      .join(' ; ');

  static String _firebaseMessage(FirebaseException e) => switch (e.code) {
        'permission-denied' => "Vous n'avez pas les droits pour cette action.",
        'unavailable' => 'Pas de connexion internet. Réessayez.',
        _ => 'Une erreur est survenue (${e.code}).',
      };

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw OrderException(_firebaseMessage(e));
    }
  }
}
