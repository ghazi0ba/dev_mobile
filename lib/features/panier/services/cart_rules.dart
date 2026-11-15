import 'package:dev_mobile/shared/models/models.dart';

/// Une ligne du panier : l'article et le produit à jour (null si supprimé).
class CartLine {
  const CartLine(this.item, this.product);

  final CartItem item;
  final Product? product;

  String get productId => item.productId;
  int get quantity => item.quantity;

  bool get isUnavailable => product == null;
  bool get isOutOfStock => product != null && product!.stock <= 0;

  /// Quantité demandée supérieure au stock (mais produit encore en stock).
  bool get exceedsStock =>
      product != null && product!.stock > 0 && quantity > product!.stock;

  /// La ligne empêche de commander.
  bool get blocksCheckout => isUnavailable || isOutOfStock || exceedsStock;

  double get subtotal => (product?.price ?? 0) * quantity;

  /// Quantité maximale autorisée pour ce produit.
  int get maxQuantity => CartRules.maxFor(product?.stock ?? 0);
}

/// Règles du panier, sans Firebase (testées dans test/panier_test.dart).
class CartRules {
  CartRules._();

  /// Plafond par produit, même si le stock est plus grand.
  static const maxPerProduct = 99;

  static int maxFor(int stock) =>
      stock < 0 ? 0 : (stock > maxPerProduct ? maxPerProduct : stock);

  /// Nouvelle quantité après un ajout, ou null si impossible.
  static int? quantityAfterAdd({
    required int current,
    required int adding,
    required int stock,
  }) {
    final next = current + adding;
    if (adding <= 0 || next > maxFor(stock)) return null;
    return next;
  }

  static int itemCount(Iterable<CartLine> lines) =>
      lines.fold(0, (sum, l) => sum + l.quantity);

  /// Total au centime près (les produits indisponibles comptent 0).
  static double total(Iterable<CartLine> lines) =>
      (lines.fold<double>(0, (sum, l) => sum + l.subtotal) * 100).round() /
      100;

  static bool canCheckout(List<CartLine> lines) =>
      lines.isNotEmpty && !lines.any((l) => l.blocksCheckout);

  /// Texte d'alerte à afficher sous une ligne, ou null.
  static String? warningFor(CartLine line) {
    if (line.isUnavailable) return 'Ce produit n\'est plus disponible';
    if (line.isOutOfStock) return 'Rupture de stock';
    if (line.exceedsStock) {
      return 'Il ne reste que ${line.product!.stock} unité(s)';
    }
    if (line.product!.lowStock) return 'Plus que ${line.product!.stock} en stock';
    return null;
  }
}
