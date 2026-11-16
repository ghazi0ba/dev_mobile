import 'package:flutter/material.dart';

import 'package:dev_mobile/app/shells.dart';
import 'package:dev_mobile/core/widgets/widgets.dart';

import '../services/auth_service.dart';
import '../widgets/current_user_scope.dart';
import 'complete_profile_screen.dart';
import 'login_screen.dart';

/// Point d'entrée de l'app : choisit l'écran selon la session.
/// - non connecté      → LoginScreen
/// - compte désactivé  → DisabledAccountScreen
/// - admin / client    → AdminShell / ClientShell
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastStable;

  @override
  Widget build(BuildContext context) {
    final status = CurrentUser.statusOf(context);
    final user = CurrentUser.maybeOf(context);

    final (String key, Widget screen) = switch (status) {
      SessionStatus.loading => ('loading', const _LoadingScreen()),
      SessionStatus.missingProfile => (
        'missing',
        const _MissingProfileScreen(),
      ),
      SessionStatus.signedOut => ('signedOut', const LoginScreen()),
      SessionStatus.ready when user!.disabled => (
        'disabled',
        const DisabledAccountScreen(),
      ),
      // Prénom ou nom manquant (ancien compte) : à compléter avant d'entrer.
      SessionStatus.ready when !user!.hasCompleteName => (
        'incomplete',
        CompleteProfileScreen(user: user),
      ),
      SessionStatus.ready when user!.isAdmin => ('admin', const AdminShell()),
      SessionStatus.ready => ('client', const ClientShell()),
    };

    // Changement d'espace (connexion, déconnexion, rôle modifié, compte
    // désactivé) : on ferme les écrans ouverts par-dessus.
    if (key != 'loading' && key != 'missing') {
      if (_lastStable != null && _lastStable != key) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        });
      }
      _lastStable = key;
    }

    return KeyedSubtree(key: ValueKey(key), child: screen);
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Le profil Firestore est en cours de création (inscription) ou manque.
class _MissingProfileScreen extends StatefulWidget {
  const _MissingProfileScreen();

  @override
  State<_MissingProfileScreen> createState() => _MissingProfileScreenState();
}

class _MissingProfileScreenState extends State<_MissingProfileScreen> {
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pendant une inscription, le profil arrive en moins d'une seconde.
    // S'il n'existe toujours pas, on le fait créer (prénom + nom).
    if (!_timedOut) return const _LoadingScreen();
    return const CompleteProfileScreen();
  }
}

class DisabledAccountScreen extends StatelessWidget {
  const DisabledAccountScreen({super.key});

  @override
  Widget build(BuildContext context) => const _MessageScreen(
    icon: Icons.block,
    title: 'Compte désactivé',
    message:
        'Votre compte a été désactivé par un administrateur. '
        'Contactez la boutique pour plus d\'informations.',
  );
}

class _MessageScreen extends StatelessWidget {
  const _MessageScreen({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SectionCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  IconBadge(
                    icon: icon,
                    size: 64,
                    background: AppColors.errorLight,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: AuthService.instance.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Retour à la connexion'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
