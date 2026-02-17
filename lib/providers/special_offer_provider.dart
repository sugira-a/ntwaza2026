import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/api/api_service.dart';
import '../models/special_offer.dart';

class SpecialOfferProvider with ChangeNotifier {
  final ApiService _apiService;
  final Logger _logger = Logger();
  
  List<SpecialOffer> _specialOffers = [];
  List<SpecialOffer> _homepageOffers = [];
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<SpecialOffer> get specialOffers => _specialOffers;
  List<SpecialOffer> get homepageOffers => _homepageOffers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Filtered getters
  List<SpecialOffer> get activeOffers {
    return _specialOffers.where((offer) => offer.isActive).toList();
  }
  
  List<SpecialOffer> get validHomepageOffers {
    return _homepageOffers.where((offer) => offer.canBeShownOnHomepage).toList();
  }
  
  SpecialOfferProvider(this._apiService);
  
  // Fetch all special offers
  Future<void> fetchSpecialOffers({bool activeOnly = true}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final offers = await _apiService.getSpecialOffers(
        activeOnly: activeOnly,
        homepageOnly: false,
      );
      
      _specialOffers = offers;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.e('Error in fetchSpecialOffers: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  // Fetch homepage offers (optimized for customer home screen)
  Future<void> fetchHomepageOffers() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final offers = await _apiService.getHomepageSpecialOffers();
      
      _homepageOffers = offers;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.e('Error in fetchHomepageOffers: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  // Get offer by ID
  SpecialOffer? getOfferById(int id) {
    try {
      return _specialOffers.firstWhere((offer) => offer.id == id);
    } catch (_) {
      return null;
    }
  }
  
  // Clear state
  void clear() {
    _specialOffers = [];
    _homepageOffers = [];
    _error = null;
    notifyListeners();
  }
}