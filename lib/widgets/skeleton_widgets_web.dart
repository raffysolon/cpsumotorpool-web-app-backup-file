import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable skeleton widgets for web app loading states
class SkeletonWidgetsWeb {
  /// Basic box skeleton with rounded corners
  static Widget box({
    required double width,
    required double height,
    double borderRadius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Circle skeleton (for avatars or icons)
  static Widget circle({required double size}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Skeleton for active trip card on dashboard
  static Widget activeTripCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 248),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title skeleton
          box(width: 150, height: 24, borderRadius: 4),
          const SizedBox(height: 16),
          // Route text skeleton
          box(width: double.infinity, height: 20, borderRadius: 4),
          const SizedBox(height: 12),
          // Departure time skeleton
          box(width: 250, height: 18, borderRadius: 4),
          const SizedBox(height: 24),
          // Button skeleton
          Align(
            alignment: Alignment.centerRight,
            child: box(width: 120, height: 40, borderRadius: 8),
          ),
        ],
      ),
    );
  }

  /// Skeleton for trip list item card
  static Widget tripCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon skeleton
              circle(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route text skeleton
                    box(width: double.infinity, height: 18, borderRadius: 4),
                    const SizedBox(height: 8),
                    // Date skeleton
                    box(width: 150, height: 14, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status badge skeleton
          box(width: 80, height: 24, borderRadius: 12),
        ],
      ),
    );
  }

  /// Skeleton for trip list (multiple cards)
  static Widget tripList({int itemCount = 3}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => tripCard(),
    );
  }

  /// Skeleton for dashboard stats cards
  static Widget statsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number skeleton
          box(width: 60, height: 32, borderRadius: 4),
          const SizedBox(height: 8),
          // Label skeleton
          box(width: 100, height: 16, borderRadius: 4),
        ],
      ),
    );
  }

  /// Skeleton for admin trip table row
  static Widget tripTableRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // Driver name
          Expanded(
            flex: 2,
            child: box(width: 100, height: 16, borderRadius: 4),
          ),
          const SizedBox(width: 12),
          // Route
          Expanded(
            flex: 3,
            child: box(width: 150, height: 16, borderRadius: 4),
          ),
          const SizedBox(width: 12),
          // Date
          Expanded(
            flex: 2,
            child: box(width: 80, height: 16, borderRadius: 4),
          ),
          const SizedBox(width: 12),
          // Status badge
          box(width: 70, height: 24, borderRadius: 12),
        ],
      ),
    );
  }

  /// Skeleton for admin trip table (multiple rows)
  static Widget tripTable({int rowCount = 5}) {
    return Column(
      children: List.generate(
        rowCount,
        (index) => tripTableRow(),
      ),
    );
  }
}
