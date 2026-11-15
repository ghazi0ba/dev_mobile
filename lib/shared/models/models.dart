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
    required this.firstName,
    required this.lastName,
    this.role = UserRole.client,
    this.phone,
    this.address,
    this.photoUrl,
    this.photoPublicId,
    this.createdAt,
    this.disabled = false,
  });

  final String id;
  final String email;
  final String firstName; // prénom
  final String lastName; // nom
  final UserRole role;
  final String? phone;
  final String? address;

  /// Photo de profil hébergée sur Cloudinary (null : on affiche les initiales).
  final String? photoUrl;

  /// Identifiant Cloudinary de la photo (utile pour la supprimer plus tard).
  final String? photoPublicId;
  final DateTime? createdAt;

  /// Compte désactivé par un admin : l'utilisateur ne peut plus utiliser l'app.
  final bool disabled;

  /// "Prénom Nom" : à utiliser pour l'affichage (ex. userName d'un avis).
  String get fullName => '$firstName $lastName'.trim();

  bool get isAdmin => role == UserRole.admin;
  bool get hasPhoto => (photoUrl ?? '').isNotEmpty;

  AppUser copyWith({
    String? email,
    String? firstName,
    String? lastName,
    UserRole? role,
    String? phone,
    String? address,
    String? photoUrl,
    String? photoPublicId,
    bool? disabled,
  }) => AppUser(
    id: id,
    email: email ?? this.email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    role: role ?? this.role,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    photoUrl: photoUrl ?? this.photoUrl,
    photoPublicId: photoPublicId ?? this.photoPublicId,
    createdAt: createdAt,
    disabled: disabled ?? this.disabled,
  );

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    var first = map['firstName'] as String?;
    var last = map['lastName'] as String?;
    // Anciens documents : seulement "fullName" → on le découpe.
    if (first == null && last == null) {
      final parts = (map['fullName'] as String? ?? '').trim().split(
        RegExp(r'\s+'),
      );
      first = parts.first;
      last = parts.skip(1).join(' ');
    }
    return AppUser(
      id: id,
      email: map['email'] as String? ?? '',
      firstName: first ?? '',
      lastName: last ?? '',
      role: map['role'] == 'admin' ? UserRole.admin : UserRole.client,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      photoUrl: map['photoUrl'] as String?,
      photoPublicId: map['photoPublicId'] as String?,
      createdAt: _toDate(map['createdAt']),
      disabled: map['disabled'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'fullName': fullName, // copie pratique pour la console / les autres modules
    'role': role.name,
    'phone': phone,
    'address': address,
    'photoUrl': photoUrl,
    'photoPublicId': photoPublicId,
    'createdAt': createdAt ?? DateTime.now(),
    'disabled': disabled,
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

  final String id;
  final String name;
  final double price; // en euros
  final int stock; // unités disponibles
  final String categoryId;
  final String sku; // ex. SKU-8402
  final String brand;
  final String description;
  final String composition;
  final String volume; // ex. "30 ml"
  final String? imageUrl;
  final List<String> labels; // "bio", "vegan", "naturel"
  final double ratingAverage; // mis à jour par le module Avis
  final int ratingCount;
  final DateTime? createdAt;

  /// Seuil sous lequel le stock est "en alerte".
  static const lowStockThreshold = 10;

  bool get inStock => stock > 0;
  bool get lowStock => stock > 0 && stock <= lowStockThreshold;

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
