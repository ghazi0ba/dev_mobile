import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

import '../services/auth_errors.dart';
import '../services/auth_service.dart';
import '../widgets/current_user_scope.dart';
import '../widgets/form_helpers.dart';

/// Firebase envoie un lien à la nouvelle adresse ; l'email ne change
/// qu'après le clic. L'utilisateur se reconnecte ensuite avec la nouvelle.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
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
      final newEmail = _email.text.trim();
      await AuthService.instance.changeEmail(
        password: _password.text,
        newEmail: newEmail,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vérifiez votre boîte mail'),
          content: Text(
            'Un lien de confirmation a été envoyé à $newEmail.\n\n'
            'Cliquez dessus pour valider le changement, puis reconnectez-vous '
            'avec votre nouvelle adresse.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = CurrentUser.maybeOf(context)?.email ?? '';
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Adresse email', showBack: true),
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
                title: "Changer l'email",
                icon: Icons.alternate_email,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Email actuel'),
                    TextFormField(
                      initialValue: current,
                      enabled: false,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Nouvel email'),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'nouveau@exemple.com',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) {
                        final base = Validators.email(v);
                        if (base != null) return base;
                        return v!.trim().toLowerCase() == current.toLowerCase()
                            ? "C'est déjà votre adresse actuelle"
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Mot de passe actuel'),
                    PasswordField(
                      controller: _password,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Mot de passe requis'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              BusyButton(
                label: 'Envoyer le lien de confirmation',
                icon: Icons.send_outlined,
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
