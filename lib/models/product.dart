// lib/models/product.dart
// FIXED: vendorId is now non-nullable (required)

import '../services/api/api_service.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final String category;
  final String? subcategory;
  final bool isAvailable;
  final int? stockQuantity;
  final String? unit;
  final double? unitQuantity;
  
  // Vendor information
  final String? vendorName;
  final String vendorId; // FIXED: Changed from String? to String (non-nullable)
  
  // Restaurant-specific fields
  final int? preparationTime;
  final String? servingSize;
  final int? calories;
  final String? spiceLevel;
  final List<String>? ingredients;
  final List<String>? allergens;
  final List<String>? dietaryInfo;
  final bool? isPopular;
  final bool? isFeatured;
  final double? rating;
  final int? ratingCount;
  
  // Modifiers (for customization)
  final List<ProductModifier>? modifiers;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    required this.category,
    this.subcategory,
    required this.isAvailable,
    this.stockQuantity,
    this.unit,
    this.unitQuantity,
    this.vendorName,
    required this.vendorId, // FIXED: Now required instead of optional
    this.preparationTime,
    this.servingSize,
    this.calories,
    this.spiceLevel,
    this.ingredients,
    this.allergens,
    this.dietaryInfo,
    this.isPopular,
    this.isFeatured,
    this.rating,
    this.ratingCount,
    this.modifiers,
  });

  /// Build a full URL for product images
  static String _buildProductImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final trimmed = value.trim();
    var normalized = trimmed.replaceAll('\\', '/');

    // Already a full URL
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      // PERMANENT FIX: Redirect catalog URLs to products folder
      if (normalized.contains('/static/uploads/catalog/')) {
        final filename = normalized.split('/').last;
        return '${ApiService.baseUrl}/static/uploads/products/$filename';
      }
      return normalized;
    }
    
    // Fix common backend path issues
    if (normalized.startsWith('/static/products/')) {
      normalized = normalized.replaceFirst('/static/products/', '/static/uploads/products/');
    }
    
    // PERMANENT FIX: Redirect catalog paths to products folder
    if (normalized.contains('/static/uploads/catalog/')) {
      final filename = normalized.split('/').last;
      return '${ApiService.baseUrl}/static/uploads/products/$filename';
    }
    
    // General /static/ paths
    if (normalized.startsWith('/static/')) {
      return '${ApiService.baseUrl}$normalized';
    }
    
    // Relative URL starting with /
    if (normalized.startsWith('/')) {
      return '${ApiService.baseUrl}$normalized';
    }
    
    // Relative URL starting with static/
    if (normalized.startsWith('static/')) {
      return '${ApiService.baseUrl}/$normalized';
    }
    
    // Just the filename - assume it's in uploads/products folder
    return '${ApiService.baseUrl}/static/uploads/products/$normalized';
  }

  /// Helper to parse fields that can be either String or List
  static List<String>? _parseStringOrList(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // If it's an empty string, return null
      if (value.isEmpty) return null;
      // If it's a string, wrap it in a list
      return [value];
    }
    if (value is List) {
      // If it's already a list, convert all items to strings
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawImageUrl = json['image_url'] ?? '';
    final processedImageUrl = _buildProductImageUrl(rawImageUrl);
    
    print('🖼️ Product image: "$rawImageUrl" → "$processedImageUrl"');
    
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      originalPrice: json['original_price'] != null ? (json['original_price'] as num).toDouble() : null,
      imageUrl: processedImageUrl,
      category: json['category'] ?? '',
      subcategory: json['subcategory'],
      isAvailable: json['is_available'] ?? true,
      stockQuantity: json['stock_quantity'],
      unit: json['unit'],
      unitQuantity: json['unit_quantity'] != null ? (json['unit_quantity'] as num).toDouble() : null,
      vendorName: json['vendor_name'],
      // FIXED: Ensure vendorId is never null by providing a default or throwing error
      vendorId: json['vendor_id']?.toString() ?? 
                json['business_id']?.toString() ?? 
                '0', // Fallback to '0' if no vendor_id provided
      preparationTime: json['preparation_time'],
      servingSize: json['serving_size'],
      calories: json['calories'],
      spiceLevel: json['spice_level'],
      // FIXED: Handle both String and List for these fields
      ingredients: _parseStringOrList(json['ingredients']),
      allergens: _parseStringOrList(json['allergens']),
      dietaryInfo: _parseStringOrList(json['dietary_info']),
      isPopular: json['is_popular'],
      isFeatured: json['is_featured'],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      ratingCount: json['rating_count'],
      modifiers: json['modifiers'] != null 
        ? (json['modifiers'] as List).map((m) => ProductModifier.fromJson(m)).toList()
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'original_price': originalPrice,
      'image_url': imageUrl,
      'category': category,
      'subcategory': subcategory,
      'is_available': isAvailable,
      'stock_quantity': stockQuantity,
      'unit': unit,
      'unit_quantity': unitQuantity,
      'vendor_name': vendorName,
      'vendor_id': vendorId,
      'preparation_time': preparationTime,
      'serving_size': servingSize,
      'calories': calories,
      'spice_level': spiceLevel,
      'ingredients': ingredients,
      'allergens': allergens,
      'dietary_info': dietaryInfo,
      'is_popular': isPopular,
      'is_featured': isFeatured,
      'rating': rating,
      'rating_count': ratingCount,
      'modifiers': modifiers?.map((m) => m.toJson()).toList(),
    };
  }
}

class ProductModifier {
  final String id;
  final String name;
  final String? description;
  final bool isRequired;
  final int minSelections;
  final int maxSelections;
  final List<ModifierOption> options;

  ProductModifier({
    required this.id,
    required this.name,
    this.description,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.options,
  });

  factory ProductModifier.fromJson(Map<String, dynamic> json) {
    return ProductModifier(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      isRequired: json['is_required'] ?? false,
      minSelections: json['min_selections'] ?? 0,
      maxSelections: json['max_selections'] ?? 1,
      options: (json['options'] as List?)?.map((o) => ModifierOption.fromJson(o)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_required': isRequired,
      'min_selections': minSelections,
      'max_selections': maxSelections,
      'options': options.map((o) => o.toJson()).toList(),
    };
  }
}

class ModifierOption {
  final String id;
  final String name;
  final String? description;
  final double priceAdjustment;
  final bool isDefault;
  final bool isAvailable;

  ModifierOption({
    required this.id,
    required this.name,
    this.description,
    required this.priceAdjustment,
    required this.isDefault,
    required this.isAvailable,
  });

  factory ModifierOption.fromJson(Map<String, dynamic> json) {
    return ModifierOption(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      priceAdjustment: (json['price_adjustment'] ?? 0).toDouble(),
      isDefault: json['is_default'] ?? false,
      isAvailable: json['is_available'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price_adjustment': priceAdjustment,
      'is_default': isDefault,
      'is_available': isAvailable,
    };
  }
}