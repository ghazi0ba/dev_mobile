import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

/// Validateurs des formulaires du module.
class Validators {
  Validators._();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phoneRe = RegExp(r'^\+?[0-9 .\-]{8,20}$');

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return "L'email est requis";
    return _emailRe.hasMatch(s) ? null : 'Email invalide';
  }

  /// 8 caractères min., avec majuscule, minuscule, chiffre et caractère spécial.
  static String? password(String? v) {
    final s = v ?? '';
    if (s.length < 8) return '8 caractères minimum';
    if (!RegExp(r'[A-Z]').hasMatch(s)) return 'Au moins une majuscule';
    if (!RegExp(r'[a-z]').hasMatch(s)) return 'Au moins une minuscule';
    if (!RegExp(r'[0-9]').hasMatch(s)) return 'Au moins un chiffre';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(s)) {
      return 'Au moins un caractère spécial';
    }
    return null;
  }

  static String? firstName(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Le prénom est requis' : null;

  static String? lastName(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Le nom est requis' : null;

  /// Optionnel : vide accepté.
  static String? phone(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    return _phoneRe.hasMatch(s) ? null : 'Numéro invalide';
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 05/03/2026
String formatDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
}

/// Bouton principal qui affiche un indicateur pendant le chargement.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return FilledButton(
      // Garde le style "actif" pendant le chargement, mais ignore les clics.
      onPressed: busy ? () {} : onPressed,
      child: busy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: onPrimary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label),
                if (icon != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(icon, size: 18),
                ],
              ],
            ),
    );
  }
}

/// Bandeau d'erreur dans un formulaire.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Libellé au-dessus d'un champ (comme sur la maquette de connexion).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// Prénom et nom côte à côte.
class NameFields extends StatelessWidget {
  const NameFields({
    super.key,
    required this.firstName,
    required this.lastName,
  });

  final TextEditingController firstName;
  final TextEditingController lastName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Prénom'),
              TextFormField(
                controller: firstName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                decoration: const InputDecoration(hintText: 'Nadia'),
                validator: Validators.firstName,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Nom'),
              TextFormField(
                controller: lastName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                decoration: const InputDecoration(hintText: 'Benali'),
                validator: Validators.lastName,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Champ mot de passe avec bouton afficher / masquer.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hintText = '••••••••',
    this.validator = Validators.password,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.key_outlined),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Afficher' : 'Masquer',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator,
    );
  }
}

/// Demande le mot de passe actuel (actions sensibles). Retourne null si annulé.
Future<String?> askPassword(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool destructive = false,
}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: IconBadge(
                  icon: Icons.lock_outline,
                  size: 52,
                  background: destructive
                      ? AppColors.errorLight
                      : AppColors.secondary,
                  color: destructive ? AppColors.error : AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: controller,
                hintText: 'Mot de passe actuel',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, controller.text);
                  }
                },
                child: Text(confirmLabel),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
