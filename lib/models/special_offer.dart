import '../utils/helpers.dart';

class SpecialOffer {
  final int id;
  final String name;
  final String? description;
  final String discountText;
  final String? category;
  final double? discountPercentage;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final String? imageUrl;
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
    this.discountPercentage,
    required this.minOrderAmount,
    this.maxDiscountAmount,
    this.imageUrl,
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
    return SpecialOffer(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      discountText: json['discount_text'] as String,
      category: json['category'] as String?,
      discountPercentage: json['discount_percentage'] != null
          ? (json['discount_percentage'] as num).toDouble()
          : null,
      minOrderAmount: (json['min_order_amount'] as num).toDouble(),
      maxDiscountAmount: json['max_discount_amount'] != null
          ? (json['max_discount_amount'] as num).toDouble()
          : null,
      imageUrl: json['image_url'] as String?,
      validFrom: parseServerTime(json['valid_from'] as String),
      validUntil: parseServerTime(json['valid_until'] as String),
      vendorId: json['vendor_id'] as int?,
      sortOrder: json['sort_order'] as int,
      isActive: json['is_active'] as bool,
      showOnHomepage: json['show_on_homepage'] as bool,
      usageLimit: json['usage_limit'] as int?,
      usageLimitPerUser: json['usage_limit_per_user'] as int,
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
      'discount_percentage': discountPercentage,
      'min_order_amount': minOrderAmount,
      'max_discount_amount': maxDiscountAmount,
      'image_url': imageUrl,
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
}