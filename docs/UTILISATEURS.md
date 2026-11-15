# Users module (Utilisateurs)

This module handles everything about accounts in CosmaPlus:

- signing up, signing in and signing out
- each user managing their own profile
- admins managing every account

It runs entirely on Firebase (Authentication + Firestore), so there is no custom server or API.

> Folder: `lib/features/utilisateurs/`. Firestore collection: `users`.

---

## 1. What each role can do

| Action | Visitor | Client | Admin |
|---|:-:|:-:|:-:|
| Create an account (always as a client) | ✅ | | |
| Sign in / reset a forgotten password | ✅ | | |
| View own profile | | ✅ | ✅ |
| Edit own name, phone, address | | ✅ | ✅ |
| Change own password / email | | ✅ | ✅ |
| Delete own account | | ✅ | ✅ |
| Sign out | | ✅ | ✅ |
| List, search and filter all users | | | ✅ |
| Edit any user's name, phone, address | | | ✅ |
| Change a user's role (client ⇄ admin) | | | ✅ (not their own) |
| Disable / re-enable an account | | | ✅ (not their own) |
| Send a password-reset email to a user | | | ✅ |
| Create an account (client or admin) | | | ✅ |

An admin can't change their own role or disable themselves. Without that rule, the last admin could lock everyone out.

---

## 2. How the app decides what to show

When the app starts, it shows `AuthGate`. `AuthGate` reads the current session and picks a screen:

```
App start
   │
   ▼
SessionScope  ── listens to Firebase Auth + the users/{uid} document (live)
   │
   ▼
AuthGate
   ├─ loading                → spinner
   ├─ signed out             → LoginScreen  (⇄ SignupScreen)
   ├─ profile missing        → spinner, then "Profil introuvable" after 4 s
   ├─ profile.disabled=true  → "Compte désactivé" screen
   ├─ role = admin           → AdminShell  (Accueil · Produits · Commandes · Avis · Menu)
   └─ role = client          → ClientShell (Boutique · Panier · Commandes · Profil)
```

The session is **live**. If an admin changes your role or disables your account while you're using the app, your screen switches right away. Whenever the user moves to a different area (sign in, sign out, role change, account disabled), `AuthGate` also closes any screens that were open on top.

### Why `SessionScope` sits above `MaterialApp`

Screens opened with `Navigator.push` don't sit inside `AuthGate`. Putting `SessionScope` above `MaterialApp` (in `main.dart`) means **every** screen can read the signed-in user.

---

## 3. Using the signed-in user from another module

```dart
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';

final user = CurrentUser.of(context);       // AppUser (throws if nobody is signed in)
final maybe = CurrentUser.maybeOf(context); // AppUser? (null if signed out)

user.id        // use as userId in orders, reviews, carts/{user.id}
user.fullName  // e.g. userName in a review
user.isAdmin   // show/hide admin-only buttons
```

The widget rebuilds automatically when the profile changes, for example after the user renames themselves.

---

## 4. Data model

### Firestore document `users/{uid}`

`uid` is the Firebase Authentication user id.

| Field | Type | Notes |
|---|---|---|
| `email` | string | Copy of the login email (kept in sync, see §6.3) |
| `fullName` | string | Required, at least 2 characters |
| `role` | `"client"` \| `"admin"` | Sign-up always gives `client` |
| `phone` | string \| null | Optional. Empty fields are stored as `null` |
| `address` | string \| null | Optional delivery address |
| `photoUrl` | string \| null | Not used yet (avatars show initials) |
| `createdAt` | timestamp | Set by the server (`FieldValue.serverTimestamp()`) |
| `disabled` | bool | `true` = blocked by an admin |

### Dart model

`AppUser` in `lib/shared/models/models.dart` provides:

- `fromMap(id, map)` and `toMap()` to convert to and from Firestore
- `isAdmin`
- `copyWith(...)`

Passwords are **never** stored in Firestore. Firebase Authentication handles them.

---

## 5. File map

