import 'package:flutter/material.dart';

import 'package:dev_mobile/core/widgets/widgets.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 20,
    this.color = AppColors.warning,
    this.allowHalf = false,
    this.onTap,
    this.initialRating,
  });

  final int rating;
  final int maxRating;
  final double size;
  final Color color;
  final bool allowHalf;
  final ValueChanged<int>? onTap;
  final int? initialRating;

  @override
  Widget build(BuildContext context) {
    final displayRating = initialRating ?? rating;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final starIndex = index + 1;
        final isFilled = starIndex <= displayRating;
        final isHalf = allowHalf && starIndex == displayRating + 1 && displayRating < maxRating;

        return GestureDetector(
          onTap: onTap != null ? () => onTap!(starIndex) : null,
          child: Icon(
            isHalf ? Icons.star_half : (isFilled ? Icons.star : Icons.star_border),
            size: size,
            color: isFilled || isHalf ? color : AppColors.border,
          ),
        );
      }),
    );
  }
}

class InteractiveRatingStars extends StatefulWidget {
  const InteractiveRatingStars({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 28,
    this.color = AppColors.warning,
  });

  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;
  final Color color;

  @override
  State<InteractiveRatingStars> createState() => _InteractiveRatingStarsState();
}

class _InteractiveRatingStarsState extends State<InteractiveRatingStars> {
  late int _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.rating;
  }

  @override
  void didUpdateWidget(covariant InteractiveRatingStars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rating != widget.rating) {
      _currentRating = widget.rating;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () {
            setState(() => _currentRating = starIndex);
            widget.onChanged?.call(starIndex);
          },
          child: Icon(
            starIndex <= _currentRating ? Icons.star : Icons.star_border,
            size: widget.size,
            color: starIndex <= _currentRating ? widget.color : AppColors.border,
          ),
        );
      }),
    );
  }
}