import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

/// Écran de connexion (maquette "Espace Admin").
/// Module Utilisateurs : brancher Firebase Auth dans [_submit].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoggedIn});

  /// Appelé après une connexion réussie (temporaire, en attendant l'AuthGate).
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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // TODO(module Utilisateurs) : FirebaseAuth.instance.signInWithEmailAndPassword(...)
    widget.onLoggedIn?.call();
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
                              onTap: () {
                                // TODO(module Utilisateurs) : sendPasswordResetEmail
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
                        FilledButton(
                          onPressed: _submit,
                          child: const Row(
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
