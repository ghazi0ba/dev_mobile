import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import 'package:dev_mobile/shared/models/models.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';

enum SessionStatus { loading, signedOut, missingProfile, ready }

/// Suit la connexion Firebase et le profil `users/{uid}` en temps réel.
/// Placé au-dessus de MaterialApp (main.dart) : tous les écrans y ont accès.
class SessionScope extends StatefulWidget {
  const SessionScope({super.key, required this.child});
  final Widget child;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;
  SessionStatus _status = SessionStatus.loading;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _authSub = AuthService.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? authUser) {
    _profileSub?.cancel();
    _profileSub = null;
    if (authUser == null) {
      _set(SessionStatus.signedOut, null);
      return;
    }
    _set(SessionStatus.loading, null);
    _profileSub = UserService.instance
        .watchUser(authUser.uid)
        .listen(
          (profile) => _set(
            profile == null
                ? SessionStatus.missingProfile
                : SessionStatus.ready,
            profile,
          ),
          onError: (Object _) {
            if (AuthService.instance.currentUser != null) {
              _set(SessionStatus.missingProfile, null);
            }
          },
        );
  }

  void _set(SessionStatus status, AppUser? user) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _user = user;
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CurrentUser._(status: _status, user: _user, child: widget.child);
}

/// Accès à l'utilisateur connecté depuis n'importe quel écran :
///
/// ```dart
/// final user = CurrentUser.of(context); // AppUser (id, fullName, isAdmin…)
/// final maybe = CurrentUser.maybeOf(context); // null si personne n'est connecté
/// ```
class CurrentUser extends InheritedWidget {
  const CurrentUser._({
    required this.status,
    required this.user,
    required super.child,
  });

  final SessionStatus status;
  final AppUser? user;

  static CurrentUser? _scope(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrentUser>();

  static AppUser? maybeOf(BuildContext context) => _scope(context)?.user;

  static AppUser of(BuildContext context) {
    final user = maybeOf(context);
    if (user == null) {
      throw FlutterError(
        'CurrentUser.of() : aucun utilisateur connecté. '
        'Utilisez CurrentUser.maybeOf() si l\'écran est accessible sans connexion.',
      );
    }
    return user;
  }

  static SessionStatus statusOf(BuildContext context) =>
      _scope(context)?.status ?? SessionStatus.loading;

  @override
  bool updateShouldNotify(CurrentUser oldWidget) =>
      oldWidget.status != status || !identical(oldWidget.user, user);
}
