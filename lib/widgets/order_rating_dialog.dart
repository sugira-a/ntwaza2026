import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api/api_service.dart';

/// A professional post-delivery rating dialog that lets
/// the customer rate both the vendor and the rider.
class OrderRatingDialog extends StatefulWidget {
  final String orderId;
  final String vendorName;
  final String? riderName;
  final bool hasRider;
  final ApiService apiService;
  final bool pickupOrderMode;

  const OrderRatingDialog({
    super.key,
    required this.orderId,
    required this.vendorName,
    this.riderName,
    this.hasRider = true,
    required this.apiService,
    this.pickupOrderMode = false,
  });

  /// Show the rating dialog and return true if submitted successfully.
  static Future<bool> show(
    BuildContext context, {
    required String orderId,
    required String vendorName,
    String? riderName,
    bool hasRider = true,
    required ApiService apiService,
    bool pickupOrderMode = false,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (context, anim1, anim2) {
        return OrderRatingDialog(
          orderId: orderId,
          vendorName: vendorName,
          riderName: riderName,
          hasRider: hasRider,
          apiService: apiService,
          pickupOrderMode: pickupOrderMode,
        );
      },
    );
    return result ?? false;
  }

  @override
  State<OrderRatingDialog> createState() => _OrderRatingDialogState();
}

class _OrderRatingDialogState extends State<OrderRatingDialog>
    with SingleTickerProviderStateMixin {
  int _vendorRating = 0;
  int _riderRating = 0;
  final _vendorReviewController = TextEditingController();
  final _riderReviewController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;
  late AnimationController _checkAnimController;

  static const Color _gold = Color(0xFFFFB800);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _darkBg = Color(0xFF141414);
  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _surfaceBg = Color(0xFF262626);

  @override
  void initState() {
    super.initState();
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _vendorReviewController.dispose();
    _riderReviewController.dispose();
    _checkAnimController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // In pickup mode, only rider rating is needed
    if (!widget.pickupOrderMode && _vendorRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please rate the vendor'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    if (widget.hasRider && _riderRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please rate the rider'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String endpoint;
      final Map<String, dynamic> body;

      if (widget.pickupOrderMode) {
        // Pickup order: rate rider only via pickup-orders endpoint
        endpoint = '/api/pickup-orders/${widget.orderId}/rate';
        body = {
          'rider_rating': _riderRating,
          'rider_review': _riderReviewController.text.trim(),
        };
      } else {
        // Regular order: rate both vendor and rider
        endpoint = '/api/orders/${widget.orderId}/rate';
        body = {
          'vendor_rating': _vendorRating,
          'vendor_review': _vendorReviewController.text.trim(),
        };
        if (widget.hasRider) {
          body['rider_rating'] = _riderRating;
          body['rider_review'] = _riderReviewController.text.trim();
        }
      }

      final resp = await widget.apiService.post(endpoint, body);

      if (resp['success'] == true) {
        setState(() => _submitted = true);
        _checkAnimController.forward();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          // Navigate to home after successful rating
          context.go('/');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(resp['error']?.toString() ?? 'Failed to submit rating'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Great';
      case 5:
        return 'Excellent';
      default:
        return 'Tap to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: _darkBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: _submitted ? _buildSuccessView() : _buildRatingForm(),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _checkAnimController,
              curve: Curves.elasticOut,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 44,
                color: _green,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Thank You!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your feedback helps us improve',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.delivery_dining_rounded,
              size: 40,
              color: _green,
            ),
            const SizedBox(height: 12),
            const Text(
              'Order Delivered!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How was your experience?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.55),
              ),
            ),

            const SizedBox(height: 28),

            // Vendor Rating (only for regular orders, not pickup)
            if (!widget.pickupOrderMode) ...[
              _buildRatingSection(
              icon: Icons.store_rounded,
              title: widget.vendorName,
              subtitle: 'Rate the vendor',
              rating: _vendorRating,
              onRatingChanged: (r) => setState(() => _vendorRating = r),
              reviewController: _vendorReviewController,
              reviewHint: 'How was the food & packaging?',
            ),
            ],

            // Rider Rating
            if (widget.hasRider) ...[
              const SizedBox(height: 16),
              _buildRatingSection(
                icon: Icons.directions_bike_rounded,
                title: widget.riderName ?? 'Rider',
                subtitle: 'Rate the rider',
                rating: _riderRating,
                onRatingChanged: (r) => setState(() => _riderRating = r),
                reviewController: _riderReviewController,
                reviewHint: 'How was the delivery?',
              ),
            ],

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _green.withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),


          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required int rating,
    required ValueChanged<int> onRatingChanged,
    required TextEditingController reviewController,
    required String reviewHint,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rating > 0
              ? _gold.withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _surfaceBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: Colors.white70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (rating > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _ratingLabel(rating),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _gold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Stars
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = starIndex <= rating;
                return GestureDetector(
                  onTap: () => onRatingChanged(starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSelected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 38,
                        color: isSelected
                            ? _gold
                            : Colors.white.withOpacity(0.18),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Review text area (shown after rating)
          if (rating > 0) ...[
            const SizedBox(height: 14),
            TextField(
              controller: reviewController,
              maxLines: 2,
              maxLength: 200,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: reviewHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.25),
                ),
                filled: true,
                fillColor: _surfaceBg,
                counterStyle: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 10,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _gold.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
