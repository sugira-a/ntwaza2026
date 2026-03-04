// lib/services/wishlist_service.dart
/// Service to manage product wishlist/saved items
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class SavedProduct {
  final String productId;
  final String productName;
  final String vendorId;
  final String vendorName;
  final double price;
  final String? imageUrl;
  final DateTime savedAt;

  SavedProduct({
    required this.productId,
    required this.productName,
    required this.vendorId,
    required this.vendorName,
    required this.price,
    this.imageUrl,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'vendor_id': vendorId,
    'vendor_name': vendorName,
    'price': price,
    'image_url': imageUrl,
    'saved_at': savedAt.toIso8601String(),
  };

  factory SavedProduct.fromJson(Map<String, dynamic> json) => SavedProduct(
    productId: json['product_id'] as String,
    productName: json['product_name'] as String,
    vendorId: json['vendor_id'] as String,
    vendorName: json['vendor_name'] as String,
    price: (json['price'] as num).toDouble(),
    imageUrl: json['image_url'] as String?,
    savedAt: DateTime.parse(json['saved_at'] as String),
  );
}

class WishlistService {
  static const String _wishlistKey = 'wishlist_products';

  /// Add product to wishlist
  static Future<void> addToWishlist(Product product, String vendorName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlist = await getWishlist();
      
      // Check if already saved
      final exists = wishlist.any((p) => 
        p.productId == product.id && p.vendorId == product.vendorId);
      
      if (exists) {
        print('⚠️  Already in wishlist');
        return;
      }

      final saved = SavedProduct(
        productId: product.id,
        productName: product.name,
        vendorId: product.vendorId,
        vendorName: vendorName,
        price: product.price,
        imageUrl: product.imageUrl,
        savedAt: DateTime.now(),
      );

      wishlist.insert(0, saved);
      final jsonList = wishlist.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_wishlistKey, jsonList);
      
      print('❤️  Added to wishlist: ${product.name}');
    } catch (e) {
      print('❌ Wishlist error: $e');
    }
  }

  /// Remove from wishlist
  static Future<void> removeFromWishlist(String productId, String vendorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlist = await getWishlist();
      
      wishlist.removeWhere((p) => 
        p.productId == productId && p.vendorId == vendorId);
      
      final jsonList = wishlist.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_wishlistKey, jsonList);
      
      print('✅ Removed from wishlist');
    } catch (e) {
      print('❌ Error removing: $e');
    }
  }

  /// Get all wishlist items
  static Future<List<SavedProduct>> getWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_wishlistKey) ?? [];
      
      return jsonList
          .map((json) => SavedProduct.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('❌ Error getting wishlist: $e');
      return [];
    }
  }

  /// Check if product is saved
  static Future<bool> isSaved(String productId, String vendorId) async {
    final wishlist = await getWishlist();
    return wishlist.any((p) => 
      p.productId == productId && p.vendorId == vendorId);
  }

  /// Get wishlist count
  static Future<int> getWishlistCount() async {
    final wishlist = await getWishlist();
    return wishlist.length;
  }

  /// Clear entire wishlist
  static Future<void> clearWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wishlistKey);
  }
}
