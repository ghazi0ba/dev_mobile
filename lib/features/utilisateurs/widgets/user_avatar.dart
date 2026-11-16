import 'package:flutter/material.dart';

import 'package:dev_mobile/core/services/cloudinary_service.dart';
import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

/// Initiales : prénom + nom → "NB". Sans nom : première lettre de [fallback]
/// (l'email), sinon "?".
String initialsOf(String firstName, String lastName, {String fallback = ''}) {
  String first(String v) {
    final t = v.trim();
    return t.isEmpty ? '' : t.substring(0, 1).toUpperCase();
  }

  final initials = first(firstName) + first(lastName);
  if (initials.isNotEmpty) return initials;
  final f = first(fallback);
  return f.isEmpty ? '?' : f;
}

const _palette = [
  (AppColors.secondary, AppColors.primary),
  (AppColors.successLight, AppColors.success),
  (AppColors.warningLight, AppColors.warning),
  (AppColors.errorLight, AppColors.primaryDark),
  (AppColors.surfaceMuted, AppColors.textPrimary),
];

/// Avatar rond : photo Cloudinary si elle existe, sinon les initiales.
/// Les initiales restent aussi affichées pendant le chargement de la photo
/// ou si elle ne peut pas être chargée (pas de réseau, URL invalide…).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 22});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = user.disabled
        ? (AppColors.neutralLight, AppColors.textHint)
        : _palette[user.id.codeUnits.fold(0, (a, c) => a + c) %
              _palette.length];
    final pixels = (radius * 2 * MediaQuery.devicePixelRatioOf(context))
        .round();
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundImage: user.hasPhoto
          ? NetworkImage(cloudinaryThumbnail(user.photoUrl!, size: pixels))
          : null,
      onForegroundImageError: user.hasPhoto ? (_, _) {} : null,
      child: Text(
        initialsOf(user.firstName, user.lastName, fallback: user.email),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});
  final UserRole role;

  @override
  Widget build(BuildContext context) => role == UserRole.admin
      ? const StatusBadge('Admin', tone: BadgeTone.brand)
      : const StatusBadge('Client');
}

class AccountStatusBadge extends StatelessWidget {
  const AccountStatusBadge({super.key, required this.disabled});
  final bool disabled;

  @override
  Widget build(BuildContext context) => disabled
      ? const StatusBadge('Désactivé', tone: BadgeTone.error, showDot: true)
      : const StatusBadge('Actif', tone: BadgeTone.success, showDot: true);
}
