import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

import '../services/user_filter.dart';
import 'form_helpers.dart';

/// Panneau "Filtres avancés" : tri, complétude du profil, période d'inscription.
/// Retourne le nouveau filtre, ou null si fermé sans appliquer.
Future<UserFilter?> showUserFilterSheet(
  BuildContext context,
  UserFilter initial,
) {
  return showModalBottomSheet<UserFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) => _UserFilterSheet(initial: initial),
  );
}

class _UserFilterSheet extends StatefulWidget {
  const _UserFilterSheet({required this.initial});
  final UserFilter initial;

  @override
  State<_UserFilterSheet> createState() => _UserFilterSheetState();
}

class _UserFilterSheetState extends State<_UserFilterSheet> {
  late UserFilter _f = widget.initial;

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _f.createdFrom != null && _f.createdTo != null
          ? DateTimeRange(start: _f.createdFrom!, end: _f.createdTo!)
          : null,
      helpText: "Période d'inscription",
    );
    if (range != null) {
      setState(
        () => _f = _f.copyWith(createdFrom: range.start, createdTo: range.end),
      );
    }
  }

  String get _dateLabel {
    final from = _f.createdFrom, to = _f.createdTo;
    if (from == null && to == null) return 'Toutes les dates';
    if (from != null && to != null) {
      return 'Du ${formatDate(from)} au ${formatDate(to)}';
    }
    return from != null
        ? 'À partir du ${formatDate(from)}'
        : "Jusqu'au ${formatDate(to!)}";
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filtres avancés',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _section(
              'Trier par',
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in UserSort.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _f.sort == s,
                      onSelected: (_) =>
                          setState(() => _f = _f.copyWith(sort: s)),
                    ),
                ],
              ),
            ),
            _section(
              'Profil',
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final p in ProfileFilter.values)
                    ChoiceChip(
                      label: Text(p.label),
                      selected: _f.profile == p,
                      onSelected: (_) =>
                          setState(() => _f = _f.copyWith(profile: p)),
                    ),
                ],
              ),
            ),
            _section(
              "Date d'inscription",
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDates,
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(_dateLabel),
                    ),
                  ),
                  if (_f.hasDateRange)
                    IconButton(
                      tooltip: 'Effacer les dates',
                      onPressed: () =>
                          setState(() => _f = _f.copyWith(clearDates: true)),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(
                      () => _f = UserFilter(
                        query: _f.query,
                        role: _f.role,
                        status: _f.status,
                      ),
                    ),
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _f),
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
