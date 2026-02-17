// lib/models/vendor_type.dart

import 'package:flutter/material.dart';

enum VendorType {
  restaurant,  // Uses menu system (menus -> categories -> dishes)
  product,     // Uses product listings (categories -> products)
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
  
  String get description {
    switch (this) {
      case VendorType.restaurant:
        return 'Serve food with organized menus';
      case VendorType.product:
        return 'Sell products and goods';
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