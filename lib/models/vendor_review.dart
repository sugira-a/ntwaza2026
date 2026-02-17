// lib/models/vendor_review.dart
import '../utils/helpers.dart';
class VendorReview {
  final int id;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final int helpfulCount;

  VendorReview({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.helpfulCount,
  });

  factory VendorReview.fromJson(Map<String, dynamic> json) {
    return VendorReview(
      id: json['id'],
      userName: json['user_name'] ?? 'Anonymous',
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] ?? '',
      createdAt: parseServerTime(json['created_at']),
      helpfulCount: json['helpful_count'] ?? 0,
    );
  }
}