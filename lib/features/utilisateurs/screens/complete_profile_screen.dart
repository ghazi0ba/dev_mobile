import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../services/auth_errors.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/form_helpers.dart';

/// Affiché par l'AuthGate quand le prénom ou le nom manque (anciens comptes),
/// ou quand le compte n'a pas encore de profil ([user] null : compte créé
/// depuis la console Firebase). Une fois enregistré, l'AuthGate ouvre
/// automatiquement l'espace du rôle.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, this.user});
  final AppUser? user;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.user?.firstName);
  late final _lastName = TextEditingController(text: widget.user?.lastName);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = widget.user;
      if (user == null) {
        await AuthService.instance.createOwnProfile(
          firstName: _firstName.text,
          lastName: _lastName.text,
        );
      } else {
        await UserService.instance.updateInfo(
          user.id,
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: user.phone,
          address: user.address,
        );
      }
      // Le profil est maintenant complet : l'AuthGate change d'écran.
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: IconBadge(
                      icon: Icons.badge_outlined,
                      size: 64,
                      background: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Complétez votre profil',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Votre prénom et votre nom sont nécessaires pour '
                    'utiliser CosmaPlus.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null) ...[
                    ErrorBanner(_error!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  SectionCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: NameFields(
                      firstName: _firstName,
                      lastName: _lastName,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  BusyButton(
                    label: 'Continuer',
                    icon: Icons.arrow_forward,
                    busy: _busy,
                    onPressed: _save,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: AuthService.instance.signOut,
                    child: const Text('Se déconnecter'),
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
