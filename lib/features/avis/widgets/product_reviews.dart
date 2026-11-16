import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.maxReviewsToShow = 3,
  });

  final Product product;
  final int maxReviewsToShow;

  @override
  State<ProductReviews> createState() => _ProductReviewsState();
}

class _ProductReviewsState extends State<ProductReviews> {
  Review? _userReview;
  String? _currentUserId;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _currentUserId = null;
        _isLoadingUser = false;
      });
      return;
    }

    _currentUserId = user.uid;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      // _currentUserName is set but not used directly in this widget
    } catch (e) {
      // Ignore errors
    } finally {
      if (mounted) {
        setState(() => _isLoadingUser = false);
        _loadUserReview();
      }
    }
  }

  Future<void> _loadUserReview() async {
    if (_currentUserId == null) {
      setState(() => _userReview = null);
      return;
    }

    final review = await ReviewService.getUserReviewForProduct(
      widget.product.id,
      _currentUserId!,
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (_isLoadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Résumé de la note du produit
        Row(
          children: [
            Text(
              widget.product.ratingAverage.toStringAsFixed(1),
              style: AppTheme.serif(size: 36, weight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RatingStars(
                  rating: widget.product.ratingAverage.round(),
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.product.ratingCount} avis',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (_currentUserId == null)
              Text('Connectez-vous pour laisser un avis', style: text.bodyMedium)
            else if (_userReview == null)
              FilledButton.icon(
                onPressed: _openAddReview,
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Laisser un avis'),
              )
            else
              OutlinedButton.icon(
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
                ReviewCardList(
                  reviews: displayReviews,
                  onEdit: _userReview != null
                      ? (r) {
                          if (r.id == _userReview!.id) {
                            _openEditReview();
                          }
                        }
                      : null,
                  onDelete: _userReview != null
                      ? (r) {
                          if (r.id == _userReview!.id) {
                            _openEditReview();
                          }
                        }
                      : null,
                  emptyMessage: '',
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