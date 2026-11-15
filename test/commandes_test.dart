// Tests du module Commandes (logique pure, sans Firebase).
// Lancer : flutter test test/commandes_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:dev_mobile/features/commandes/services/order_rules.dart';
import 'package:dev_mobile/features/commandes/services/order_service.dart';
import 'package:dev_mobile/shared/models/models.dart';

const _serum = OrderLine(
    productId: 'p1', name: 'Sérum', unitPrice: 48.5, quantity: 2);
const _creme = OrderLine(
    productId: 'p2', name: 'Crème', unitPrice: 19.99, quantity: 1);

CustomerOrder _order({
  OrderStatus status = OrderStatus.enAttente,
  bool stockReserved = false,
}) =>
    CustomerOrder(
      id: 'abcdef123',
      userId: 'u1',
      lines: const [_serum, _creme],
      total: 116.99,
      shippingAddress: '12 rue Test',
      status: status,
      stockReserved: stockReserved,
    );

void main() {
  group('Cycle de vie', () {
    test('statuts suivants autorisés', () {
      expect(OrderRules.nextStatuses(OrderStatus.enAttente),
          [OrderStatus.confirmee, OrderStatus.annulee]);
      expect(OrderRules.nextStatuses(OrderStatus.confirmee),
          [OrderStatus.expediee, OrderStatus.annulee]);
      expect(OrderRules.nextStatuses(OrderStatus.expediee),
          [OrderStatus.livree, OrderStatus.annulee]);
      expect(OrderRules.nextStatuses(OrderStatus.livree), isEmpty);
      expect(OrderRules.nextStatuses(OrderStatus.annulee), isEmpty);
    });

    test('on ne saute pas d\'étape et on ne revient pas en arrière', () {
      expect(OrderRules.canMove(OrderStatus.enAttente, OrderStatus.livree),
          isFalse);
      expect(OrderRules.canMove(OrderStatus.livree, OrderStatus.annulee),
          isFalse);
      expect(OrderRules.canMove(OrderStatus.expediee, OrderStatus.enAttente),
          isFalse);
    });

    test('le client annule seulement une commande en attente', () {
      expect(OrderRules.canClientCancel(_order()), isTrue);
      expect(
          OrderRules.canClientCancel(_order(status: OrderStatus.confirmee)),
          isFalse);
    });
  });

  group('Stock', () {
    test('retiré à la confirmation, une seule fois', () {
      expect(OrderRules.reservesStock(_order(), OrderStatus.confirmee), isTrue);
      expect(
          OrderRules.reservesStock(
              _order(stockReserved: true), OrderStatus.confirmee),
          isFalse);
      expect(OrderRules.reservesStock(_order(), OrderStatus.annulee), isFalse);
    });

    test('remis seulement si une commande confirmée est annulée', () {
      expect(
          OrderRules.releasesStock(
              _order(status: OrderStatus.confirmee, stockReserved: true),
              OrderStatus.annulee),
          isTrue);
      // En attente : rien n'a été retiré, rien à remettre.
      expect(OrderRules.releasesStock(_order(), OrderStatus.annulee), isFalse);
    });

    test('détecte rupture, stock insuffisant et produit supprimé', () {
      final problems = OrderRules.stockProblems(
        const [_serum, _creme],
        {'p1': 1}, // p2 absent = supprimé
      );
      expect(problems['Sérum'], contains('1 unité'));
      expect(problems['Crème'], contains("n'est plus disponible"));

      expect(OrderRules.stockProblems(const [_serum], {'p1': 0})['Sérum'],
          contains('rupture'));
      expect(OrderRules.stockProblems(const [_serum], {'p1': 2}), isEmpty);
    });
  });

  group('Montants', () {
    test('total arrondi au centime', () {
      expect(OrderRules.totalOf(const [_serum, _creme]), 116.99);
      expect(_serum.total, 97.0);
    });

    test('format en euros', () {
      expect(formatPrice(48.5), '48,50 €');
      expect(formatPrice(0), '0,00 €');
    });

    test('CheckoutLine : sous-total et stock', () {
      const p = Product(
          id: 'p1', name: 'Sérum', price: 10, stock: 3, categoryId: 'c');
      expect(const CheckoutLine(p, 2).subtotal, 20);
      expect(const CheckoutLine(p, 3).enoughStock, isTrue);
      expect(const CheckoutLine(p, 4).enoughStock, isFalse);
      expect(const CheckoutLine(p, 2).toOrderLine().unitPrice, 10);
    });
  });

  group('Modèle CustomerOrder', () {
    test('toMap puis fromMap conserve les données', () {
      final at = DateTime(2026, 11, 15, 14, 7);
      final order = CustomerOrder(
        id: 'abcdef123',
        userId: 'u1',
        lines: const [_serum],
        total: 97,
        shippingAddress: '12 rue Test',
        customerName: 'Nadia Benali',
        customerPhone: '0612345678',
        note: '2e étage',
        status: OrderStatus.expediee,
        stockReserved: true,
        history: [
          OrderEvent(status: OrderStatus.enAttente, at: at, by: 'client'),
          OrderEvent(status: OrderStatus.expediee, at: at, by: 'admin'),
        ],
        createdAt: at,
      );

      final copy = CustomerOrder.fromMap(order.id, order.toMap());
      expect(copy.status, OrderStatus.expediee);
      expect(copy.stockReserved, isTrue);
      expect(copy.customerName, 'Nadia Benali');
      expect(copy.note, '2e étage');
      expect(copy.lines.single.quantity, 2);
      expect(copy.history.map((e) => e.by), ['client', 'admin']);
      expect(copy.itemCount, 2);
      expect(copy.shortId, '#ABCDEF');
    });

    test('ancienne commande sans les nouveaux champs', () {
      final o = CustomerOrder.fromMap('x1', {
        'userId': 'u1',
        'lines': [
          {'productId': 'p1', 'name': 'Sérum', 'unitPrice': 10, 'quantity': 1},
        ],
        'total': 10,
        'status': 'confirmee',
      });
      expect(o.status, OrderStatus.confirmee);
      expect(o.history, isEmpty);
      expect(o.stockReserved, isFalse);
      expect(o.customerName, '');
    });

    test('statut inconnu → en attente', () {
      expect(orderStatusFromName('nimporte'), OrderStatus.enAttente);
      expect(orderStatusFromName(null), OrderStatus.enAttente);
    });
  });
}
