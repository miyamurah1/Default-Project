import 'package:flutter/material.dart';

import '../theme/sakura_theme.dart';
import 'motion.dart';

/// Themed loading placeholder for a not-yet-visited tab: three rounded
/// cards matching the app's card rhythm, shimmering via [ShimmerLoading].
/// Purely presentational — announces "Loading" to screen readers.
class TabSkeleton extends StatelessWidget {
  const TabSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      container: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: const [
          _SkeletonCard(height: 130),
          SizedBox(height: 14),
          _SkeletonCard(height: 96),
          SizedBox(height: 14),
          _SkeletonCard(height: 96),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;

  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: SakuraTheme.cardDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(width: 120, height: 12),
          SizedBox(height: 14),
          ShimmerLoading(width: double.infinity, height: 10),
          SizedBox(height: 8),
          ShimmerLoading(width: 180, height: 10),
        ],
      ),
    );
  }
}
