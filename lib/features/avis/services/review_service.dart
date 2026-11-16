import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dev_mobile/shared/models/models.dart';

class ReviewService {
  ReviewService._();
  static final _firestore = FirebaseFirestore.instance;
  static CollectionReference get _collection => _firestore.collection('reviews');

  /// Récupère tous les avis d'un produit
  static Future<List<Review>> getReviewsByProduct(String productId) async {
    final snapshot = await _collection
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Review.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Récupère l'avis d'un utilisateur pour un produit spécifique
  static Future<Review?> getUserReviewForProduct(String productId, String userId) async {
    final snapshot = await _collection
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Review.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// Ajoute un nouvel avis
  static Future<String> addReview(Review review) async {
    final docRef = await _collection.add(review.toMap());
    await _updateProductRating(review.productId);
    return docRef.id;
  }

  /// Met à jour un avis existant
  static Future<void> updateReview(String reviewId, Map<String, dynamic> data) async {
    await _collection.doc(reviewId).update(data);
    // La note a pu changer : on recalcule la moyenne du produit.
    final doc = await _collection.doc(reviewId).get();
    final productId = (doc.data() as Map<String, dynamic>?)?['productId'];
    if (productId is String && productId.isNotEmpty) {
      await _updateProductRating(productId);
    }
  }

  /// Supprime un avis
  static Future<void> deleteReview(String reviewId, String productId) async {
    await _collection.doc(reviewId).delete();
    await _updateProductRating(productId);
  }

  /// Met à jour la moyenne et le compte des notes d'un produit
  static Future<void> _updateProductRating(String productId) async {
    final reviewsSnapshot = await _collection
        .where('productId', isEqualTo: productId)
        .get();

    if (reviewsSnapshot.docs.isEmpty) {
      await _firestore.collection('products').doc(productId).update({
        'ratingAverage': 0.0,
        'ratingCount': 0,
      });
      return;
    }

    final ratings = reviewsSnapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['rating'] as int)
        .toList();

    final average = ratings.reduce((a, b) => a + b) / ratings.length;

    await _firestore.collection('products').doc(productId).update({
      'ratingAverage': average,
      'ratingCount': ratings.length,
    });
  }

  /// Tous les avis, les plus récents d'abord (modération admin).
  static Stream<List<Review>> watchAllReviews() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Review.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

    /// Stream des avis d'un produit (pour mise à jour en temps réel)
  static Stream<List<Review>> watchReviewsByProduct(String productId) {
    return _collection
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Review.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Stream de l'avis de l'utilisateur pour un produit
  static Stream<Review?> watchUserReviewForProduct(String productId, String userId) {
    return _collection
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return Review.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    });
  }
}