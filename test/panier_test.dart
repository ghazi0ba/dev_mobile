// Tests du module Panier (logique pure, sans Firebase).
// Lancer : flutter test test/panier_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:dev_mobile/features/panier/services/cart_rules.dart';
import 'package:dev_mobile/shared/models/models.dart';

Product _product({int stock = 10, double price = 12.5}) => Product(
    id: 'p1', name: 'Crème', price: price, stock: stock, categoryId: 'c');

CartLine _line(int quantity, {Product? product, bool deleted = false}) =>
    CartLine(
      CartItem(productId: 'p1', quantity: quantity),
      deleted ? null : (product ?? _product()),
    );

void main() {
  group('Ajout au panier', () {
    test('ajoute dans la limite du stock', () {
      expect(CartRules.quantityAfterAdd(current: 0, adding: 1, stock: 5), 1);
      expect(CartRules.quantityAfterAdd(current: 4, adding: 1, stock: 5), 5);
    });

    test('refuse au-delà du stock ou si rupture', () {
      expect(CartRules.quantityAfterAdd(current: 5, adding: 1, stock: 5),
          isNull);
      expect(CartRules.quantityAfterAdd(current: 0, adding: 1, stock: 0),
          isNull);
      expect(CartRules.quantityAfterAdd(current: 0, adding: 0, stock: 5),
          isNull);
    });

    test('plafond de 99 par produit', () {
      expect(CartRules.maxFor(500), 99);
      expect(CartRules.quantityAfterAdd(current: 99, adding: 1, stock: 500),
          isNull);
      expect(CartRules.maxFor(-3), 0);
    });
  });

  group('Lignes du panier', () {
    test('sous-total et total au centime', () {
      final lines = [
        _line(2, product: _product(price: 12.5)),
        CartLine(const CartItem(productId: 'p2', quantity: 3),
            const Product(
                id: 'p2', name: 'Huile', price: 9.99, stock: 5, categoryId: 'c')),
      ];
      expect(lines.first.subtotal, 25);
      expect(CartRules.itemCount(lines), 5);
      expect(CartRules.total(lines), 54.97);
    });

    test('produit supprimé : bloque la commande et compte 0', () {
      final line = _line(2, deleted: true);
      expect(line.isUnavailable, isTrue);
      expect(line.blocksCheckout, isTrue);
      expect(line.subtotal, 0);
      expect(CartRules.warningFor(line), contains('plus disponible'));
    });

    test('rupture et quantité supérieure au stock bloquent la commande', () {
      final rupture = _line(1, product: _product(stock: 0));
      expect(rupture.isOutOfStock, isTrue);
      expect(CartRules.warningFor(rupture), 'Rupture de stock');

      final tooMany = _line(4, product: _product(stock: 2));
      expect(tooMany.exceedsStock, isTrue);
      expect(CartRules.warningFor(tooMany), contains('2 unité'));
      expect(CartRules.canCheckout([tooMany]), isFalse);
    });

    test('stock faible : simple alerte, la commande reste possible', () {
      final low = _line(1, product: _product(stock: 3));
      expect(low.blocksCheckout, isFalse);
      expect(CartRules.warningFor(low), contains('3 en stock'));
      expect(CartRules.canCheckout([low]), isTrue);
    });

    test('panier vide : pas de commande', () {
      expect(CartRules.canCheckout(const []), isFalse);
    });
  });

  group('Résumé carts/{uid}', () {
    test('toMap puis fromMap', () {
      final s = CartSummary(
        userId: 'u1',
        customerName: 'Nadia Benali',
        customerEmail: 'nadia@test.com',
        itemCount: 4,
        lineCount: 2,
        estimatedTotal: 54.97,
        updatedAt: DateTime(2026, 11, 15),
      );
      final copy = CartSummary.fromMap('u1', s.toMap());
      expect(copy.customerName, 'Nadia Benali');
      expect(copy.itemCount, 4);
      expect(copy.estimatedTotal, 54.97);
      expect(copy.isEmpty, isFalse);
      expect(CartSummary.fromMap('u2', const {}).isEmpty, isTrue);
    });
  });
}
