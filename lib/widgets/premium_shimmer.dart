import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme.dart';

class PremiumShimmer extends StatelessWidget {
  final Widget child;
  const PremiumShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceGlass,
      highlightColor: AppTheme.electricCyan.withValues(alpha: 0.1),
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}

// A standard glowing box we can shape however we want
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({super.key, required this.width, required this.height, this.borderRadius = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // Shimmer package uses white to mask the colors
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}