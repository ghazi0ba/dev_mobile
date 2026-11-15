# CosmaPlus : guide de l'équipe

## 1. Qui fait quoi

| Module | Dossier | Responsable | Possède les collections Firestore |
|---|---|---|---|
| Utilisateurs | `lib/features/utilisateurs/` | _(nom)_ | `users` |
| Produits | `lib/features/produits/` | _(nom)_ | `products`, `categories` |
| Commandes | `lib/features/commandes/` | _(nom)_ | `orders` |
| Panier | `lib/features/panier/` | _(nom)_ | `carts` |
| Avis | `lib/features/avis/` | _(nom)_ | `reviews` |

**Règle d'or : chacun ne modifie que son dossier.** Ça évite presque tous les conflits Git.
Les fichiers partagés (`lib/core/`, `lib/shared/`, `lib/app/`, `lib/main.dart`, `pubspec.yaml`) se modifient seulement après en avoir parlé au groupe.

## 2. Structure du code

```
lib/
├── main.dart                 # démarrage + Firebase (ne pas toucher)
├── app/
│   ├── shells.dart           # barres de navigation admin / client
│   ├── home_screen.dart      # tableau de bord : écran d'exemple du thème
│   └── dev_launcher.dart     # écran temporaire pour choisir admin/client
├── core/
│   ├── theme/                # couleurs et thème (AppColors, AppTheme, AppSpacing)
│   └── widgets/              # composants partagés (AppHeader, SectionCard, StatusBadge…)
├── shared/models/models.dart # modèles de données communs
└── features/<module>/
    ├── screens/              # vos écrans
    ├── widgets/              # vos composants propres au module
    └── services/             # accès à Firestore (lecture / écriture)
```

## 3. Utiliser le thème

Un seul import donne accès au thème et aux composants :

```dart
import 'package:dev_mobile/core/widgets/widgets.dart';
```

| Besoin | À utiliser |
|---|---|
| En-tête "CosmaPlus / SOUS-TITRE" | `AppHeader(subtitle: 'Produits')` |
| Bouton principal (terracotta) | `FilledButton(...)` |
| Bouton secondaire (beige) | `OutlinedButton(...)` |
| Champ de saisie | `TextFormField(decoration: InputDecoration(hintText: ...))` : le style est automatique |
| Bloc blanc avec titre | `SectionCard(title: 'Prix & Inventaire', icon: ..., child: ...)` |
| Étiquette "Disponible", "Rupture"… | `StatusBadge('Disponible', tone: BadgeTone.success, showDot: true)` |
| Carte de chiffre clé | `StatCard(label: ..., value: ..., icon: ...)` |
| Confirmation de suppression | `await showConfirmDialog(context, ..., destructive: true)` |
| Titre en police serif | `Theme.of(context).textTheme.titleLarge` ou `AppTheme.serif(size: 22)` |
| Couleurs | `AppColors.primary`, `AppColors.success`… |
| Marges | `AppSpacing.md` (16), `AppSpacing.lg` (24)… |

**Ne mettez jamais de couleur ou de police en dur** (`Color(0xFF...)`, `fontFamily: ...`) dans vos écrans. Si une couleur manque, on l'ajoute dans `AppColors`.

`lib/app/home_screen.dart` et `lib/features/utilisateurs/screens/login_screen.dart` sont deux écrans complets à prendre comme modèles.

## 4. Base de données Firestore

Les modèles Dart correspondants sont dans `lib/shared/models/models.dart`.

```
users/{uid}
  email, firstName, lastName, fullName (copie "Prénom Nom", calculée),
  role ("client" | "admin"), phone, address, createdAt,
  photoUrl (Cloudinary, null = initiales), photoPublicId,
  disabled (bool : compte désactivé par un admin)

categories/{id}
  name, imageUrl

products/{id}
  name, price, stock, categoryId, sku, brand, description, composition,
  volume, imageUrl, labels ["bio","vegan","naturel"],
  ratingAverage, ratingCount, createdAt

carts/{uid}/items/{productId}
  quantity, addedAt            # pas de prix : on le relit dans products

orders/{id}
  userId, lines [{productId, name, unitPrice, quantity, imageUrl}],
  total, shippingAddress, customerName, customerEmail, customerPhone, note,
  status, paymentMethod ("livraison"), stockReserved,
  history [{status, at, by ("client" | "admin")}], createdAt, updatedAt
  status : "enAttente" | "confirmee" | "expediee" | "livree" | "annulee"

reviews/{id}
  productId, userId, userName, rating (1-5), comment, createdAt
```

