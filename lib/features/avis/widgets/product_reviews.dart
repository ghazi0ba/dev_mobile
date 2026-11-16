import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/avis/screens/add_review_screen.dart';
import 'package:dev_mobile/features/avis/screens/edit_review_screen.dart';
import 'package:dev_mobile/features/avis/services/services.dart';
import 'package:dev_mobile/features/avis/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

/// Widget à intégrer dans la fiche produit pour afficher les avis
/// et permettre d'en ajouter un.
class ProductReviews extends StatefulWidget {
  const ProductReviews({
    super.key,
    required this.product,
    required this.userId,
    required this.userName,
    this.maxReviewsToShow = 3,
  });

  final Product product;
  final String userId;
  final String userName;
  final int maxReviewsToShow;

  @override
  State<ProductReviews> createState() => _ProductReviewsState();
}

class _ProductReviewsState extends State<ProductReviews> {
  Review? _userReview;

  @override
  void initState() {
    super.initState();
    _loadUserReview();
  }

  Future<void> _loadUserReview() async {
    final review = await ReviewService.getUserReviewForProduct(
      widget.product.id,
      widget.userId,
    );
    if (mounted) {
      setState(() => _userReview = review);
    }
  }

  Future<void> _openAddReview() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddReviewScreen(
          productId: widget.product.id,
          productName: widget.product.name,
          userId: widget.userId,
          userName: widget.userName,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadUserReview();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avis ajouté avec succès')),
        );
      }
    }
  }

  Future<void> _openEditReview() async {
    if (_userReview == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditReviewScreen(
          review: _userReview!,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadUserReview();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avis modifié')),
        );
      }
    }
  }

  Future<void> _deleteReview(Review review) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer votre avis ?',
      message: 'Votre note et votre commentaire seront supprimés.',
      confirmLabel: 'Oui, supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ReviewService.deleteReview(review.id, review.productId);
      if (mounted) setState(() => _userReview = null);
      messenger.showSnackBar(
        const SnackBar(content: Text('Avis supprimé')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Résumé de la note du produit (mis à jour en direct)
        Row(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .doc(widget.product.id)
                  .snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data();
                final average = (data?['ratingAverage'] as num?)?.toDouble() ??
                    widget.product.ratingAverage;
                final count = (data?['ratingCount'] as num?)?.toInt() ??
                    widget.product.ratingCount;
                return Row(
                  children: [
                    Text(
                      average.toStringAsFixed(1),
                      style: AppTheme.serif(size: 36, weight: FontWeight.w700),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RatingStars(rating: average.round(), size: 20),
                        const SizedBox(height: 2),
                        Text(
                          '$count avis',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            if (_userReview == null)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _openAddReview,
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Laisser un avis'),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _openEditReview,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifier mon avis'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Liste des avis
        StreamBuilder<List<Review>>(
          stream: ReviewService.watchReviewsByProduct(widget.product.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final reviews = snapshot.data ?? [];

            if (reviews.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.star_outline_rounded,
                        size: 48,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Aucun avis pour ce produit',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final displayReviews = reviews.take(widget.maxReviewsToShow).toList();

            return Column(
              children: [
                // Modifier / Supprimer uniquement sur son propre avis.
                for (final r in displayReviews)
                  ReviewCard(
                    review: r,
                    onEdit: r.userId == widget.userId
                        ? () => _openEditReview()
                        : null,
                    onDelete: r.userId == widget.userId
                        ? () => _deleteReview(r)
                        : null,
                  ),
                if (reviews.length > widget.maxReviewsToShow) ...[
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // TODO: Naviguer vers l'écran complet des avis
                      },
                      child: Text('Voir les ${reviews.length - widget.maxReviewsToShow} autres avis'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}