```
lib/features/utilisateurs/
├── services/
│   ├── auth_service.dart      Firebase Auth: sign in/up/out, reset, reauth,
│   │                          change password/email, delete self, admin create user
│   ├── user_service.dart      Firestore users collection: read/watch/update/role/disable
│   ├── user_filter.dart       Search + filters + sorting (pure Dart, unit-tested)
│   └── auth_errors.dart       Firebase error codes → French messages
├── widgets/
│   ├── current_user_scope.dart  SessionScope + CurrentUser (signed-in user everywhere)
│   ├── user_avatar.dart         Initials avatar, RoleBadge, AccountStatusBadge
│   ├── user_filter_sheet.dart   "Filtres avancés" bottom sheet
│   └── form_helpers.dart        Validators, BusyButton, ErrorBanner, PasswordField,
│                                askPassword dialog, formatDate, showMessage
└── screens/
    ├── auth_gate.dart           Routing by session (+ disabled / missing-profile screens)
    ├── login_screen.dart        Sign in, forgot password, link to sign up, dev mode (debug)
    ├── signup_screen.dart       Create a client account
    ├── account_screen.dart      My profile (Profil tab for clients, Menu tab for admins)
    ├── profile_form_screen.dart Edit name / phone / address (self or admin)
    ├── change_password_screen.dart
    ├── change_email_screen.dart
    └── admin/
        ├── user_list_screen.dart    List + advanced search + filters
        ├── user_detail_screen.dart  User page: edit, role, disable, reset email
        └── create_user_screen.dart  Create a client or admin account
```

The **services** are the only files that talk to Firebase. Screens call the services and show the results.

---

## 6. How each feature works

### 6.1 Sign up

1. `createUserWithEmailAndPassword` creates the Firebase login, and the user is signed in automatically.
2. The display name is set, and `users/{uid}` is created with `role: client` and `disabled: false`.
3. If step 2 fails, the login from step 1 is **deleted** so that no account is left without a profile.
4. `AuthGate` sees the new session and opens the client area.

### 6.2 Sign in

1. `signInWithEmailAndPassword`.
2. **Profile sync:**
   - If `users/{uid}` doesn't exist (for example, the account was created by hand in the console), it's created as a client.
   - If the login email differs from the stored email (after an email change), the stored email is updated.
3. `AuthGate` opens the right area for the role, or the "Compte désactivé" screen.

**Forgot password:** a dialog asks for the email and calls `sendPasswordResetEmail`. For privacy, the message is the same whether or not the account exists.

### 6.3 Changing password or email (requires the current password)

Firebase only allows sensitive changes after a recent sign-in, so the app asks for the current password first (`reauthenticateWithCredential`).

- **Password:** after reauthenticating, `updatePassword`. The new password must be different from the old one.
- **Email:** after reauthenticating, `verifyBeforeUpdateEmail(newEmail)`. Firebase emails a link to the **new** address, and the change only happens once that link is clicked. The user then signs in with the new email, and the sign-in sync (6.2) copies it into Firestore.

### 6.4 Deleting my account

There's a confirmation dialog, then a password prompt. The app then:

1. deletes `users/{uid}`
2. deletes the Firebase login

The profile goes first because, once the login is deleted, the app no longer has permission to delete the document. Past orders and reviews keep their `userId`, since the shop still needs those records.

### 6.5 Admin: creating an account

Creating a user with the normal Firebase instance would **sign the admin out** and sign the new user in. To avoid that, `AuthService` starts a **second, hidden Firebase app** (`adminUserCreation`):

1. The second instance creates the login.
2. The **main** instance, signed in as the admin, writes `users/{uid}` with the chosen role. This works because the security rules allow admins to do it.
3. The second instance signs out.
4. Optionally, a password-reset email goes to the new user so they choose their own password. That way the admin never has to share the temporary password.

If writing the profile fails, the new login is deleted.

### 6.6 Admin: disabling an account

On the free Firebase plan, the app **cannot** delete or block another person's login (that needs Cloud Functions, which are paid). So "deleting" a user from the admin side means setting `disabled: true`, which has two effects:

- **In the app:** `AuthGate` immediately shows the "Compte désactivé" screen, even if the user is in the middle of using the app.
- **In the database:** the security rules treat the user as inactive, so they can't read or write data even with a modified app.

The admin can re-enable the account at any time.

---

## 7. Admin search and filters

**Where:** Menu → Administration → Gestion des utilisateurs.

