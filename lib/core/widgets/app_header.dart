import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// En-tête des écrans principaux : logo + "CosmaPlus" + sous-titre en majuscules.
///
/// ```dart
/// Scaffold(appBar: const AppHeader(subtitle: 'Produits'), ...)
/// ```
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.subtitle,
    this.title = 'CosmaPlus',
    this.actions,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      automaticallyImplyLeading: showBack,
      titleSpacing: showBack ? 0 : AppSpacing.md,
      title: Row(
        children: [
          const AppLogo(size: 36),
          const SizedBox(width: AppSpacing.sm + 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTheme.serif(size: 20)),
              Text(
                subtitle.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
      actions: actions,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}

/// Logo de la boutique.
/// Pour utiliser le vrai logo : ajoutez assets/images/logo.png dans pubspec.yaml
/// et remplacez l'Icon par Image.asset('assets/images/logo.png').
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(Icons.spa_outlined,
          size: size * 0.55, color: AppColors.primary),
    );
  }
}
