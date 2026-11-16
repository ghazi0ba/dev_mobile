import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../services/auth_errors.dart';
import '../services/user_service.dart';
import '../widgets/form_helpers.dart';

/// Modifier nom / téléphone / adresse.
/// Utilisé par l'utilisateur (son profil) et par l'admin (n'importe qui).
class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({
    super.key,
    required this.user,
    this.title = 'Modifier mes informations',
  });

  final AppUser user;
  final String title;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.user.firstName);
  late final _lastName = TextEditingController(text: widget.user.lastName);
  late final _phone = TextEditingController(text: widget.user.phone ?? '');
  late final _address = TextEditingController(text: widget.user.address ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await UserService.instance.updateInfo(
        widget.user.id,
        firstName: _firstName.text,
        lastName: _lastName.text,
        phone: _phone.text,
        address: _address.text,
      );
      if (!mounted) return;
      showMessage(context, 'Informations enregistrées');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(subtitle: widget.title, showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Informations',
                icon: Icons.badge_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NameFields(firstName: _firstName, lastName: _lastName),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Téléphone'),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Non renseigné',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Adresse de livraison'),
                    TextFormField(
                      controller: _address,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Non renseignée',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const FieldLabel('Email'),
                    TextFormField(
                      initialValue: widget.user.email,
                      enabled: false,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.alternate_email),
                        helperText:
                            "L'email se change depuis « Changer l'email ».",
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              BusyButton(
                label: 'Enregistrer',
                icon: Icons.check,
                busy: _busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