| Feature | Details |
|---|---|
| **Search bar** | Searches name, email, phone and address at the same time. Ignores case and accents (`eric` finds `Éric`). Several words must **all** match (`nadia tunis`). Phone numbers match with or without spaces (`0612` finds `06 12 34 56 78`). |
| **Role chips** | Tous / Clients / Admins, each with a count |
| **Status chips** | Actifs / Désactivés, each with a count. Tap again to turn off. |
| **Advanced filters** (⚙ button, the badge shows how many are on) | **Sort:** name A→Z / Z→A, newest, oldest, email. **Profile:** complete / no phone / no address. **Sign-up date:** a date range (both ends included). |
| **Active filter chips** | Each advanced filter shows as a chip you can remove with ✕ |
| **Result bar** | "12 sur 40 utilisateurs" + **Réinitialiser** |
| **Empty state** | Message plus a button to reset the filters |

All filtering happens in the app on the live list (`UserFilter.apply`). Firestore has no full-text search, and a shop's user list is small enough for this approach.

---

## 8. Security rules (`firestore.rules`)

The rules are the real protection. Hiding a button in the app isn't enough, because anyone could call Firestore directly.

**Helper functions:**

| Function | Meaning |
|---|---|
| `signedIn()` | A Firebase login is present |
| `isSelf(uid)` | The document belongs to the signed-in user |
| `isActive()` | Signed in, has a profile, and `disabled` is not `true` |
| `isAdmin()` | Active **and** `role == 'admin'` |

**Rules on `users/{uid}`:**

| Operation | Who is allowed |
|---|---|
| read | the user themselves, or an admin |
| create | an admin (any role), or the user themselves **only** with `role: client` and `disabled: false` |
| update | an admin (anything), or the user themselves if active **and** not touching `role`, `disabled` or `createdAt` |
| delete | the user themselves, or an admin |

As a result, a client cannot make themselves admin, re-enable their own account, or read other people's profiles.

The other collections (`products`, `orders`, `carts`, `reviews`, `categories`) have **temporary** rules ("any active user"). Each module owner should tighten their own block. For example, `products` writes should be admin-only.

**Deploying the rules:** use either option.
- Copy-paste the file into the Firebase console (Firestore → Rules → Publish).
- Run `firebase deploy --only firestore:rules --project projetmobile-4csde2`.

---

## 9. Setup (one time, Firebase console)

1. **Authentication → Sign-in method:** enable **Email/Password**.
2. **Firestore Database:** create it if it doesn't exist.
3. **Deploy the rules** (section 8).
4. **First admin:** sign up in the app, then in Firestore open `users/{your uid}` and set `role` to `"admin"`. After that, admins can promote others from the app.
5. *(Optional)* **Authentication → Templates:** translate the reset and verification emails into French.

---

## 10. Developing and testing

- **Dev mode** (debug builds only): the link under the login form opens `DevLauncher` to browse the admin or client area without signing in. Firestore will refuse reads in this mode, so to test with real data, sign in with a test account.
- **Tests:** `test/utilisateurs_test.dart` covers the `AppUser` model, initials, validators, error messages and every search, filter and sort case. Run them with:
  ```bash
  flutter test
  ```
- **Before pushing:** `flutter analyze` and `flutter test` must pass.

---

## 11. Common errors

| Message shown | Cause / fix |
|---|---|
| "Email ou mot de passe incorrect." | Wrong credentials. Firebase deliberately doesn't say which one is wrong. |
| "Ce mode de connexion n'est pas activé dans Firebase." | Email/Password isn't enabled (setup step 1). |
| "Vous n'avez pas les droits pour cette action." | The rules aren't deployed, or the user isn't admin / is disabled. |
| "Un compte existe déjà avec cet email." | Sign in instead, or use "Mot de passe oublié". |
| "Trop de tentatives…" | Firebase temporarily blocked repeated failures. Wait a few minutes. |
| "Profil introuvable" screen | The `users/{uid}` document is missing and couldn't be created. Check the connection and the rules, then sign in again. |
| Admin list empty or showing an error | The rules weren't deployed, or your profile doesn't have `role: "admin"`. |

---

## 12. Known limitations

- **Disabling doesn't remove the login.** A disabled user's login still exists, but the app and the rules block them. A full delete would need Cloud Functions (the paid Blaze plan).
- **No profile photos.** Avatars show initials because Firebase Storage needs the Blaze plan. The `photoUrl` field is ready for later.
- **Date picker in English.** The month names come out in English until `flutter_localizations` is added to the project.
- **Whole collection loaded.** The admin list loads every user, which is fine for a shop's size. With thousands of users it would need paging and server-side queries.
