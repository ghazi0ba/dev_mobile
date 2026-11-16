import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../../services/auth_errors.dart';
import '../../services/auth_service.dart';
import '../../widgets/form_helpers.dart';

/// Admin : créer un compte client ou admin.
class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.client;
  bool _sendReset = true;
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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _generatePassword() {
    const lower = 'abcdefghjkmnpqrstuvwxyz';
    const upper = 'ABCDEFGHJKMNPQRSTUVWXYZ';
    const digits = '23456789';
    const special = '!@#\$%&*?-_';
    const all = lower + upper + digits + special;
    final rnd = Random.secure();
    String pick(String set) => set[rnd.nextInt(set.length)];
    // Garantit une majuscule, une minuscule, un chiffre et un spécial.
    final chars = [
      pick(lower), pick(upper), pick(digits), pick(special),
      for (var i = 0; i < 8; i++) pick(all),
    ]..shuffle(rnd);
    _password.text = chars.join();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.createUserAsAdmin(
        email: _email.text,
        password: _password.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        role: _role,
        phone: _phone.text,
        address: _address.text,
        sendPasswordResetEmail: _sendReset,
      );
      if (!mounted) return;
      showMessage(
        context,
        _sendReset
            ? 'Compte créé. Un email a été envoyé à ${_email.text.trim()}.'
            : 'Compte créé pour ${_email.text.trim()}.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Nouvel utilisateur', showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: AppSpacing.md),
              ],
              SectionCard(
                title: 'Rôle',
                icon: Icons.admin_panel_settings_outlined,
                child: SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.client,
                      label: Text('Client'),
                      icon: Icon(Icons.person_outline),
                    ),
                    ButtonSegment(
                      value: UserRole.admin,
                      label: Text('Admin'),
                      icon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Informations',
                icon: Icons.badge_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NameFields(firstName: _firstName, lastName: _lastName),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Email'),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'nom@exemple.com',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Téléphone (optionnel)'),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Adresse (optionnel)'),
                    TextFormField(
                      controller: _address,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Mot de passe provisoire',
                icon: Icons.key_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: PasswordField(controller: _password)),
                        const SizedBox(width: AppSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IconButton.filledTonal(
                            tooltip: 'Générer',
                            onPressed: _generatePassword,
                            icon: const Icon(Icons.auto_fix_high_outlined),
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _sendReset,
                      onChanged: (v) => setState(() => _sendReset = v ?? true),
                      title: const Text(
                        'Envoyer un email pour choisir son mot de passe',
                      ),
                      subtitle: const Text(
                        "Recommandé : vous n'avez pas à communiquer le "
                        'mot de passe provisoire.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              BusyButton(
                label: 'Créer le compte',
                icon: Icons.person_add_alt_1_outlined,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
