import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:dev_mobile/firebase_options.dart';
import 'package:dev_mobile/shared/models/models.dart';

import 'auth_errors.dart';
import 'user_service.dart';

/// Connexion, inscription et gestion du compte avec Firebase Auth.
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  UserService get _users => UserService.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─── Connexion / inscription ───────────────────────────────────────────

  Future<void> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _syncProfile(cred.user!);
  }

  /// Crée le profil s'il manque (compte créé depuis la console) et
  /// recopie l'email après un changement d'adresse validé.
  Future<void> _syncProfile(User user) async {
    final email = user.email ?? '';
    final profile = await _users.getUser(user.uid);
    if (profile == null) {
      final parts = (user.displayName ?? email.split('@').first).trim().split(
        RegExp(r'\s+'),
      );
      await _users.createProfile(
        AppUser(
          id: user.uid,
          email: email,
          firstName: parts.first,
          lastName: parts.skip(1).join(' '),
        ),
      );
    } else if (email.isNotEmpty &&
        profile.email != email &&
        !profile.disabled) {
      await _users.updateEmail(user.uid, email);
    }
  }

  /// Inscription d'un client. En cas d'échec du profil, le compte est annulé.
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? address,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    try {
      await user.updateDisplayName('${firstName.trim()} ${lastName.trim()}');
      await _users.createProfile(
        AppUser(
          id: user.uid,
          email: user.email ?? email.trim(),
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          phone: cleanOptional(phone),
          address: cleanOptional(address),
        ),
      );
    } catch (_) {
      await user.delete();
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  // ─── Mon compte (demande le mot de passe actuel) ──────────────────────

  Future<User> _reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure("Vous n'êtes pas connecté.");
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    return user;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = await _reauthenticate(currentPassword);
    await user.updatePassword(newPassword);
  }

  /// Envoie un lien de vérification à la nouvelle adresse.
  /// L'email ne change qu'après le clic ; Firestore est mis à jour
  /// à la connexion suivante (voir [_syncProfile]).
  Future<void> changeEmail({
    required String password,
    required String newEmail,
  }) async {
    final user = await _reauthenticate(password);
    await user.verifyBeforeUpdateEmail(newEmail.trim());
  }

  /// Supprime définitivement le profil puis le compte de connexion.
  Future<void> deleteAccount(String password) async {
    final user = await _reauthenticate(password);
    await _users.deleteProfile(user.uid);
    await user.delete();
  }

  // ─── Admin ─────────────────────────────────────────────────────────────

  static const _secondaryAppName = 'adminUserCreation';

  /// Instance Firebase secondaire : créer un compte avec l'instance
  /// principale connecterait le nouvel utilisateur à la place de l'admin.
  Future<FirebaseApp> _secondaryApp() async {
    for (final app in Firebase.apps) {
      if (app.name == _secondaryAppName) return app;
    }
    return Firebase.initializeApp(
      name: _secondaryAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  /// Un admin crée un compte (client ou admin) sans être déconnecté.
  Future<void> createUserAsAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? phone,
    String? address,
    bool sendPasswordResetEmail = false,
  }) async {
    final auth = FirebaseAuth.instanceFor(app: await _secondaryApp());
    final cred = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    try {
      await user.updateDisplayName('${firstName.trim()} ${lastName.trim()}');
      // Écrit avec l'instance principale : ce sont les droits de l'admin.
      await _users.createProfile(
        AppUser(
          id: user.uid,
          email: user.email ?? email.trim(),
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          role: role,
          phone: cleanOptional(phone),
          address: cleanOptional(address),
        ),
      );
    } catch (_) {
      try {
        await user.delete();
      } catch (_) {}
      rethrow;
    } finally {
      await auth.signOut();
    }
    if (sendPasswordResetEmail) await sendPasswordReset(email);
  }
}
