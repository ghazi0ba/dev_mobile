// Modèles de données partagés entre les modules.
// Ils correspondent aux collections Firestore décrites dans docs/EQUIPE.md.
//
// Règle d'équipe : chaque modèle a un propriétaire (voir docs/EQUIPE.md).
// Pour ajouter ou renommer un champ, prévenez le groupe avant de le pousser,
// car d'autres modules lisent ces données.

/// Convertit un Timestamp Firestore (ou un DateTime) en DateTime.
DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return value.toDate() as DateTime; // Timestamp de cloud_firestore
}

double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

// ─── Utilisateurs (propriétaire : module Utilisateurs) ──────────────────────

enum UserRole { client, admin }

/// Collection `users/{uid}` (uid = identifiant Firebase Auth).
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = UserRole.client,
    this.phone,
    this.address,
    this.photoUrl,
    this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? phone;
  final String? address;
  final String? photoUrl;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) => AppUser(
    id: id,
    email: map['email'] as String? ?? '',
    fullName: map['fullName'] as String? ?? '',
    role: map['role'] == 'admin' ? UserRole.admin : UserRole.client,
    phone: map['phone'] as String?,
    address: map['address'] as String?,
    photoUrl: map['photoUrl'] as String?,
    createdAt: _toDate(map['createdAt']),
  );

  Map<String, dynamic> toMap() => {
    'email': email,
    'fullName': fullName,
    'role': role.name,
    'phone': phone,
    'address': address,
    'photoUrl': photoUrl,
    'createdAt': createdAt ?? DateTime.now(),
  };
}

// ─── Produits & catégories (propriétaire : module Produits) ─────────────────

/// Collection `categories/{id}`.
class ProductCategory {
  const ProductCategory({required this.id, required this.name, this.imageUrl});

  final String id;
  final String name;
  final String? imageUrl;

  factory ProductCategory.fromMap(String id, Map<String, dynamic> map) =>
      ProductCategory(
        id: id,
        name: map['name'] as String? ?? '',
        imageUrl: map['imageUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {'name': name, 'imageUrl': imageUrl};
}

/// Collection `products/{id}`.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.categoryId,
    this.sku = '',
    this.brand = '',
    this.description = '',
    this.composition = '',
    this.volume = '',
    this.imageUrl,
    this.labels = const [],
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.createdAt,
  });

  final String id; // Firestore document ID (not stored inside the document)
  final String name; // Required
  final double price; // Required (en euros)
  final int stock; // Required (unités disponibles)
  final String categoryId; // Required (ID of a document in categories)
  final String sku; // Optional, ex. "SKU-8402", default ""
  final String brand; // Optional, brand name as text, e.g. "Aura Botanica"
  final String description; // Optional
  final String composition; // Optional (ingredients)
  final String volume; // Optional, ex. "30 ml"
  final String? imageUrl; // Optional (Image URL from Cloudinary), can be empty
  final List<String> labels; // Optional, ["bio", "vegan", "naturel"]
  final double ratingAverage; // Average rating, updated by Avis module
  final int ratingCount; // Number of reviews
  final DateTime? createdAt; // Creation date

  /// Seuil sous lequel le stock est "en alerte".
  static const lowStockThreshold = 10;

  bool get inStock => stock > 0;
  bool get lowStock => stock > 0 && stock <= lowStockThreshold;
  bool get isOutOfStock => stock == 0;

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
    id: id,
    name: map['name'] as String? ?? '',
    price: _toDouble(map['price']),
    stock: _toInt(map['stock']),
    categoryId: map['categoryId'] as String? ?? '',
    sku: map['sku'] as String? ?? '',
    brand: map['brand'] as String? ?? '',
    description: map['description'] as String? ?? '',
    composition: map['composition'] as String? ?? '',
    volume: map['volume'] as String? ?? '',
    imageUrl: map['imageUrl'] as String?,
    labels: List<String>.from(map['labels'] as List? ?? const []),
    ratingAverage: _toDouble(map['ratingAverage']),
    ratingCount: _toInt(map['ratingCount']),
    createdAt: _toDate(map['createdAt']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'stock': stock,
    'categoryId': categoryId,
    'sku': sku,
    'brand': brand,
    'description': description,
    'composition': composition,
    'volume': volume,
    'imageUrl': imageUrl,
    'labels': labels,
    'ratingAverage': ratingAverage,
    'ratingCount': ratingCount,
    'createdAt': createdAt ?? DateTime.now(),
  };

  /// Create a copy with updated fields
  Product copyWith({
    String? id,
    String? name,
    double? price,
    int? stock,
    String? categoryId,
    String? sku,
    String? brand,
    String? description,
    String? composition,
    String? volume,
    String? imageUrl,
    List<String>? labels,
    double? ratingAverage,
    int? ratingCount,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      categoryId: categoryId ?? this.categoryId,
      sku: sku ?? this.sku,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      composition: composition ?? this.composition,
      volume: volume ?? this.volume,
      imageUrl: imageUrl ?? this.imageUrl,
      labels: labels ?? this.labels,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ─── Panier (propriétaire : module Panier) ──────────────────────────────────

/// Sous-collection `carts/{uid}/items/{productId}`.
/// Le prix n'est PAS stocké ici : on le relit toujours depuis `products`.
class CartItem {
  const CartItem({
    required this.productId,
    required this.quantity,
    this.addedAt,
  });

  final String productId;
  final int quantity;
  final DateTime? addedAt;

  factory CartItem.fromMap(String productId, Map<String, dynamic> map) =>
      CartItem(
        productId: productId,
        quantity: _toInt(map['quantity']),
        addedAt: _toDate(map['addedAt']),
      );

  Map<String, dynamic> toMap() => {
    'quantity': quantity,
    'addedAt': addedAt ?? DateTime.now(),
  };
}

// ─── Commandes (propriétaire : module Commandes) ────────────────────────────

enum OrderStatus { enAttente, confirmee, expediee, livree, annulee }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.enAttente => 'En attente',
    OrderStatus.confirmee => 'Confirmée',
    OrderStatus.expediee => 'Expédiée',
    OrderStatus.livree => 'Livrée',
    OrderStatus.annulee => 'Annulée',
  };
}

