// lib/services/favorite_vendors_service.dart
/// Service to manage favorite vendors
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vendor.dart';

class FavoriteVendor {
  final String vendorId;
  final String vendorName;
  final String vendorType;
  final double? rating;
  final String? imageUrl;
  final DateTime savedAt;

  FavoriteVendor({
    required this.vendorId,
    required this.vendorName,
    required this.vendorType,
    this.rating,
    this.imageUrl,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'vendor_id': vendorId,
    'vendor_name': vendorName,
    'vendor_type': vendorType,
    'rating': rating,
    'image_url': imageUrl,
    'saved_at': savedAt.toIso8601String(),
  };

  factory FavoriteVendor.fromJson(Map<String, dynamic> json) => FavoriteVendor(
    vendorId: json['vendor_id'] as String,
    vendorName: json['vendor_name'] as String,
    vendorType: json['vendor_type'] as String,
    rating: (json['rating'] as num?)?.toDouble(),
    imageUrl: json['image_url'] as String?,
    savedAt: DateTime.parse(json['saved_at'] as String),
  );

  factory FavoriteVendor.fromVendor(Vendor vendor) => FavoriteVendor(
    vendorId: vendor.id,
    vendorName: vendor.name,
    vendorType: vendor.vendorType ?? 'supermarket',
    rating: vendor.rating,
    imageUrl: vendor.imageUrl,
    savedAt: DateTime.now(),
  );
}

class FavoriteVendorsService {
  static const String _favoritesKey = 'favorite_vendors';

  /// Add vendor to favorites
  static Future<void> addFavorite(Vendor vendor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();

      if (favorites.any((v) => v.vendorId == vendor.id)) {
        print('⚠️  Already favorited');
        return;
      }

      final favorite = FavoriteVendor.fromVendor(vendor);
      favorites.insert(0, favorite);

      final jsonList = favorites
          .map((v) => jsonEncode(v.toJson()))
          .toList();
      await prefs.setStringList(_favoritesKey, jsonList);

      print('⭐ Added to favorites: ${vendor.name}');
    } catch (e) {
      print('❌ Error adding favorite: $e');
    }
  }

  /// Remove from favorites
  static Future<void> removeFavorite(String vendorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();

      favorites.removeWhere((v) => v.vendorId == vendorId);

      final jsonList = favorites
          .map((v) => jsonEncode(v.toJson()))
          .toList();
      await prefs.setStringList(_favoritesKey, jsonList);

      print('✅ Removed from favorites');
    } catch (e) {
      print('❌ Error removing favorite: $e');
    }
  }

  /// Get all favorite vendors
  static Future<List<FavoriteVendor>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_favoritesKey) ?? [];

      return jsonList
          .map((json) => FavoriteVendor.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('❌ Error getting favorites: $e');
      return [];
    }
  }

  /// Check if vendor is favorited
  static Future<bool> isFavorited(String vendorId) async {
    final favorites = await getFavorites();
    return favorites.any((v) => v.vendorId == vendorId);
  }

  /// Get favorite count
  static Future<int> getFavoriteCount() async {
    final favorites = await getFavorites();
    return favorites.length;
  }

  /// Clear all favorites
  static Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
  }
}
