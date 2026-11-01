import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// A pulsing placeholder block used while content is loading.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  const SkeletonBox.circle({super.key, double size = 40})
      : width = size,
        height = size,
        borderRadius = size / 2;

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(
          colors.skeletonBase,
          colors.skeletonHighlight,
          Curves.easeInOut.transform(_controller.value),
        );
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// A list-tile-shaped skeleton (icon + two lines + trailing amount).
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          SkeletonBox.circle(size: 44),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 90, height: 12),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(width: 70, height: 16),
        ],
      ),
    );
  }
}

/// Card-shaped skeleton for dashboard summary tiles.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: height - AppConstants.spaceMd * 2,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBox(width: 100, height: 12),
            SkeletonBox(width: 160, height: 24),
            SkeletonBox(width: 120, height: 12),
          ],
        ),
      ),
    );
  }
}
