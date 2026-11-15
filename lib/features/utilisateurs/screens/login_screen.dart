import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:dev_mobile/app/dev_launcher.dart';
import 'package:dev_mobile/core/widgets/widgets.dart';

import '../services/auth_errors.dart';
import '../services/auth_service.dart';
import '../widgets/form_helpers.dart';
import 'signup_screen.dart';

/// Écran de connexion commun aux clients et aux admins.
/// Après connexion, l'AuthGate ouvre l'espace correspondant au rôle.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(
        email: _email.text,
        password: _password.text,
      );
      // L'AuthGate remplace cet écran automatiquement.
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final formKey = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Entrez votre email : vous recevrez un lien pour choisir '
                'un nouveau mot de passe.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'vous@exemple.com',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: Validators.email,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (email == null) return;
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        showMessage(
          context,
          'Si un compte existe pour $email, un email vient d\'être envoyé.',
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), error: true);
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
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.surfaceMuted,
                  child: AppLogo(size: 64),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'COSMAPLUS',
                  style: text.labelSmall?.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Connexion', style: text.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Connectez-vous pour accéder\nà votre espace',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            ErrorBanner(_error!),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          const FieldLabel('Email'),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              hintText: 'vous@exemple.com',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                            validator: Validators.email,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Mot de passe',
                                  style: text.labelLarge,
                                ),
                              ),
                              GestureDetector(
                                onTap: _forgotPassword,
                                child: Text(
                                  'Mot de passe oublié ?',
                                  style: text.labelLarge?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          PasswordField(
                            controller: _password,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          BusyButton(
                            label: 'Se connecter',
                            icon: Icons.arrow_forward,
                            busy: _busy,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Pas encore de compte ?', style: text.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      ),
                      child: const Text('Créer un compte'),
                    ),
                  ],
                ),
                if (kDebugMode)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DevLauncher()),
                    ),
                    icon: const Icon(Icons.developer_mode, size: 18),
                    label: const Text('Mode développement (sans connexion)'),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Session sécurisée • CosmaPlus',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
