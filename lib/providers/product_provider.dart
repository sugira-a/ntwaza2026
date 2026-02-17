import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api/api_service.dart';
import '../services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ProductService _productService = ProductService();
  
  List<Product> _allProducts = [];
  Map<String, List<Product>> _productsByVendor = {};
  Map<String, List<Product>> _productsByCategory = {};
  
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Product> get allProducts => _allProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Get the products for the current vendor (if stored)
  List<Product> get currentVendorProducts {
    // Return the first vendor's products (most recent fetch)
    if (_productsByVendor.isNotEmpty) {
      return _productsByVendor.values.first;
    }
    return [];
  }
  
  List<Product> getProductsByVendor(String vendorId) {
    final products = _productsByVendor[vendorId] ?? [];
    print('📦 getProductsByVendor($vendorId): ${products.length} products');
    return products;
  }
  
  List<Product> getProductsByCategory(String category) {
    return _productsByCategory[category] ?? [];
  }

  // Fetch products for a specific vendor
  Future<void> fetchVendorProducts(String vendorId, {bool isRestaurant = false}) async {
    print('🔍 fetchVendorProducts called for vendor: $vendorId (Restaurant: $isRestaurant)');
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final products = await _productService.getVendorProducts(
        vendorId,
        isRestaurantOverride: isRestaurant,
      );
      _productsByVendor[vendorId] = products;
      _isLoading = false;
      
      print('📦 Stored ${products.length} products for vendor $vendorId');
      print('📦 Current _productsByVendor keys: ${_productsByVendor.keys}');
      
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Error fetching vendor products: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch all products
  Future<void> fetchAllProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/api/products');
      
      final List<dynamic> productsJson = response['products'] ?? response['data'] ?? [];
      _allProducts = productsJson.map((json) => Product.fromJson(json)).toList();
      
      // Organize by category
      _productsByCategory.clear();
      for (var product in _allProducts) {
        if (!_productsByCategory.containsKey(product.category)) {
          _productsByCategory[product.category] = [];
        }
        _productsByCategory[product.category]!.add(product);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('Error fetching all products: $e');
    }
  }

  // Fetch products by category
  Future<void> fetchProductsByCategory(String category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/api/products?category=$category');
      
      final List<dynamic> productsJson = response['products'] ?? response['data'] ?? [];
      final products = productsJson.map((json) => Product.fromJson(json)).toList();
      
      _productsByCategory[category] = products;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('Error fetching products by category: $e');
    }
  }

  // Search products
  Future<void> searchProducts(String query) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/api/products/search?q=$query');
      
      final List<dynamic> productsJson = response['products'] ?? response['data'] ?? [];
      _allProducts = productsJson.map((json) => Product.fromJson(json)).toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('Error searching products: $e');
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data
  void clear() {
    _allProducts = [];
    _productsByVendor = {};
    _productsByCategory = {};
    _error = null;
    notifyListeners();
  }
}