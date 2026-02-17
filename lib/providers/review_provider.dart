// lib/providers/review_provider.dart
import 'package:flutter/material.dart';
import '../models/vendor_review.dart';
import '../services/api/api_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<VendorReview> _reviews = [];
  double _averageRating = 0.0;
  Map<String, int> _ratingDistribution = {};
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<VendorReview> get reviews => _reviews;
  double get averageRating => _averageRating;
  Map<String, int> get ratingDistribution => _ratingDistribution;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Fetch reviews for a vendor
  Future<void> fetchVendorReviews(String vendorId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/api/vendors/$vendorId/reviews');
      
      if (response['success'] == true) {
        final reviewsData = response['reviews'] as List;
        _reviews = reviewsData.map((json) => VendorReview.fromJson(json)).toList();
        _averageRating = (response['average_rating'] as num).toDouble();
        _ratingDistribution = Map<String, int>.from(response['rating_distribution']);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('Error fetching reviews: $e');
    }
  }
  
  // Submit a review
  Future<bool> submitReview(String vendorId, double rating, String comment, {String? orderId}) async {
    try {
      final response = await _apiService.post(
        '/api/vendors/$vendorId/reviews',
        {
          'rating': rating,
          'comment': comment,
          if (orderId != null) 'order_id': orderId,
        },
      );
      
      if (response['success'] == true) {
        // Refresh reviews
        await fetchVendorReviews(vendorId);
        return true;
      }
      return false;
    } catch (e) {
      print('Error submitting review: $e');
      return false;
    }
  }
  
  // Mark review as helpful
  Future<void> markHelpful(int reviewId) async {
    try {
      await _apiService.post('/api/reviews/$reviewId/helpful', {});
      
      // Update local review
      final index = _reviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        _reviews[index] = VendorReview(
          id: _reviews[index].id,
          userName: _reviews[index].userName,
          rating: _reviews[index].rating,
          comment: _reviews[index].comment,
          createdAt: _reviews[index].createdAt,
          helpfulCount: _reviews[index].helpfulCount + 1,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error marking review helpful: $e');
    }
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}