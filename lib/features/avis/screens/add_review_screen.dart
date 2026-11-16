import 'package:flutter/material.dart';
import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/avis/services/services.dart';
import 'package:dev_mobile/features/avis/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

class AddReviewScreen extends StatefulWidget {
  const AddReviewScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.userId,
    required this.userName,
    this.onReviewAdded,
  });

  final String productId;
  final String productName;
  final String userId;
  final String userName;
  final VoidCallback? onReviewAdded;

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      setState(() => _errorMessage = 'Veuillez sélectionner une note');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final review = Review(
        id: '',
        productId: widget.productId,
        userId: widget.userId,
        userName: widget.userName,
        rating: _rating,
        comment: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await ReviewService.addReview(review);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avis ajouté avec succès')),
        );
        widget.onReviewAdded?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur lors de l\'ajout de l\'avis');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppHeader(
        subtitle: 'Nouvel avis',
        showBack: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.productName,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: 'Votre avis',
                icon: Icons.star_outline_rounded,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Note', style: text.labelLarge),
                      const SizedBox(height: AppSpacing.sm),
                      InteractiveRatingStars(
                        rating: _rating,
                        onChanged: (value) => setState(() {
                          _rating = value;
                          _errorMessage = null;
                        }),
                        size: 36,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _errorMessage!,
                          style: text.bodySmall?.copyWith(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text('Commentaire (optionnel)', style: text.labelLarge),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _commentController,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: 'Partagez votre expérience...',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value != null && value.trim().length > 500) {
                            return 'Le commentaire ne doit pas dépasser 500 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Publier l\'avis'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}