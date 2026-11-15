import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

import '../services/auth_errors.dart';
import '../services/auth_service.dart';
import '../widgets/form_helpers.dart';

/// Inscription d'un nouveau client (rôle "client" par défaut).
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _address,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signUp(
        email: _email.text,
        password: _password.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        phone: _phone.text,
        address: _address.text,
      );
      // Connecté automatiquement : l'AuthGate ferme cet écran.
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Créer un compte', showBack: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bienvenue !',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Créez votre compte pour commander vos soins.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                SectionCard(
                  title: 'Identité',
                  icon: Icons.person_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NameFields(firstName: _firstName, lastName: _lastName),
                      const SizedBox(height: AppSpacing.md),
                      const FieldLabel('Téléphone (optionnel)'),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: '+216 20 000 000',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: Validators.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const FieldLabel('Adresse de livraison (optionnel)'),
                      TextFormField(
                        controller: _address,
                        maxLines: 2,
                        minLines: 1,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Rue, ville, code postal',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  title: 'Connexion',
                  icon: Icons.lock_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Email'),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'vous@exemple.com',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const FieldLabel('Mot de passe'),
                      PasswordField(
                        controller: _password,
                        hintText: '6 caractères minimum',
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const FieldLabel('Confirmer le mot de passe'),
                      PasswordField(
                        controller: _confirm,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (v) => v != _password.text
                            ? 'Les mots de passe ne correspondent pas'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                BusyButton(
                  label: 'Créer mon compte',
                  icon: Icons.arrow_forward,
                  busy: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("J'ai déjà un compte"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
