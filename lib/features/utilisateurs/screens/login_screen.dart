import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

/// Écran de connexion avec Firebase Auth.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoggedIn});

  /// Appelé après une connexion réussie.
  final VoidCallback? onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      widget.onLoggedIn?.call();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = switch (e.code) {
          'user-not-found' => 'Aucun compte avec cet email',
          'wrong-password' => 'Mot de passe incorrect',
          'invalid-email' => 'Email invalide',
          'user-disabled' => 'Compte désactivé',
          'too-many-requests' => 'Trop de tentatives. Réessayez plus tard',
          _ => 'Erreur de connexion: ${e.message}',
        };
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                Text('COSMAPLUS',
                    style: text.labelSmall?.copyWith(color: AppColors.primary)),
                const SizedBox(height: AppSpacing.xs),
                Text('Espace Admin', style: text.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Connectez-vous pour gérer vos\ncosmétiques et inventaires',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Identifiant / Email professionnel',
                            style: text.labelLarge),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'directeur@aurabotanica.com',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Email invalide'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                                child: Text('Mot de passe',
                                    style: text.labelLarge)),
                            GestureDetector(
                              onTap: () async {
                                final email = _email.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Entrez votre email d\'abord')),
                                  );
                                  return;
                                }
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Email de réinitialisation envoyé')),
                                    );
                                  }
                                } on FirebaseAuthException catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Erreur: ${e.message}')),
                                    );
                                  }
                                }
                              },
                              child: Text(
                                'Mot de passe oublié ?',
                                style: text.labelLarge
                                    ?.copyWith(color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? '6 caractères minimum'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Checkbox(
                              value: _remember,
                              onChanged: (v) =>
                                  setState(() => _remember = v ?? false),
                            ),
                            Text('Mémoriser ce poste', style: text.bodyMedium),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: text.bodySmall?.copyWith(color: AppColors.error),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Se connecter'),
                                    SizedBox(width: AppSpacing.sm),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Session sécurisée • CosmaPlus',
                        style: text.bodySmall),
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