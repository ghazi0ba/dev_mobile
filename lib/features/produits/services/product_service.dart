import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dev_mobile/shared/models/models.dart';

/// Service for product CRUD operations with Firestore
class ProductService {
  final FirebaseFirestore _firestore;

  ProductService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get all products with real-time updates
  Stream<List<Product>> watchAllProducts() {
    return _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Product.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  /// Get all products (one-time fetch)
  Future<List<Product>> getAllProducts() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Impossible de charger les produits');
    }
  }

  /// Get product by ID
  Future<Product?> getProductById(String id) async {
    try {
      final doc = await _firestore.collection('products').doc(id).get();

      if (!doc.exists) return null;

      return Product.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Impossible de charger le produit');
    }
  }

  /// Add a new product
  Future<String> addProduct(Product product) async {
    try {
      final docRef = _firestore.collection('products').doc();

      final data = product.toMap();
      // La note est gérée par le module Avis : on ne l'écrase pas.
      data.remove('ratingAverage');
      data.remove('ratingCount');
      data['createdAt'] = FieldValue.serverTimestamp();

      await docRef.set(data);

      return docRef.id;
    } catch (e) {
      throw Exception('Impossible d\'ajouter le produit: $e');
    }
  }

  /// Update an existing product
  Future<void> updateProduct(Product product) async {
    try {
      final data = product.toMap();
      // Preserve the original creation date
      if (product.createdAt != null) {
        data['createdAt'] = Timestamp.fromDate(product.createdAt!);
      }

      await _firestore.collection('products').doc(product.id).update(data);
    } catch (e) {
      throw Exception('Impossible de modifier le produit');
    }
  }

  /// Delete a product
  Future<void> deleteProduct(String id) async {
    try {
      await _firestore.collection('products').doc(id).delete();
    } catch (e) {
      throw Exception('Impossible de supprimer le produit');
    }
  }

  /// Update product stock
  Future<void> updateStock(String id, int newStock) async {
    try {
      await _firestore.collection('products').doc(id).update({
        'stock': newStock,
      });
    } catch (e) {
      throw Exception('Impossible de mettre à jour le stock');
    }
  }

  /// Get all categories (includes default categories if none exist)
  Future<List<ProductCategory>> getAllCategories() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .orderBy('name')
          .get();

      var categories = snapshot.docs
          .map((doc) => ProductCategory.fromMap(doc.id, doc.data()))
          .toList();

      if (categories.isEmpty) {
        try {
          await seedDefaultCategories();
        } catch (_) {
          return categories;
        }
        final seeded = await _firestore.collection('categories').orderBy('name').get();
        categories = seeded.docs
            .map((doc) => ProductCategory.fromMap(doc.id, doc.data()))
            .toList();
      }

      return categories;
    } catch (e) {
      throw Exception('Impossible de charger les catégories');
    }
  }

  static const defaultCategoryNames = [
    'Soins Visage & Sérums',
    'Crèmes & Hydratation',
    'Huiles & Élixirs',
    'Baumes & Soins Corps',
    'Lotions & Toniques',
    'Nettoyants & Démaquillants',
    'Masques & Gommages',
    'Soins Spécifiques',
  ];

  /// Inserts the default categories that are not already stored.
  /// Requires a signed-in admin (`categories` writes are `isAdmin()` only).
  Future<void> seedDefaultCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    final existing = snapshot.docs
        .map((doc) => (doc.data()['name'] as String?)?.trim().toLowerCase())
        .whereType<String>()
        .toSet();

    for (final name in defaultCategoryNames) {
      if (existing.contains(name.toLowerCase())) continue;
      await _firestore.collection('categories').add({'name': name});
    }
  }

  /// Add a new category
  Future<String> addCategory(String name, {String? imageUrl}) async {
    try {
      final docRef = _firestore.collection('categories').doc();

      await docRef.set({'name': name, 'imageUrl': imageUrl});

      return docRef.id;
    } catch (e) {
      throw Exception('Impossible d\'ajouter la catégorie');
    }
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    try {
      await _firestore.collection('categories').doc(id).delete();
    } catch (e) {
      throw Exception('Impossible de supprimer la catégorie');
    }
  }
}
