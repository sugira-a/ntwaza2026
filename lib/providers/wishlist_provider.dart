// lib/providers/wishlist_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class WishlistProvider with ChangeNotifier {
  static const _storageKey = 'wishlist_product_ids';
  static const _productsKey = 'wishlist_products_cache';

  final Set<String> _wishlistIds = {};
  final Map<String, Product> _productsCache = {};
  bool _initialized = false;

  // Getters
  Set<String> get wishlistIds => Set.unmodifiable(_wishlistIds);
  List<Product> get wishlistProducts => _productsCache.values.toList();
  int get count => _wishlistIds.length;
  bool get isEmpty => _wishlistIds.isEmpty;

  bool isWishlisted(String productId) => _wishlistIds.contains(productId);

  /// Initialize from SharedPreferences
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_storageKey) ?? [];
      _wishlistIds.addAll(ids);

      // Load cached product data
      final cachedJson = prefs.getString(_productsKey);
      if (cachedJson != null) {
        final List<dynamic> list = jsonDecode(cachedJson);
        for (final item in list) {
          try {
            final product = Product.fromJson(item);
            _productsCache[product.id] = product;
          } catch (_) {}
        }
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      print('⚠️ Wishlist init error: $e');
    }
  }

  /// Toggle product in wishlist
  Future<void> toggleWishlist(Product product) async {
    if (_wishlistIds.contains(product.id)) {
      _wishlistIds.remove(product.id);
      _productsCache.remove(product.id);
    } else {
      _wishlistIds.add(product.id);
      _productsCache[product.id] = product;
    }
    notifyListeners();
    await _persist();
  }

  /// Add product to wishlist
  Future<void> addToWishlist(Product product) async {
    if (_wishlistIds.contains(product.id)) return;
    _wishlistIds.add(product.id);
    _productsCache[product.id] = product;
    notifyListeners();
    await _persist();
  }

  /// Remove product from wishlist
  Future<void> removeFromWishlist(String productId) async {
    _wishlistIds.remove(productId);
    _productsCache.remove(productId);
    notifyListeners();
    await _persist();
  }

  /// Clear all wishlist items
  Future<void> clearWishlist() async {
    _wishlistIds.clear();
    _productsCache.clear();
    notifyListeners();
    await _persist();
  }

  /// Persist to SharedPreferences
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _wishlistIds.toList());

      // Cache product data for offline display
      final productsJson = _productsCache.values
          .map((p) => p.toJson())
          .toList();
      await prefs.setString(_productsKey, jsonEncode(productsJson));
    } catch (e) {
      print('⚠️ Wishlist persist error: $e');
    }
  }
}
