import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../../services/auth_errors.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/current_user_scope.dart';
import '../../widgets/editable_avatar.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/user_avatar.dart';
import '../account_screen.dart';
import '../profile_form_screen.dart';

/// Admin : fiche d'un utilisateur (mise à jour en temps réel).
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late final Stream<AppUser?> _user = UserService.instance.watchUser(
    widget.userId,
  );
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showMessage(context, success);
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeRole(AppUser user, UserRole role) async {
    if (role == user.role) return;
    final toAdmin = role == UserRole.admin;
    final ok = await showConfirmDialog(
      context,
      title: toAdmin ? 'Nommer administrateur ?' : 'Retirer les droits admin ?',
      message: toAdmin
          ? '${user.fullName} aura accès à toute la gestion de la boutique, '
                'y compris les utilisateurs.'
          : '${user.fullName} redeviendra un client.',
      confirmLabel: toAdmin ? 'Oui, nommer admin' : 'Oui, passer client',
    );
    if (!ok) return;
    await _run(
      () => UserService.instance.setRole(user.id, role),
      toAdmin ? 'Rôle admin attribué' : 'Rôle client attribué',
    );
  }

  Future<void> _toggleDisabled(AppUser user) async {
    final disable = !user.disabled;
    final ok = await showConfirmDialog(
      context,
      title: disable ? 'Désactiver ce compte ?' : 'Réactiver ce compte ?',
      message: disable
          ? '${user.fullName} sera déconnecté et ne pourra plus utiliser '
                "l'application. Vous pourrez le réactiver à tout moment."
          : '${user.fullName} pourra de nouveau se connecter.',
      confirmLabel: disable ? 'Oui, désactiver' : 'Oui, réactiver',
      destructive: disable,
    );
    if (!ok) return;
    await _run(
      () => UserService.instance.setDisabled(user.id, disable),
      disable ? 'Compte désactivé' : 'Compte réactivé',
    );
  }

  Future<void> _sendReset(AppUser user) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Réinitialiser le mot de passe ?',
      message:
          'Un email sera envoyé à ${user.email} avec un lien pour '
          'choisir un nouveau mot de passe.',
      confirmLabel: "Envoyer l'email",
    );
    if (!ok) return;
    await _run(
      () => AuthService.instance.sendPasswordReset(user.email),
      'Email envoyé à ${user.email}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = CurrentUser.maybeOf(context);
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Fiche utilisateur', showBack: true),
      body: StreamBuilder<AppUser?>(
        stream: _user,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ErrorBanner(errorMessage(snap.error!)),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snap.data;
          if (user == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: ErrorBanner('Cet utilisateur n\'existe plus.'),
            );
          }
          final isMe = me?.id == user.id;
          return _body(context, user, isMe);
        },
      ),
    );
  }

  Widget _body(BuildContext context, AppUser user, bool isMe) {
    final text = Theme.of(context).textTheme;
    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_busy) const LinearProgressIndicator(),
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
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          RoleBadge(user.role),
                          AccountStatusBadge(disabled: user.disabled),
                          if (isMe)
                            const StatusBadge('Vous', tone: BadgeTone.success),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Informations',
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
                  label: 'Inscrit le',
                  value: user.createdAt == null
                      ? null
                      : formatDate(user.createdAt!),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileFormScreen(
                        user: user,
                        title: "Modifier l'utilisateur",
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier les informations'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Rôle et accès',
            icon: Icons.admin_panel_settings_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isMe) ...[
                  Text(
                    'Vous ne pouvez pas modifier votre propre rôle ni '
                    'désactiver votre compte.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                SegmentedButton<UserRole>(
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
                  selected: {user.role},
                  onSelectionChanged: isMe
                      ? null
                      : (s) => _changeRole(user, s.first),
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Compte actif'),
                  subtitle: Text(
                    user.disabled
                        ? "L'utilisateur ne peut pas se connecter"
                        : "L'utilisateur peut utiliser l'application",
                  ),
                  value: !user.disabled,
                  onChanged: isMe ? null : (_) => _toggleDisabled(user),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Sécurité',
            icon: Icons.lock_outline,
            child: MenuTile(
              icon: Icons.lock_reset,
              title: 'Envoyer un email de réinitialisation',
              subtitle:
                  'Le mot de passe actuel reste valable jusqu\'au '
                  'changement',
              onTap: () => _sendReset(user),
            ),
          ),
        ],
      ),
    );
  }
}
