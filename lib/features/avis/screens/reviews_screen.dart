import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/avis/services/services.dart';
import 'package:dev_mobile/features/avis/widgets/rating_stars.dart';
import 'package:dev_mobile/shared/models/models.dart';

/// Onglet "Avis" (admin) : tous les avis des clients, avec statistiques,
/// recherche, filtre par note et suppression (modération).
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final Stream<List<Review>> _reviews = ReviewService.watchAllReviews();

  /// Nom de chaque produit (id → nom), pour afficher le produit de l'avis.
  final Stream<Map<String, String>> _productNames = FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((q) => {
            for (final d in q.docs) d.id: (d.data()['name'] as String?) ?? '',
          });

  final _search = TextEditingController();
  int? _stars; // null = toutes les notes

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _normalize(String s) {
    const from = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿ';
    const to = 'aaaaaceeeeiiiinooooouuuuyy';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _date(DateTime? d) => d == null
      ? "à l'instant"
      : '${_two(d.day)}/${_two(d.month)}/${d.year} à ${_two(d.hour)}:${_two(d.minute)}';

  Future<void> _delete(Review r, String productName) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer cet avis ?',
      message: 'Avis de ${r.userName.isEmpty ? 'un client' : r.userName} '
          'sur « $productName » (${r.rating}★).\n'
          'La note moyenne du produit sera recalculée.',
      confirmLabel: 'Oui, supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ReviewService.deleteReview(r.id, r.productId);
      messenger.showSnackBar(const SnackBar(content: Text('Avis supprimé')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Suppression impossible : $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppHeader(subtitle: 'Avis'),
      body: StreamBuilder<Map<String, String>>(
        stream: _productNames,
        builder: (context, productSnap) {
          final names = productSnap.data ?? const <String, String>{};
          return StreamBuilder<List<Review>>(
            stream: _reviews,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Impossible de charger les avis.\n${snap.error}',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary));
              }

              final all = snap.data!;
              final average = all.isEmpty
                  ? 0.0
                  : all.fold<int>(0, (int s, r) => s + r.rating) / all.length;
              final counts = {
                for (var n = 1; n <= 5; n++)
                  n: all.where((r) => r.rating == n).length,
              };
              final lowCount = (counts[1] ?? 0) + (counts[2] ?? 0);

              final q = _normalize(_search.text.trim());
              final list = all.where((r) {
                if (_stars != null && r.rating != _stars) return false;
                if (q.isEmpty) return true;
                return _normalize(
                        '${r.userName} ${r.comment} ${names[r.productId] ?? ''}')
                    .contains(q);
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Statistiques
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Avis publiés',
                          value: '${all.length}',
                          icon: Icons.reviews_outlined,
                          iconBackground: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: StatCard(
                          label: 'Note moyenne',
                          value: average.toStringAsFixed(1).replaceAll('.', ','),
                          icon: Icons.star_rounded,
                          iconBackground: AppColors.warningLight,
                          badge: lowCount > 0
                              ? StatusBadge('$lowCount à 1-2★',
                                  tone: BadgeTone.error)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),

                  // Répartition des notes
                  SectionCard(
                    child: Column(
                      children: [
                        for (var n = 5; n >= 1; n--)
                          _DistributionRow(
                            stars: n,
                            count: counts[n] ?? 0,
                            total: all.length,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Recherche + filtre
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Client, produit ou commentaire',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('Toutes (${all.length})', null),
                        for (var n = 5; n >= 1; n--)
                          _chip('$n★ (${counts[n]})', n),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('${list.length} avis', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.sm),

                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          const Icon(Icons.star_outline_rounded,
                              size: 56, color: AppColors.textHint),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            all.isEmpty
                                ? 'Aucun avis pour le moment.'
                                : 'Aucun avis ne correspond.',
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                    ),

                  for (final r in list)
                    _AdminReviewCard(
                      review: r,
                      productName: names[r.productId] ?? 'Produit supprimé',
                      date: _date(r.createdAt),
                      onDelete: () => _delete(
                          r, names[r.productId] ?? 'Produit supprimé'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _chip(String label, int? stars) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: _stars == stars,
          onSelected: (_) => setState(() => _stars = stars),
        ),
      );
}

/// Barre de répartition : « 5★ ████████░░ 12 »
class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.stars,
    required this.count,
    required this.total,
  });

  final int stars;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('$stars★')),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.neutralLight,
                color: stars <= 2 ? AppColors.error : AppColors.warning,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text('$count', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un avis côté admin : produit, client, note, commentaire, supprimer.
class _AdminReviewCard extends StatelessWidget {
  const _AdminReviewCard({
    required this.review,
    required this.productName,
    required this.date,
    required this.onDelete,
  });

  final Review review;
  final String productName;
  final String date;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spa_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    productName,
                    style: text.labelLarge?.copyWith(color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer l\'avis',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                ),
              ],
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.secondary,
                  child: Text(
                    review.userName.isNotEmpty
                        ? review.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName.isEmpty ? 'Client' : review.userName,
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(date, style: text.bodySmall),
                    ],
                  ),
                ),
                RatingStars(rating: review.rating, size: 18),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(review.comment, style: text.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
