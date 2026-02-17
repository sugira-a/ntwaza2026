// lib/models/product_category.dart
import 'product.dart';

class ProductCategory {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final List<Product> products;

  ProductCategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.imageUrl,
    required this.sortOrder,
    required this.isActive,
    required this.products,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'],
      imageUrl: json['image_url'],
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      products: (json['products'] as List?)
          ?.map((p) => Product.fromJson(p))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'is_active': isActive,
      'products': products.map((p) => p.toJson()).toList(),
    };
  }

  ProductCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
    List<Product>? products,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      products: products ?? this.products,
    );
  }
}