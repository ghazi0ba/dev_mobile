import 'package:dev_mobile/shared/models/models.dart';

/// Règles métier des commandes, sans Firebase (testées dans test/commandes_test.dart).
///
/// Cycle de vie :
///   enAttente → confirmee → expediee → livree
///        ↘          ↘           ↘
///                 annulee
///
/// Le stock est retiré quand l'admin CONFIRME la commande, et remis
/// si une commande confirmée ou expédiée est annulée.
class OrderRules {
  OrderRules._();

  /// Statuts que l'admin peut choisir ensuite.
  static List<OrderStatus> nextStatuses(OrderStatus current) =>
      switch (current) {
        OrderStatus.enAttente => [OrderStatus.confirmee, OrderStatus.annulee],
        OrderStatus.confirmee => [OrderStatus.expediee, OrderStatus.annulee],
        OrderStatus.expediee => [OrderStatus.livree, OrderStatus.annulee],
        OrderStatus.livree || OrderStatus.annulee => const [],
      };

  static bool canMove(OrderStatus from, OrderStatus to) =>
      nextStatuses(from).contains(to);

  /// Le client peut annuler tant que la boutique n'a pas confirmé.
  static bool canClientCancel(CustomerOrder order) =>
      order.status == OrderStatus.enAttente;

  /// La transition retire-t-elle le stock ?
  static bool reservesStock(CustomerOrder order, OrderStatus to) =>
      to == OrderStatus.confirmee && !order.stockReserved;

  /// La transition remet-elle le stock ?
  static bool releasesStock(CustomerOrder order, OrderStatus to) =>
      to == OrderStatus.annulee && order.stockReserved;

  /// Total arrondi au centime.
  static double totalOf(Iterable<OrderLine> lines) =>
      (lines.fold<double>(0, (sum, l) => sum + l.total) * 100).round() / 100;

  /// Problèmes de stock : nom du produit → message. Vide si tout va bien.
  /// [stockById] : stock actuel de chaque produit (absent = produit supprimé).
  static Map<String, String> stockProblems(
    Iterable<OrderLine> lines,
    Map<String, int> stockById,
  ) {
    final problems = <String, String>{};
    for (final line in lines) {
      final stock = stockById[line.productId];
      if (stock == null) {
        problems[line.name] = "n'est plus disponible";
      } else if (stock < line.quantity) {
        problems[line.name] = stock == 0
            ? 'est en rupture de stock'
            : 'il ne reste que $stock unité(s)';
      }
    }
    return problems;
  }

  /// Texte du bouton admin pour passer à [to].
  static String actionLabel(OrderStatus to) => switch (to) {
        OrderStatus.confirmee => 'Confirmer la commande',
        OrderStatus.expediee => 'Marquer comme expédiée',
        OrderStatus.livree => 'Marquer comme livrée',
        OrderStatus.annulee => 'Annuler la commande',
        OrderStatus.enAttente => 'Remettre en attente',
      };
}

/// 48.5 → "48,50 €"
String formatPrice(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

String _two(int n) => n.toString().padLeft(2, '0');

/// 05/03/2026 à 14:07
String formatDateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} à ${_two(d.hour)}:${_two(d.minute)}';
