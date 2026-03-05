// lib/providers/product_detail_provider.dart
import 'package:flutter/foundation.dart';
import '../models/vendor.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../services/product_service.dart';

class _VendorCache {
  final List<ProductCategory> categories;
  final List<Product> products;
  final DateTime timestamp;

  _VendorCache({required this.categories, required this.products})
      : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > const Duration(minutes: 5);
}

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

  // Cache: vendorId → (categories, products, timestamp)
  final Map<String, _VendorCache> _cache = {};
  static const _cacheDuration = Duration(minutes: 5);

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
    _searchQuery = '';
    _filteredProducts = [];
    _selectedCategoryId = null;
    _error = null;

    // Check cache first — show instantly if available
    final cached = _cache[vendor.id];
    if (cached != null && !cached.isExpired) {
      _categories = cached.categories;
      _allProducts = cached.products;
      _isLoading = false;
      notifyListeners();
      // Refresh in background silently
      _refreshInBackground(vendor);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _productService.getVendorCategories(
        vendor.id,
        vendor: vendor,
      );
      _allProducts = _categories.expand((cat) => cat.products).toList();
      
      // Store in cache
      _cache[vendor.id] = _VendorCache(categories: _categories, products: _allProducts);
    } catch (e) {
      _error = 'Failed to load products: $e';
      print('❌ Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Silently refresh cached data in background
  Future<void> _refreshInBackground(Vendor vendor) async {
    try {
      final categories = await _productService.getVendorCategories(vendor.id, vendor: vendor);
      final products = categories.expand((cat) => cat.products).toList();
      _cache[vendor.id] = _VendorCache(categories: categories, products: products);
      // Only update UI if this vendor is still being viewed
      if (_vendor?.id == vendor.id) {
        _categories = categories;
        _allProducts = products;
        notifyListeners();
      }
    } catch (_) {}
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