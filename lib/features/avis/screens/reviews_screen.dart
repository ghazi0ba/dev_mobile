import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/avis/screens/add_review_screen.dart';
import 'package:dev_mobile/features/avis/screens/edit_review_screen.dart';
import 'package:dev_mobile/features/avis/services/services.dart';
import 'package:dev_mobile/features/avis/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        // _currentUserName is fetched but not used directly in this screen
      }
    } catch (e) {
      // Ignore errors
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _openAddReview(Product product) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour laisser un avis')),
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddReviewScreen(
          productId: product.id,
          productName: product.name,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avis ajouté')),
      );
    }
  }

  Future<void> _openEditReview(Review review) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditReviewScreen(
          review: review,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avis modifié')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (_isLoadingUser) {
      return const Scaffold(
        appBar: AppHeader(subtitle: 'Avis'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const AppHeader(subtitle: 'Avis'),
      body: StreamBuilder<List<Review>>(
        stream: ReviewService.watchReviewsByProduct('test-product'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Erreur de chargement',
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    snapshot.error.toString(),
                    style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final reviews = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              SectionCard(
                title: 'Tous les avis',
                icon: Icons.star_outline_rounded,
                child: Column(
                  children: [
                    if (reviews.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.star_outline_rounded,
                              size: 64,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Aucun avis pour le moment',
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ReviewCardList(
                        reviews: reviews,
                        onEdit: (review) => _openEditReview(review),
                        onDelete: (review) => _openEditReview(review),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_currentUserId != null) ...[
                SectionCard(
                  title: 'Tester l\'ajout d\'avis',
                  icon: Icons.add_circle_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sélectionnez un produit pour tester l\'ajout d\'avis :',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _TestProductChip(
                            label: 'Sérum Vitamine C',
                            productId: 'test-product-1',
                            onTap: () => _openAddReview(Product(
                              id: 'test-product-1',
                              name: 'Sérum Vitamine C',
                              price: 29.90,
                              stock: 10,
                              categoryId: 'cat-1',
                            )),
                          ),
                          _TestProductChip(
                            label: 'Crème Hydratante',
                            productId: 'test-product-2',
                            onTap: () => _openAddReview(Product(
                              id: 'test-product-2',
                              name: 'Crème Hydratante',
                              price: 24.50,
                              stock: 15,
                              categoryId: 'cat-1',
                            )),
                          ),
                          _TestProductChip(
                            label: 'Huile Visage Bio',
                            productId: 'test-product-3',
                            onTap: () => _openAddReview(Product(
                              id: 'test-product-3',
                              name: 'Huile Visage Bio',
                              price: 34.90,
                              stock: 8,
                              categoryId: 'cat-1',
                            )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SectionCard(
                  title: 'Connexion requise',
                  icon: Icons.lock_outline,
                  child: Text(
                    'Connectez-vous pour laisser un avis',
                    style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TestProductChip extends StatelessWidget {
  const _TestProductChip({
    required this.label,
    required this.productId,
    required this.onTap,
  });

  final String label;
  final String productId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: const Icon(Icons.add_circle_outline, size: 18),
    );
  }
}