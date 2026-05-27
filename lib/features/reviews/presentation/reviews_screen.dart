// lib/features/reviews/presentation/reviews_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/review_provider.dart';
import '../domain/review_model.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  final String? barberId;
  final String? appointmentId;
  final bool canReview;

  const ReviewsScreen({
    super.key,
    this.barberId,
    this.appointmentId,
    this.canReview = false,
  });

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(reviewsProvider(widget.barberId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Reviews',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: widget.canReview && widget.barberId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showReviewDialog(context, ref),
              icon: const Icon(Icons.rate_review),
              label: const Text('Write Review'),
            )
          : null,
      body: reviewsAsync.when(
        data: (reviews) {
          if (reviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_border,
                      size: 80, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('No reviews yet',
                      style: GoogleFonts.playfairDisplay(
                          color: AppTheme.textSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Be the first to leave a review!',
                      style: GoogleFonts.dmSans(color: AppTheme.textHint)),
                ],
              ),
            );
          }

          // Stats summary
          final avgRating =
              reviews.fold<double>(0, (sum, r) => sum + r.rating) /
                  reviews.length;
          final ratingCounts = List.generate(5, (i) {
            final star = 5 - i;
            return reviews.where((r) => r.rating == star).length;
          });

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child:
                    _buildRatingSummary(reviews.length, avgRating, ratingCounts)
                        .animate()
                        .fadeIn(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) => _buildReviewCard(reviews[index], index),
                    childCount: reviews.length,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(error: e.toString()),
      ),
    );
  }

  Widget _buildRatingSummary(int total, double avg, List<int> counts) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Big rating number
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: GoogleFonts.playfairDisplay(
                  color: AppTheme.secondary,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _buildStarRow(avg.round(), size: 20),
              const SizedBox(height: 4),
              Text(
                '$total review${total != 1 ? 's' : ''}',
                style:
                    GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Rating bars
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = counts[i];
                final pct = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('$star',
                          style: GoogleFonts.dmSans(
                              color: AppTheme.textHint, fontSize: 12)),
                      const SizedBox(width: 6),
                      const Icon(Icons.star,
                          color: AppTheme.secondary, size: 12),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppTheme.surface,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.secondary),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text('$count',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textHint, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                child: Text(
                  review.customerName.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.dmSans(
                      color: AppTheme.secondary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.customerName,
                        style: GoogleFonts.dmSans(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(review.timeAgo,
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textHint, fontSize: 12)),
                  ],
                ),
              ),
              _buildStarRow(review.rating, size: 16),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment!,
              style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'for ${review.barberName}',
            style: GoogleFonts.dmSans(
              color: AppTheme.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.05);
  }

  Widget _buildStarRow(int rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: AppTheme.secondary,
          size: size,
        );
      }),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    int selectedRating = 5;
    final commentCtrl = TextEditingController();
    final user = ref.read(authStateProvider).value;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Write a Review',
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How was your experience?',
                style: GoogleFonts.dmSans(
                    color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedRating = i + 1),
                    child: Icon(
                      i < selectedRating ? Icons.star : Icons.star_border,
                      color: AppTheme.secondary,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: commentCtrl,
                label: 'Comment (optional)',
                hint: 'Share your experience...',
                maxLines: 4,
                prefixIcon: Icons.comment_outlined,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (user == null ||
                    widget.barberId == null ||
                    widget.appointmentId == null) {
                  return;
                }
                Navigator.pop(ctx);
                final success = await ref
                    .read(reviewNotifierProvider.notifier)
                    .createReview(
                      customerId: user.id,
                      barberId: widget.barberId!,
                      appointmentId: widget.appointmentId!,
                      rating: selectedRating,
                      comment: commentCtrl.text.isEmpty
                          ? null
                          : commentCtrl.text.trim(),
                    );
                if (success) {
                  ref.invalidate(reviewsProvider(widget.barberId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Review submitted! Thank you.'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                }
              },
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }
}
