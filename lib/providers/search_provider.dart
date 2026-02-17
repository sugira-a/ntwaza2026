import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../models/vendor.dart';
import '../models/product.dart';
import '../services/api/api_service.dart';

enum SearchFilter { all, vendors, products }

class SearchProvider with ChangeNotifier {
  final ApiService _apiService;
  final _logger = Logger();

  List<Vendor> _vendors = [];
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  SearchFilter _filter = SearchFilter.all;
  Position? _userLocation;

  SearchProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // GETTERS
  List<Vendor> get vendors => _vendors;
  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  SearchFilter get filter => _filter;
  bool get hasResults => _vendors.isNotEmpty || _products.isNotEmpty;
  int get totalResults => _vendors.length + _products.length;

  List<Vendor> get filteredVendors {
    if (_filter == SearchFilter.products) return [];
    return _vendors;
  }

  List<Product> get filteredProducts {
    if (_filter == SearchFilter.vendors) return [];
    return _products;
  }

  void setUserLocation(Position? position) {
    _userLocation = position;
  }

  void setFilter(SearchFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  // ✅ REMOVED: _calculateVendorDistances() 
  // Backend already provides all distance calculations in search results!

  // UNIFIED SEARCH
  Future<void> unifiedSearch(String query) async {
    final trimmedQuery = query.trim();
    _searchQuery = trimmedQuery;

    print('🔍 UNIFIED SEARCH: "$trimmedQuery"');

    if (trimmedQuery.isEmpty) {
      clearSearch();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📡 Calling unified search API...');
      
      // ✅ Backend calculates distances when we provide user location
      final response = await _apiService.unifiedSearch(
        query: trimmedQuery,
        userLat: _userLocation?.latitude,
        userLng: _userLocation?.longitude,
      );

      print('📦 Response received: ${response.keys}');

      // Parse vendors (with backend-calculated distances already included)
      final vendorsJson = response['vendors'] as List<dynamic>? ?? [];
      _vendors = vendorsJson.map((json) => Vendor.fromJson(json)).toList();

      // Parse products
      final productsJson = response['products'] as List<dynamic>? ?? [];
      _products = productsJson.map((json) => Product.fromJson(json)).toList();

      print('✅ Found ${_vendors.length} vendors and ${_products.length} products');
      print('✅ All distances already calculated by backend');

      // ✅ REMOVED: Google Maps distance calculation
      // Backend provides: distance_km, distance_display, delivery_fee, delivery_time, etc.

      _logger.i('✅ Unified search complete: ${_vendors.length} vendors, ${_products.length} products');
    } catch (e) {
      print('❌ Unified search error: $e');
      _error = 'Search failed. Please try again.';
      _vendors = [];
      _products = [];
      _logger.e('❌ Error in unified search: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search only vendors
  Future<void> searchVendorsOnly(String query) async {
    final trimmedQuery = query.trim();
    _searchQuery = trimmedQuery;

    if (trimmedQuery.isEmpty) {
      clearSearch();
      return;
    }

    _isLoading = true;
    _error = null;
    _filter = SearchFilter.vendors;
    notifyListeners();

    try {
      // ✅ Backend calculates distances
      final response = await _apiService.searchVendors(
        query: trimmedQuery,
        userLat: _userLocation?.latitude,
        userLng: _userLocation?.longitude,
      );

      final vendorsJson = response['vendors'] as List<dynamic>? ?? [];
      _vendors = vendorsJson.map((json) => Vendor.fromJson(json)).toList();
      _products = [];

      // ✅ REMOVED: Distance calculation - backend handles it!
      _logger.i('✅ Vendor search complete: ${_vendors.length} vendors with backend distances');
    } catch (e) {
      _error = 'Vendor search failed. Please try again.';
      _vendors = [];
      _logger.e('❌ Error searching vendors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search only products
  Future<void> searchProductsOnly(String query) async {
    final trimmedQuery = query.trim();
    _searchQuery = trimmedQuery;

    if (trimmedQuery.isEmpty) {
      clearSearch();
      return;
    }

    _isLoading = true;
    _error = null;
    _filter = SearchFilter.products;
    notifyListeners();

    try {
      final response = await _apiService.searchProducts(query: trimmedQuery);

      final productsJson = response['products'] as List<dynamic>? ?? [];
      _products = productsJson.map((json) => Product.fromJson(json)).toList();
      _vendors = [];

      _logger.i('✅ Product search complete: ${_products.length} products');
    } catch (e) {
      _error = 'Product search failed. Please try again.';
      _products = [];
      _logger.e('❌ Error searching products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _vendors = [];
    _products = [];
    _error = null;
    _filter = SearchFilter.all;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_searchQuery.isNotEmpty) {
      await unifiedSearch(_searchQuery);
    }
  }
}