## 5. Ce que les modules s'échangent

Mettez-vous d'accord tôt sur ces points de contact :

- **Produits → Panier** : la fiche produit affiche un bouton « Ajouter au panier » fourni par le module Panier (ex. widget `AddToCartButton(productId: ...)` dans `features/panier/widgets/`).
- **Produits → Avis** : la fiche produit affiche les avis via un widget du module Avis (ex. `ProductReviews(productId: ...)` dans `features/avis/widgets/`).
- **Panier → Commandes** : le panier est stocké dans `carts/{uid}/items/{productId}` avec un champ `quantity` (entier). Le bouton « Commander » du panier ouvre simplement :
  ```dart
  import 'package:dev_mobile/features/commandes/screens/checkout_screen.dart';

  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CheckoutScreen()),
  );
  ```
  L'écran relit le panier, les prix et le stock dans Firestore, et vide les articles commandés une fois la commande passée.
- **Commandes → Produits** : le stock n'est **pas** retiré quand le client commande, mais quand l'**admin confirme** la commande (transaction Firestore). Il est remis en stock si une commande confirmée ou expédiée est annulée. Champs produits utilisés : `name`, `price`, `stock`, `imageUrl`.
- **Avis → Produits** : après un nouvel avis, `ratingAverage` et `ratingCount` du produit sont mis à jour.
- **Utilisateurs → tous** : fournit l'utilisateur connecté (voir section 5 bis).

Tant qu'un widget d'un autre module n'existe pas, mettez un simple bouton ou texte temporaire avec `// TODO`.

## 5 bis. Utilisateur connecté et sécurité

L'app démarre sur `AuthGate` : écran de connexion, puis espace admin ou client selon le rôle.

```dart
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';

final user = CurrentUser.of(context);      // AppUser : user.id, user.fullName, user.isAdmin…
final maybe = CurrentUser.maybeOf(context); // null si personne n'est connecté
```

Utilisez `user.id` comme `userId` (commandes, avis, panier `carts/{user.id}`).
Avatar (photo ou initiales) : `UserAvatar(user: user)` dans `features/utilisateurs/widgets/user_avatar.dart`.

**Images (Cloudinary)** : `CloudinaryService.instance.uploadImage(bytes, folder: 'cosmaplus/products')`
dans `lib/core/services/cloudinary_service.dart` retourne l'URL à enregistrer (ex. `imageUrl` d'un produit).
Configuration (cloud name + preset non signé) : voir `docs/UTILISATEURS.md`, section 9.
Détails complets du module Utilisateurs : `docs/UTILISATEURS.md`.

**Comptes de test** : créez un compte depuis l'écran « Créer un compte ». Pour devenir admin,
mettez `role: "admin"` sur votre document `users/{uid}` dans la console Firestore
(ou demandez à un admin de vous nommer depuis « Gestion des utilisateurs »).

**Mode développement** (debug uniquement) : lien sous le formulaire de connexion pour ouvrir
les espaces sans se connecter. Attention : sans connexion, Firestore refuse les lectures.

**Règles Firestore** : fichier `firestore.rules` à la racine. Chaque module complète le bloc
de sa collection (les règles actuelles des autres modules sont provisoires : « tout utilisateur
actif »). Déployer : `firebase deploy --only firestore:rules --project projetmobile-4csde2`
ou copier-coller dans la console (Firestore > Règles).

## 6. Travailler avec Git

```bash
git checkout main
git pull                                # toujours partir de la dernière version
git checkout -b feature/produits-liste  # une branche par tâche
# ... coder ...
flutter analyze                         # aucune erreur avant de pousser
git add .
git commit -m "Produits : liste avec filtres"
git push -u origin feature/produits-liste
```

Puis ouvrez une **Pull Request** vers `main` sur GitHub ; un autre membre la relit avant le merge.

- Faites des Pull Requests petites et fréquentes (une fonctionnalité à la fois).
- Si vous ajoutez un package (`flutter pub add ...`), prévenez le groupe : `pubspec.yaml` est partagé.
- Avant de commencer chaque jour : `git checkout main && git pull`, puis `git merge main` dans votre branche.
