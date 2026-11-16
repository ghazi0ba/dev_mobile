import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Carte blanche arrondie, avec titre optionnel (ex. "Informations principales").
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(title!, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Icône dans une pastille ronde colorée (cartes de stats, menu).
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.background = AppColors.errorLight,
    this.color = AppColors.primary,
    this.size = 36,
  });

  final IconData icon;
  final Color background;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

enum BadgeTone { success, warning, error, neutral, brand }

/// Petite étiquette arrondie : "Disponible", "+4 ce mois", "Rupture"...
class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.label, {
    super.key,
    this.tone = BadgeTone.neutral,
    this.showDot = false,
  });

  final String label;
  final BadgeTone tone;
  final bool showDot;

  (Color bg, Color fg) get _colors => switch (tone) {
        BadgeTone.success => (AppColors.successLight, AppColors.success),
        BadgeTone.warning => (AppColors.warningLight, AppColors.warning),
        BadgeTone.error => (AppColors.errorLight, AppColors.error),
        BadgeTone.neutral => (AppColors.neutralLight, AppColors.textSecondary),
        BadgeTone.brand => (AppColors.secondary, AppColors.primary),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de statistique du tableau de bord ("Produits 128").
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.badge,
    this.iconBackground = AppColors.errorLight,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatusBadge? badge;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                IconBadge(icon: icon, background: iconBackground),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        maxLines: 1,
                        style: AppTheme.serif(size: 28, weight: FontWeight.w700)),
                  ),
                ),
                ?badge,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fenêtre de confirmation (ex. suppression d'un produit).
/// Retourne true si l'utilisateur confirme.
///
/// ```dart
/// final ok = await showConfirmDialog(context,
///   title: 'Confirmer la suppression ?',
///   message: 'Supprimer définitivement ce produit ?',
///   confirmLabel: 'Oui, supprimer définitivement',
///   destructive: true);
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(
              icon: destructive
                  ? Icons.delete_outline
                  : Icons.help_outline_rounded,
              background: destructive
                  ? AppColors.errorLight
                  : AppColors.secondary,
              color: destructive ? AppColors.error : AppColors.primary,
              size: 52,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: Icon(destructive ? Icons.delete : Icons.check),
              label: Text(confirmLabel),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Écran temporaire pour un module pas encore développé.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.module,
    required this.icon,
    required this.todo,
  });

  final String module;
  final IconData icon;
  final List<String> todo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        SectionCard(
          child: Column(
            children: [
              IconBadge(
                icon: icon,
                size: 64,
                background: AppColors.secondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Module $module',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              const StatusBadge('À construire', tone: BadgeTone.warning),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'À faire',
          icon: Icons.checklist_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in todo)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text('•  $t'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
