import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

import '../services/auth_errors.dart';
import '../services/auth_service.dart';
import '../widgets/form_helpers.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      if (!mounted) return;
      showMessage(context, 'Mot de passe modifié');
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
      appBar: const AppHeader(subtitle: 'Mot de passe', showBack: true),
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
                title: 'Changer le mot de passe',
                icon: Icons.lock_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Mot de passe actuel'),
                    PasswordField(
                      controller: _current,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Mot de passe requis'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Nouveau mot de passe'),
                    PasswordField(
                      controller: _new,
                      hintText: '6 caractères minimum',
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final base = Validators.password(v);
                        if (base != null) return base;
                        return v == _current.text
                            ? "Choisissez un mot de passe différent de l'actuel"
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Confirmer le nouveau mot de passe'),
                    PasswordField(
                      controller: _confirm,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (v) => v != _new.text
                          ? 'Les mots de passe ne correspondent pas'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              BusyButton(
                label: 'Mettre à jour',
                icon: Icons.check,
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
