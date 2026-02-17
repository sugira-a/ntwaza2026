// lib/models/vendor.dart
// Fixed Vendor Model with grocery type support

import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api/api_service.dart';

// Define enum BEFORE it's used
enum VendorType {
  restaurant,  // Uses menu system
  product,     // Uses product listings (shops, supermarkets, groceries)
}

extension VendorTypeExtension on VendorType {
  String get displayName {
    switch (this) {
      case VendorType.restaurant:
        return 'Restaurant';
      case VendorType.product:
        return 'Shop';
    }
  }
  
  IconData get icon {
    switch (this) {
      case VendorType.restaurant:
        return Icons.restaurant;
      case VendorType.product:
        return Icons.shopping_bag;
    }
  }
}

// Vendor class
class Vendor with ChangeNotifier {
  final String id;
  final String name;
  final String category;
  final String logoUrl;
  final double rating;
  final int totalRatings;
  final double? latitude;
  final double? longitude;
  final int prepTimeMinutes;
  final double deliveryRadiusKm;
  
  // Distance fields from backend
  final double? distanceKm;
  final String? distanceDisplay;
  final int? estimatedDeliveryTimeMinutes;
  final String? estimatedDeliveryDisplay;
  final double deliveryFee;
  final bool distanceIsEstimate;
  
  // Delivery info
  bool isDeliverable = true;
  bool isOpen = true;
  String? deliveryWarning;
  
  // Extra fields
  bool isNew = false;
  String? bannerUrl;
  String? description;
  List<String> categories = [];
  
  // Phone field
  String? phone;
  
  // Working hours from backend
  Map<String, dynamic>? workingHours;
  
  // Vendor Type (restaurant vs product vendor)
  VendorType? vendorType;
  
  Vendor({
    required this.id,
    required this.name,
    required this.category,
    required this.logoUrl,
    required this.rating,
    required this.totalRatings,
    required this.latitude,
    required this.longitude,
    required this.prepTimeMinutes,
    this.deliveryRadiusKm = 10.0,
    this.distanceKm,
    this.distanceDisplay,
    this.estimatedDeliveryTimeMinutes,
    this.estimatedDeliveryDisplay,
    this.deliveryFee = 0.0,
    this.distanceIsEstimate = false,
    this.isNew = false,
    this.bannerUrl,
    this.isDeliverable = true,
    this.isOpen = true,
    this.description,
    this.categories = const [],
    this.phone,
    this.workingHours,
    this.vendorType,
  });

  static String? _buildVendorMediaUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    final lowered = trimmed.toLowerCase();
    if (lowered == 'none' || lowered == 'null') return null;

    final normalized = trimmed.replaceAll('\\', '/');

