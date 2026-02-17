// lib/providers/product_detail_provider.dart
import 'package:flutter/foundation.dart';
import '../models/vendor.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../services/product_service.dart';

class ProductDetailProvider with ChangeNotifier {
  final ProductService _productService;
  
  Vendor? _vendor;
  List<ProductCategory> _categories = [];
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategoryId;

  ProductDetailProvider({required ProductService productService})
      : _productService = productService;

  // Getters
  Vendor? get vendor => _vendor;
  List<ProductCategory> get categories => _categories;
  List<Product> get products => _searchQuery.isEmpty ? _allProducts : _filteredProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get isRestaurant => _vendor?.isRestaurant ?? false;

  /// Initialize vendor and load products
  Future<void> initialize(Vendor vendor) async {
    _vendor = vendor;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // DEBUG: Check vendor type
      print('🔍 DEBUG: Vendor ${vendor.name} - isRestaurant: ${vendor.isRestaurant}, vendorType: ${vendor.vendorType}');
      
      // Load categories/menus with products - PASS THE VENDOR OBJECT
      _categories = await _productService.getVendorCategories(
        vendor.id,
        vendor: vendor, // ← Pass the vendor object here
      );
      
      // Flatten all products
      _allProducts = _categories.expand((cat) => cat.products).toList();
      
      // Don't select any category - show all by default
      _selectedCategoryId = null;
      
      print('✅ Loaded ${_categories.length} ${isRestaurant ? "menus" : "categories"}, ${_allProducts.length} total products');
    } catch (e) {
      _error = 'Failed to load products: $e';
      print('❌ Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search products (local filtering for instant results)
  void searchProducts(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredProducts = [];
    } else {
      _filteredProducts = _allProducts.where((product) {
        final nameLower = product.name.toLowerCase();
        final descLower = product.description.toLowerCase();
        final queryLower = query.toLowerCase();
        return nameLower.contains(queryLower) || descLower.contains(queryLower);
      }).toList();
    }
    notifyListeners();
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _filteredProducts = [];
    notifyListeners();
  }

  /// Select category
  void selectCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }
  void clearCategorySelection() {
  _selectedCategoryId = null;
  notifyListeners();
  }

  /// Get products for a specific category
  List<Product> getProductsForCategory(String categoryId) {
    if (_searchQuery.isNotEmpty) {
      return _filteredProducts.where((p) => p.category == categoryId).toList();
    }
    
    final category = _categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => ProductCategory(
        id: '',
        name: '',
        sortOrder: 0,
        isActive: true,
        products: [],
      ),
    );
    return category.products;
  }

  /// Reload products
  Future<void> reload() async {
    if (_vendor != null) {
      await initialize(_vendor!);
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _categories.clear();
    _allProducts.clear();
    _filteredProducts.clear();
    super.dispose();
  }
}