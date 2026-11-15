import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/produits/services/product_service.dart';

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser != null) {
      _busy = true;
    }
    _restoreSession();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final failure = await _adminFailure(user.uid);
      if (failure != null) {
        await FirebaseAuth.instance.signOut();
        return;
      }
      if (!mounted) return;
      await _enter();
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(code: 'no-user', message: 'Session vide');
      }
      final failure = await _adminFailure(uid);
      if (failure != null) {
        await FirebaseAuth.instance.signOut();
        _showError(failure);
        return;
      }
      await _enter();
    } on FirebaseAuthException catch (e) {
      _showError(_authMessage(e));
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Null when `users/{uid}` is an active admin. Firestore rules grant
  /// product and category writes only in that case.
  Future<String?> _adminFailure(String uid) async {
    final profile =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = profile.data();
    if (!profile.exists || data?['role'] != 'admin') {
      return 'Ce compte n\'est pas administrateur. '
          'Le document users/$uid doit contenir role: "admin".';
    }
    if (data?['disabled'] == true) {
      return 'Ce compte administrateur est désactivé.';
    }
    return null;
  }

  Future<void> _enter() async {
    await ProductService().seedDefaultCategories();
    if (!mounted) return;
    widget.onLoggedIn?.call();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email invalide';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email ou mot de passe incorrect';
      case 'user-disabled':
        return 'Ce compte est désactivé';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard';
      case 'network-request-failed':
        return 'Pas de connexion réseau';
      default:
        return e.message ?? 'Connexion impossible (${e.code})';
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
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