    String finalUrl;
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      finalUrl = normalized;
    } else if (normalized.startsWith('/')) {
      finalUrl = '${ApiService.baseUrl}$normalized';
    } else if (normalized.startsWith('static/')) {
      finalUrl = '${ApiService.baseUrl}/$normalized';
    } else if (normalized.startsWith('uploads/')) {
      finalUrl = '${ApiService.baseUrl}/static/$normalized';
    } else if (normalized.contains('static/uploads/vendors/')) {
      finalUrl = '${ApiService.baseUrl}/${normalized.startsWith('/') ? normalized.substring(1) : normalized}';
    } else {
      finalUrl = '${ApiService.baseUrl}/static/uploads/vendors/$normalized';
    }
    
    print('🖼️ Built media URL: "$value" → "$finalUrl"');
    return finalUrl;
  }
  
  // Getters
  bool get hasValidLocation => latitude != null && longitude != null;
  bool get hasAccurateDistance => distanceKm != null && !distanceIsEstimate;
  int? get travelTimeMinutes => null;
  
  // Check if vendor is a restaurant
  bool get isRestaurant => vendorType == VendorType.restaurant;
  
  // Check if vendor is a product vendor
  bool get isProductVendor => vendorType == VendorType.product;
  
  /// Get formatted distance
  String get formattedDistance {
    if (distanceDisplay != null && distanceDisplay!.isNotEmpty) {
      return distanceDisplay!;
    }
    
    if (distanceKm == null) return 'D/U';
    
    final distanceText = distanceKm! < 1
        ? '${(distanceKm! * 1000).round()}m'
        : '${distanceKm!.toStringAsFixed(1)}km';
    
    return distanceIsEstimate ? '~$distanceText' : distanceText;
  }
  
  /// Get delivery time
  String get formattedDeliveryTime {
    if (estimatedDeliveryDisplay != null && estimatedDeliveryDisplay!.isNotEmpty) {
      return estimatedDeliveryDisplay!;
    }
    
    final minutes = estimatedDeliveryTimeMinutes ?? prepTimeMinutes;
    
    if (minutes < 60) {
      return '$minutes mins';
    } else {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      return remainingMins > 0 ? '$hours h $remainingMins m' : '$hours h';
    }
  }
  
  /// Get formatted rating
  String get formattedRating {
    return rating.toStringAsFixed(1);
  }
  
  /// Get delivery fee display
  String get deliveryFeeDisplay {
    if (deliveryFee == 0) return 'FREE';
    return 'RWF ${deliveryFee.toStringAsFixed(0)}';
  }
  
  /// Get formatted delivery fee
  String get formattedDeliveryFee {
    return deliveryFeeDisplay;
  }
  
  /// Get delivery time (for vendor_card)
  int get deliveryTime {
    return estimatedDeliveryTimeMinutes ?? prepTimeMinutes;
  }
  
  /// Get distance value for sorting/filtering
  double get distance => distanceKm ?? 0.0;
  
  /// Factory method from JSON
  factory Vendor.fromJson(Map<String, dynamic> json) {
    // Parse vendor type - FIXED: Check is_restaurant flag first!
    VendorType? type;
    
    // ✅ CRITICAL FIX: Check backend's explicit is_restaurant flag FIRST
    final backendIsRestaurant = json['is_restaurant'];
    final isRestaurantFlag = backendIsRestaurant is bool
        ? backendIsRestaurant
        : backendIsRestaurant is String
            ? backendIsRestaurant.toLowerCase() == 'true'
            : backendIsRestaurant is num
                ? backendIsRestaurant != 0
                : false;

    if (isRestaurantFlag) {
      type = VendorType.restaurant;
      print('✅ Detected as RESTAURANT (from API is_restaurant flag)');
    } else {
      // Fall back to business_type detection
      final typeStr = (json['business_type'] ?? json['vendor_type'])?.toString().toLowerCase();
      
      print('🔍 Parsing vendor type from: business_type="${json['business_type']}", vendor_type="${json['vendor_type']}"');
      print('🔍 Extracted typeStr: "$typeStr"');
      
      if (typeStr == 'restaurant') {
        type = VendorType.restaurant;
        print('✅ Detected as RESTAURANT');
      } else if (typeStr == 'product' || 
                 typeStr == 'shop' || 
                 typeStr == 'supermarket' || 
                 typeStr == 'grocery' ||  // ✅ ADDED grocery support
                 typeStr == 'groceries' ||
                 typeStr == 'market') {
        type = VendorType.product;
        print('✅ Detected as PRODUCT/SHOP/GROCERY');
      } else {
        // ✅ Default to product for unknown types
        type = VendorType.product;
        print('⚠️ Unknown vendor type: "$typeStr" - defaulting to PRODUCT');
      }
    }
    
    // Parse categories (handle both single category and array)
    List<String> categoryList = [];
    if (json['categories'] is List) {
      categoryList = (json['categories'] as List).map((c) => c.toString()).toList();
    } else if (json['category'] != null) {
      categoryList = [json['category'].toString()];
    }
    
    print('🔍 VENDOR DATA from API:');
    print('   ID: ${json['id']}');
    print('   Name: ${json['business_name'] ?? json['name']}');
    print('   Raw logo: "${json['logo']}" or "${json['logo_url']}"');
    print('   Raw banner: "${json['banner']}" or "${json['banner_url']}"');
    
    final logoUrl = _buildVendorMediaUrl(json['logo'] ?? json['logo_url']) ?? '';
    final bannerUrl = _buildVendorMediaUrl(json['banner'] ?? json['banner_url']);
    
    print('   Processed logoUrl: "$logoUrl"');
    print('   Processed bannerUrl: "$bannerUrl"');
    
    return Vendor(
      id: json['id']?.toString() ?? '0',
      name: json['business_name'] ?? json['name'] ?? 'Unknown',
      category: json['category'] ?? json['business_type'] ?? 'Others',
      logoUrl: logoUrl,
      rating: (json['rating'] ?? json['avg_rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['total_reviews'] ?? json['total_ratings'] ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      prepTimeMinutes: json['prep_time_minutes'] ?? json['estimated_prep_time'] ?? 30,
      deliveryRadiusKm: (json['delivery_radius_km'] as num?)?.toDouble() ?? 
                        (json['delivery_radius'] as num?)?.toDouble() ?? 10.0,
      
      // Distance data from backend
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      distanceDisplay: json['distance_display'],
      estimatedDeliveryTimeMinutes: json['delivery_time'] ?? json['estimated_delivery_time'],
      estimatedDeliveryDisplay: json['estimated_arrival'],
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      distanceIsEstimate: json['distance_is_estimate'] ?? false,
      
      isNew: json['is_new'] ?? false,
      bannerUrl: bannerUrl,
      isDeliverable: json['is_deliverable'] ?? true,
      isOpen: json['is_open'] ?? true,
      
      // Additional fields
      description: json['description'] ?? json['bio'],
      categories: categoryList,
      phone: json['phone'] ?? json['phone_number'],
      workingHours: json['working_hours'] is String 
          ? (json['working_hours'] as String).isNotEmpty 
              ? Map<String, dynamic>.from(jsonDecode(json['working_hours']))
              : null
          : json['working_hours'] as Map<String, dynamic>?,
      vendorType: type,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_name': name,
      'category': category,
      'logo_url': logoUrl,
      'rating': rating,
      'total_ratings': totalRatings,
      'latitude': latitude,
      'longitude': longitude,
      'prep_time_minutes': prepTimeMinutes,
      'delivery_radius_km': deliveryRadiusKm,
      'distance_km': distanceKm,
      'distance_display': distanceDisplay,
      'estimated_delivery_time': estimatedDeliveryTimeMinutes,
      'estimated_arrival': estimatedDeliveryDisplay,
      'delivery_fee': deliveryFee,
      'distance_is_estimate': distanceIsEstimate,
      'is_new': isNew,
      'banner_url': bannerUrl,
      'is_deliverable': isDeliverable,
      'is_open': isOpen,
      'description': description,
      'categories': categories,
      'phone': phone,
      'working_hours': workingHours,
      'business_type': vendorType?.toString().split('.').last,
      'vendor_type': vendorType?.toString().split('.').last,
    };
  }
}