/// Ligne de commande : copie du produit au moment de l'achat
/// (le prix ne doit pas changer si le produit est modifié ensuite).
class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final String? imageUrl;

  double get total => unitPrice * quantity;

  factory OrderLine.fromMap(Map<String, dynamic> map) => OrderLine(
    productId: map['productId'] as String? ?? '',
    name: map['name'] as String? ?? '',
    unitPrice: _toDouble(map['unitPrice']),
    quantity: _toInt(map['quantity']),
    imageUrl: map['imageUrl'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'imageUrl': imageUrl,
  };
}

/// Collection `orders/{id}`.
class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.userId,
    required this.lines,
    required this.total,
    required this.shippingAddress,
    this.status = OrderStatus.enAttente,
    this.paymentMethod = 'livraison', // paiement à la livraison
    this.createdAt,
  });

  final String id;
  final String userId;
  final List<OrderLine> lines;
  final double total;
  final String shippingAddress;
  final OrderStatus status;
  final String paymentMethod;
  final DateTime? createdAt;

  factory CustomerOrder.fromMap(String id, Map<String, dynamic> map) =>
      CustomerOrder(
        id: id,
        userId: map['userId'] as String? ?? '',
        lines: (map['lines'] as List? ?? const [])
            .map((e) => OrderLine.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: _toDouble(map['total']),
        shippingAddress: map['shippingAddress'] as String? ?? '',
        status: OrderStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => OrderStatus.enAttente,
        ),
        paymentMethod: map['paymentMethod'] as String? ?? 'livraison',
        createdAt: _toDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'lines': lines.map((l) => l.toMap()).toList(),
    'total': total,
    'shippingAddress': shippingAddress,
    'status': status.name,
    'paymentMethod': paymentMethod,
    'createdAt': createdAt ?? DateTime.now(),
  };
}

// ─── Avis (propriétaire : module Avis) ──────────────────────────────────────

/// Collection `reviews/{id}`.
class Review {
  const Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    this.comment = '',
    this.createdAt,
  });

  final String id;
  final String productId;
  final String userId;
  final String userName;
  final int rating; // 1 à 5
  final String comment;
  final DateTime? createdAt;

  factory Review.fromMap(String id, Map<String, dynamic> map) => Review(
    id: id,
    productId: map['productId'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    userName: map['userName'] as String? ?? '',
    rating: _toInt(map['rating']),
    comment: map['comment'] as String? ?? '',
    createdAt: _toDate(map['createdAt']),
  );

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'userId': userId,
    'userName': userName,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt ?? DateTime.now(),
  };
}
