import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/avis/widgets/rating_stars.dart';
import 'package:dev_mobile/shared/models/models.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.onEdit,
    this.onDelete,
    this.showProductName = false,
  });

  final Review review;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showProductName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    review.userName.isNotEmpty
                        ? review.userName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (review.createdAt != null)
                        Text(
                          dateFormat.format(review.createdAt!),
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                RatingStars(
                  rating: review.rating,
                  size: 18,
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                review.comment,
                style: text.bodyMedium,
              ),
            ],
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifier'),
                    ),
                  if (onDelete != null) ...[
                    if (onEdit != null) const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Supprimer'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReviewCardList extends StatelessWidget {
  const ReviewCardList({
    super.key,
    required this.reviews,
    this.onEdit,
    this.onDelete,
    this.emptyMessage = 'Aucun avis pour le moment',
  });

  final List<Review> reviews;
  final void Function(Review)? onEdit;
  final void Function(Review)? onDelete;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_outline_rounded,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index];
        return ReviewCard(
          review: review,
          onEdit: onEdit != null ? () => onEdit!(review) : null,
          onDelete: onDelete != null ? () => onDelete!(review) : null,
        );
      },
    );
  }
}