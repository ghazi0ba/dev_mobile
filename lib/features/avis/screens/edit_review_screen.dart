import 'package:flutter/material.dart';
import 'package:dev_mobile/core/widgets/widgets.dart';
import 'package:dev_mobile/features/avis/services/services.dart';
import 'package:dev_mobile/features/avis/widgets/widgets.dart';
import 'package:dev_mobile/shared/models/models.dart';

class EditReviewScreen extends StatefulWidget {
  const EditReviewScreen({
    super.key,
    required this.review,
    this.onReviewUpdated,
  });

  final Review review;
  final VoidCallback? onReviewUpdated;

  @override
  State<EditReviewScreen> createState() => _EditReviewScreenState();
}

class _EditReviewScreenState extends State<EditReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _commentController;
  late int _rating;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.review.comment);
    _rating = widget.review.rating;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ReviewService.updateReview(widget.review.id, {
        'rating': _rating,
        'comment': _commentController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avis modifié avec succès')),
        );
        widget.onReviewUpdated?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur lors de la modification');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer cet avis ?',
      message: 'Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await ReviewService.deleteReview(widget.review.id, widget.review.productId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avis supprimé')),
        );
        widget.onReviewUpdated?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la suppression')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppHeader(
        subtitle: 'Modifier l\'avis',
        showBack: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.error,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              : const Text('Enregistrer les modifications'),
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