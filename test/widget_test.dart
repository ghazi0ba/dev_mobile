import 'package:flutter_test/flutter_test.dart';

import 'package:dev_mobile/shared/models/models.dart';

// Chaque module peut ajouter ses tests dans test/<module>_test.dart.
void main() {
  test('Product.fromMap lit les champs et le stock', () {
    final p = Product.fromMap('p1', {
      'name': 'Sérum Éclat',
      'price': 48,
      'stock': 5,
      'categoryId': 'serums',
    });
    expect(p.name, 'Sérum Éclat');
    expect(p.price, 48.0);
    expect(p.lowStock, isTrue);
  });

  test('OrderLine calcule son total', () {
    const line = OrderLine(
        productId: 'p1', name: 'Crème', unitPrice: 12.5, quantity: 3);
    expect(line.total, 37.5);
  });
}
