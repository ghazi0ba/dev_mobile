import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../services/auth_errors.dart';
import '../services/auth_service.dart';
import '../widgets/current_user_scope.dart';
import '../widgets/editable_avatar.dart';
import '../widgets/form_helpers.dart';
import '../widgets/user_avatar.dart';
import 'admin/user_list_screen.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';
import 'profile_form_screen.dart';

/// Onglet "Profil" (client) / "Menu" (admin) : mon compte.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = CurrentUser.maybeOf(context);
    return Scaffold(
      appBar: AppHeader(subtitle: user?.isAdmin == true ? 'Menu' : 'Profil'),
      body: user == null ? const _NotSignedIn() : _AccountBody(user: user),
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({required this.user});
  final AppUser user;

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _signOut(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous devrez saisir à nouveau votre email et mot de passe.',
      confirmLabel: 'Se déconnecter',
    );
    if (ok) await AuthService.instance.signOut();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer mon compte ?',
      message:
          'Votre profil sera supprimé définitivement. '
          'Vos commandes passées restent enregistrées pour la boutique.',
      confirmLabel: 'Oui, supprimer mon compte',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final password = await askPassword(
      context,
      title: 'Confirmez votre identité',
      message: 'Entrez votre mot de passe pour supprimer votre compte.',
      confirmLabel: 'Supprimer définitivement',
      destructive: true,
    );
    if (password == null) return;
    try {
      await AuthService.instance.deleteAccount(password);
      // Déconnecté automatiquement : l'AuthGate affiche la connexion.
    } catch (e) {
      if (context.mounted) showMessage(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        SectionCard(
          child: Row(
            children: [
              EditableAvatar(user: user, radius: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: text.titleLarge),
                    Text(user.email, style: text.bodyMedium),
                    const SizedBox(height: AppSpacing.xs),
                    RoleBadge(user.role),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Mes informations',
          icon: Icons.badge_outlined,
          child: Column(
            children: [
              InfoRow(
                icon: Icons.person_outline,
                label: 'Prénom',
                value: user.firstName,
              ),
              InfoRow(
                icon: Icons.badge_outlined,
                label: 'Nom',
                value: user.lastName,
              ),
              InfoRow(
                icon: Icons.phone_outlined,
                label: 'Téléphone',
                value: user.phone,
              ),
              InfoRow(
                icon: Icons.home_outlined,
                label: 'Adresse',
                value: user.address,
              ),
              InfoRow(
                icon: Icons.event_outlined,
                label: 'Membre depuis',
                value: user.createdAt == null
                    ? null
                    : formatDate(user.createdAt!),
              ),
            ],
          ),
        ),
        if (user.isAdmin) ...[
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Administration',
            icon: Icons.admin_panel_settings_outlined,
            child: MenuTile(
              icon: Icons.group_outlined,
              title: 'Gestion des utilisateurs',
              subtitle: 'Rechercher, créer, modifier, désactiver',
              onTap: () => _open(context, const UserListScreen()),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Mon compte',
          icon: Icons.manage_accounts_outlined,
          child: Column(
            children: [
              MenuTile(
                icon: Icons.edit_outlined,
                title: 'Modifier mes informations',
                subtitle: 'Prénom, nom, téléphone, adresse',
                onTap: () => _open(context, ProfileFormScreen(user: user)),
              ),
              MenuTile(
                icon: Icons.lock_outline,
                title: 'Changer le mot de passe',
                onTap: () => _open(context, const ChangePasswordScreen()),
              ),
              MenuTile(
                icon: Icons.alternate_email,
                title: "Changer l'email",
                subtitle: user.email,
                onTap: () => _open(context, const ChangeEmailScreen()),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => _signOut(context),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => _deleteAccount(context),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Supprimer mon compte'),
        ),
      ],
    );
  }
}

/// Visible seulement en mode développement (espaces ouverts sans connexion).
class _NotSignedIn extends StatelessWidget {
  const _NotSignedIn();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      SectionCard(
        child: Column(
          children: [
            const IconBadge(
              icon: Icons.person_off_outlined,
              size: 64,
              background: AppColors.secondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Non connecté', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Mode développement : connectez-vous pour voir votre profil.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Ligne "icône + libellé + valeur" d'une fiche.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final empty = value == null || value!.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                Text(
                  empty ? 'Non renseigné' : value!,
                  style: text.bodyLarge?.copyWith(
                    color: empty ? AppColors.textHint : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Entrée de menu cliquable.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: IconBadge(icon: icon, background: AppColors.secondary),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
