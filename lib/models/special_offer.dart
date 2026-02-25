import 'dart:ui' show Color;
import 'dart:convert';
import '../utils/helpers.dart';

class SpecialOffer {
  final int id;
  final String name;
  final String? description;
  final String discountText;
  final String? category;
  final String? promoCode;
  final double? discountPercentage;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final String? imageUrl;
  final List<String> imageUrls;
  final String linkType;        // 'vendor', 'category', 'product', 'external', 'none'
  final String? linkValue;      // vendor_id, category_name, product_id, or URL
  final String? bannerTitle;    // Large text on banner card
  final String? bannerSubtitle; // Smaller text below title
  final String backgroundColor; // Banner background color hex
  final DateTime validFrom;
  final DateTime validUntil;
  final int? vendorId;
  final int sortOrder;
  final bool isActive;
  final bool showOnHomepage;
  final int? usageLimit;
  final int usageLimitPerUser;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SpecialOffer({
    required this.id,
    required this.name,
    this.description,
    required this.discountText,
    this.category,
    this.promoCode,
    this.discountPercentage,
    required this.minOrderAmount,
    this.maxDiscountAmount,
    this.imageUrl,
    this.imageUrls = const [],
    this.linkType = 'none',
    this.linkValue,
    this.bannerTitle,
    this.bannerSubtitle,
    this.backgroundColor = '#1a1a2e',
    required this.validFrom,
    required this.validUntil,
    this.vendorId,
    required this.sortOrder,
    required this.isActive,
    required this.showOnHomepage,
    this.usageLimit,
    required this.usageLimitPerUser,
    required this.createdAt,
    this.updatedAt,
  });

  factory SpecialOffer.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty || trimmed.toLowerCase() == 'none' || trimmed.toLowerCase() == 'null') {
          return null;
        }
        return int.tryParse(trimmed);
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty || trimmed.toLowerCase() == 'none' || trimmed.toLowerCase() == 'null') {
          return null;
        }
        return double.tryParse(trimmed);
      }
      return null;
    }

    return SpecialOffer(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      discountText: json['discount_text'] as String? ?? '',
      category: json['category'] as String?,
      promoCode: json['promo_code'] as String?,
      discountPercentage: parseDouble(json['discount_percentage']),
      minOrderAmount: parseDouble(json['min_order_amount']) ?? 0,
      maxDiscountAmount: parseDouble(json['max_discount_amount']),
      imageUrl: json['image_url'] as String?,
      imageUrls: _parseImageUrls(json['image_urls'], json['image_url']),
      linkType: json['link_type'] as String? ?? 'none',
      linkValue: json['link_value'] as String?,
      bannerTitle: json['banner_title'] as String?,
      bannerSubtitle: json['banner_subtitle'] as String?,
      backgroundColor: json['background_color'] as String? ?? '#1a1a2e',
      validFrom: parseServerTime(json['valid_from'] as String),
      validUntil: parseServerTime(json['valid_until'] as String),
      vendorId: parseInt(json['vendor_id']),
      sortOrder: parseInt(json['sort_order']) ?? 0,
      isActive: json['is_active'] as bool,
      showOnHomepage: json['show_on_homepage'] as bool,
      usageLimit: parseInt(json['usage_limit']),
      usageLimitPerUser: parseInt(json['usage_limit_per_user']) ?? 0,
      createdAt: parseServerTime(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? parseServerTime(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'discount_text': discountText,
      'category': category,
      'promo_code': promoCode,
      'discount_percentage': discountPercentage,
      'min_order_amount': minOrderAmount,
      'max_discount_amount': maxDiscountAmount,
      'image_url': imageUrl,
      'image_urls': imageUrls,
      'link_type': linkType,
      'link_value': linkValue,
      'banner_title': bannerTitle,
      'banner_subtitle': bannerSubtitle,
      'background_color': backgroundColor,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'vendor_id': vendorId,
      'sort_order': sortOrder,
      'is_active': isActive,
      'show_on_homepage': showOnHomepage,
      'usage_limit': usageLimit,
      'usage_limit_per_user': usageLimitPerUser,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isCurrentlyValid {
    final now = nowInRwanda();
    return now.isAfter(validFrom) && now.isBefore(validUntil);
  }

  bool get canBeShownOnHomepage {
    return isActive && showOnHomepage && isCurrentlyValid;
  }

  /// Parse hex color string to Color
  Color get bgColor {
    try {
      final hex = backgroundColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF1a1a2e);
    }
  }

  static List<String> _parseImageUrls(dynamic value, dynamic fallback) {
    List<String> fromList(List<dynamic> items) {
      return items
          .where((item) => item != null)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is List) {
      final parsed = fromList(value);
      if (parsed.isNotEmpty) return parsed;
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            final parsed = fromList(decoded);
            if (parsed.isNotEmpty) return parsed;
          }
        } catch (_) {
          final parts = trimmed.replaceAll('\n', ',').split(',');
          final parsed = parts.map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
          if (parsed.isNotEmpty) return parsed;
        }
      }
    }

    if (fallback is String && fallback.trim().isNotEmpty) {
      return [fallback.trim()];
    }

    return [];
  }
}