import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

import '../../services/auth_errors.dart';
import '../../services/user_filter.dart';
import '../../services/user_service.dart';
import '../../widgets/current_user_scope.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/user_filter_sheet.dart';
import 'create_user_screen.dart';
import 'user_detail_screen.dart';

/// Admin : liste des utilisateurs avec recherche avancée, filtres et tri.
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _search = TextEditingController();
  late final Stream<List<AppUser>> _users = UserService.instance
      .watchAllUsers();
  UserFilter _filter = const UserFilter();

  @override
  void initState() {
    super.initState();
    _migrateLegacyNames();
  }

  /// Anciens profils (seulement "fullName") → prénom + nom, une seule fois.
  Future<void> _migrateLegacyNames() async {
    try {
      final count = await UserService.instance.migrateAllLegacyNames();
      if (count > 0 && mounted) {
        showMessage(
          context,
          '$count profil${count > 1 ? 's' : ''} mis à jour (prénom / nom).',
        );
      }
    } catch (_) {
      // Sans gravité : les profils seront migrés à la connexion de chacun.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(UserFilter f) => setState(() => _filter = f);

  void _reset() {
    _search.clear();
    _update(const UserFilter());
  }

  Future<void> _openAdvanced() async {
    final result = await showUserFilterSheet(context, _filter);
    if (result != null) _update(result);
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Utilisateurs', showBack: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const CreateUserScreen()),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Nouvel utilisateur'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _users,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ErrorBanner(errorMessage(snap.error!)),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final results = _filter.apply(all);
          return Column(
            children: [
              _SearchBar(
                controller: _search,
                advancedCount: _filter.advancedCount,
                onChanged: (q) => _update(_filter.copyWith(query: q)),
                onClear: () {
                  _search.clear();
                  _update(_filter.copyWith(query: ''));
                },
                onAdvanced: _openAdvanced,
              ),
              _QuickFilters(all: all, filter: _filter, onChanged: _update),
              _ActiveFilters(filter: _filter, onChanged: _update),
              _ResultsBar(
                shown: results.length,
                total: all.length,
                canReset: _filter.isActive,
                onReset: _reset,
              ),
              Expanded(
                child: results.isEmpty
                    ? _EmptyResults(onReset: _filter.isActive ? _reset : null)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          96,
                        ),
                        itemCount: results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => _UserTile(
                          user: results[i],
                          onTap: () =>
                              _open(UserDetailScreen(userId: results[i].id)),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.advancedCount,
    required this.onChanged,
    required this.onClear,
    required this.onAdvanced,
  });

  final TextEditingController controller;
  final int advancedCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Nom, email, téléphone, adresse…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.close),
                          onPressed: onClear,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            tooltip: 'Filtres avancés',
            onPressed: onAdvanced,
            icon: Badge(
              isLabelVisible: advancedCount > 0,
              label: Text('$advancedCount'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
    );
  }
}

/// Puces rapides : rôle et statut, avec le nombre d'utilisateurs.
class _QuickFilters extends StatelessWidget {
  const _QuickFilters({
    required this.all,
    required this.filter,
    required this.onChanged,
  });

  final List<AppUser> all;
  final UserFilter filter;
  final ValueChanged<UserFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final admins = all.where((u) => u.isAdmin).length;
    final disabled = all.where((u) => u.disabled).length;

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          chip(
            'Tous (${all.length})',
            filter.role == RoleFilter.all,
            () => onChanged(filter.copyWith(role: RoleFilter.all)),
          ),
          chip(
            'Clients (${all.length - admins})',
            filter.role == RoleFilter.client,
            () => onChanged(filter.copyWith(role: RoleFilter.client)),
          ),
          chip(
            'Admins ($admins)',
            filter.role == RoleFilter.admin,
            () => onChanged(filter.copyWith(role: RoleFilter.admin)),
          ),
          const SizedBox(
            height: 24,
            child: VerticalDivider(width: AppSpacing.md),
          ),
          const SizedBox(width: AppSpacing.sm),
          chip(
            'Actifs (${all.length - disabled})',
            filter.status == StatusFilter.active,
            () => onChanged(
              filter.copyWith(
                status: filter.status == StatusFilter.active
                    ? StatusFilter.all
                    : StatusFilter.active,
              ),
            ),
          ),
          chip(
            'Désactivés ($disabled)',
            filter.status == StatusFilter.disabled,
            () => onChanged(
              filter.copyWith(
                status: filter.status == StatusFilter.disabled
                    ? StatusFilter.all
                    : StatusFilter.disabled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtres avancés actifs, supprimables d'un clic.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filter, required this.onChanged});

  final UserFilter filter;
  final ValueChanged<UserFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (filter.sort != UserSort.lastNameAsc)
        InputChip(
          avatar: const Icon(Icons.sort, size: 18),
          label: Text(filter.sort.label),
          onDeleted: () =>
              onChanged(filter.copyWith(sort: UserSort.lastNameAsc)),
        ),
      if (filter.profile != ProfileFilter.all)
        InputChip(
          avatar: const Icon(Icons.person_search_outlined, size: 18),
          label: Text(filter.profile.label),
          onDeleted: () =>
              onChanged(filter.copyWith(profile: ProfileFilter.all)),
        ),
      if (filter.hasDateRange)
        InputChip(
          avatar: const Icon(Icons.date_range_outlined, size: 18),
          label: Text(
            [
              if (filter.createdFrom != null) formatDate(filter.createdFrom!),
              if (filter.createdTo != null) formatDate(filter.createdTo!),
            ].join(' → '),
          ),
          onDeleted: () => onChanged(filter.copyWith(clearDates: true)),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: chips,
        ),
      ),
    );
  }
}

class _ResultsBar extends StatelessWidget {
  const _ResultsBar({
    required this.shown,
    required this.total,
    required this.canReset,
    required this.onReset,
  });

  final int shown;
  final int total;
  final bool canReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              shown == total
                  ? '$total utilisateur${total > 1 ? 's' : ''}'
                  : '$shown sur $total utilisateurs',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (canReset)
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Réinitialiser'),
            ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMe = CurrentUser.maybeOf(context)?.id == user.id;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Row(
            children: [
              UserAvatar(user: user),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName.isEmpty ? user.email : user.fullName,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email,
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((user.phone ?? '').isNotEmpty)
                      Text(user.phone!, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RoleBadge(user.role),
                  if (user.disabled) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const AccountStatusBadge(disabled: true),
                  ],
                  if (isMe) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const StatusBadge('Vous', tone: BadgeTone.success),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({this.onReset});
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Center(
          child: IconBadge(
            icon: Icons.person_search_outlined,
            size: 64,
            background: AppColors.secondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Aucun utilisateur trouvé',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          onReset == null
              ? 'Aucun compte pour le moment.'
              : 'Essayez d\'autres mots-clés ou retirez des filtres.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (onReset != null) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Réinitialiser les filtres'),
            ),
          ),
        ],
      ],
    );
  }
}
