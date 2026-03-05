// lib/services/product_service.dart
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/vendor.dart';
import 'api/api_service.dart';

class ProductService {
  final ApiService _apiService = ApiService();

  /// Get all categories/menus with products for a specific vendor
  /// Automatically uses /menus for restaurants and /categories for supermarkets
  Future<List<ProductCategory>> getVendorCategories(String vendorId, {Vendor? vendor}) async {
  try {
    final isRestaurant = vendor?.isRestaurant ?? false;
    
    final endpoint = isRestaurant 
        ? '/api/restaurant/vendors/$vendorId/menus'
        : '/api/vendors/$vendorId/products';
    
    print('🔍 ProductService: Fetching ${isRestaurant ? "menus" : "products"} for vendor: $vendorId');
    print('🌐 Using endpoint: $endpoint');

    final response = await _apiService.get(endpoint);

    print('📦 ProductService: Raw response keys: ${response.keys.toList()}');

    // For simple vendors, the /products endpoint returns {products: [...]}
    // For restaurants, we expect {menus: [...]}
    final dataKey = isRestaurant ? 'menus' : 'products';
    
    if (!response.containsKey(dataKey)) {
      print('⚠️ Response does not contain "$dataKey" key');
      print('📋 Available keys: ${response.keys.toList()}');
      return [];
    }

    final productsOrMenusData = response[dataKey];

    if (productsOrMenusData is! List) {
      print('❌ $dataKey is not a list: ${productsOrMenusData.runtimeType}');
      return [];
    }

    print('📦 Received ${productsOrMenusData.length} $dataKey...');

    // For restaurants, parse menus → categories → dishes into ProductCategory objects
    if (isRestaurant) {
      final List<ProductCategory> categories = [];
      for (int i = 0; i < productsOrMenusData.length; i++) {
        try {
          final menuData = Map<String, dynamic>.from(productsOrMenusData[i]);
          print('🔄 Parsing menu $i: ${menuData['name']}');
          
          // Backend returns: { name, categories: [{ name, dishes: [...] }] }
          // We need to flatten categories with dishes into ProductCategory with products
          final menuCategories = menuData['categories'] as List? ?? [];
          
          if (menuCategories.isEmpty) {
            // Menu has no categories — check if it has a direct 'products' key (legacy fallback)
            if (menuData['products'] is List) {
              final categoryJson = Map<String, dynamic>.from(menuData);
              categoryJson['products'] = (categoryJson['products'] as List).map((p) {
                final mp = Map<String, dynamic>.from(p);
                if (mp['vendor_id'] == null || mp['vendor_id'].toString().isEmpty || mp['vendor_id'] == '0') mp['vendor_id'] = vendorId;
                if (vendor != null && (mp['vendor_name'] == null || mp['vendor_name'].toString().isEmpty)) mp['vendor_name'] = vendor.name;
                return mp;
              }).toList();
              categories.add(ProductCategory.fromJson(categoryJson));
              print('✅ Menu (legacy): ${menuData['name']} with ${(categoryJson['products'] as List).length} products');
            }
            continue;
          }
          
          // Flatten each menu category into a ProductCategory
          for (var catData in menuCategories) {
            final catJson = Map<String, dynamic>.from(catData);
            // Rename 'dishes' to 'products' so ProductCategory.fromJson can parse it
            final dishes = catJson['dishes'] as List? ?? [];
            catJson['products'] = dishes.map((dish) {
              final d = Map<String, dynamic>.from(dish);
              // Map dish fields to product fields for Product.fromJson compatibility
              if (d['vendor_id'] == null || d['vendor_id'].toString().isEmpty || d['vendor_id'] == '0') d['vendor_id'] = vendorId;
              if (vendor != null && (d['vendor_name'] == null || d['vendor_name'].toString().isEmpty)) d['vendor_name'] = vendor.name;
              // Map 'original_price' → 'compare_at_price' if needed
              if (d['original_price'] != null && d['compare_at_price'] == null) d['compare_at_price'] = d['original_price'];
              // Ensure category field is set
              if (d['category'] == null) d['category'] = catJson['name'] ?? '';
              return d;
            }).toList();
            catJson.remove('dishes');
            
            final category = ProductCategory.fromJson(catJson);
            categories.add(category);
            print('✅ Category: ${category.name} with ${category.products.length} dishes');
          }
        } catch (e, stackTrace) {
          print('❌ Error parsing menu $i: $e');
          print('Stack trace: $stackTrace');
        }
      }
      print('✅ Successfully parsed ${categories.length} categories from menus');
      return categories;
    } 
    
    // For simple vendors, /products returns a flat list - group by category
    else {
      final Map<String, List<Product>> productsByCategory = {};
      
      for (var productJson in productsOrMenusData) {
        try {
          // Inject vendor_id
          final mutableProduct = Map<String, dynamic>.from(productJson);
          if (mutableProduct['vendor_id'] == null || 
              mutableProduct['vendor_id'].toString().isEmpty ||
              mutableProduct['vendor_id'] == '0') {
            mutableProduct['vendor_id'] = vendorId;
          }
          if (vendor != null && 
              (mutableProduct['vendor_name'] == null || 
               mutableProduct['vendor_name'].toString().isEmpty)) {
            mutableProduct['vendor_name'] = vendor.name;
          }
          
          final product = Product.fromJson(mutableProduct);
          final category = product.category.isEmpty ? 'Uncategorized' : product.category;
          
          if (!productsByCategory.containsKey(category)) {
            productsByCategory[category] = [];
          }
          productsByCategory[category]!.add(product);
        } catch (e) {
          print('❌ Error parsing product: $e');
        }
      }
      
      // Convert to ProductCategory objects
      final List<ProductCategory> categories = [];
      int sortIndex = 0;
      
      for (var entry in productsByCategory.entries) {
        print('🔄 Parsing category $sortIndex: ${entry.key}');
        final category = ProductCategory(
          id: entry.key.toLowerCase().replaceAll(' ', '_'),
          name: entry.key,
          sortOrder: sortIndex++,
          isActive: true,
          products: entry.value,
        );
        categories.add(category);
        print('✅ Category: ${category.name} with ${category.products.length} products');
      }
      
      print('✅ Successfully parsed ${categories.length} categories');
      return categories;
    }

  } catch (e, stackTrace) {
    print('❌ ProductService error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}
  /// Get products for a specific vendor (flat list)
  Future<List<Product>> getVendorProducts(
    String vendorId, {
    Vendor? vendor,
    bool? isRestaurantOverride,
  }) async {
  try {
    final isRestaurant = isRestaurantOverride ?? (vendor?.isRestaurant ?? false);
    
    final endpoint = isRestaurant
        ? '/api/restaurant/vendors/$vendorId/menus'
        : '/api/vendors/$vendorId/products';
    
    print('🔍 ProductService: Fetching products for vendor: $vendorId (${isRestaurant ? "restaurant" : "shop"})');
    print('🌐 Using endpoint: $endpoint');

    final response = await _apiService.get(endpoint);

    // For restaurants, flatten menus → categories → dishes into products
    if (isRestaurant) {
      final dataKey = response.containsKey('menus') ? 'menus' : 'categories';
      final menusData = response[dataKey];
      if (menusData is! List) return [];
      
      final List<Product> allProducts = [];
      for (var menu in menusData) {
        // Backend structure: menu → categories → dishes
        final menuCategories = menu['categories'] as List? ?? [];
        for (var cat in menuCategories) {
          final dishes = cat['dishes'] as List? ?? [];
          for (var dishJson in dishes) {
            try {
              final d = Map<String, dynamic>.from(dishJson);
              if (d['vendor_id'] == null || d['vendor_id'].toString().isEmpty) d['vendor_id'] = vendorId;
              if (vendor != null && d['vendor_name'] == null) d['vendor_name'] = vendor.name;
              if (d['original_price'] != null && d['compare_at_price'] == null) d['compare_at_price'] = d['original_price'];
              if (d['category'] == null) d['category'] = cat['name'] ?? '';
              allProducts.add(Product.fromJson(d));
            } catch (e) {
              print('❌ Error parsing dish: $e');
            }
          }
        }
        // Legacy fallback: direct products list in menu
        if (menuCategories.isEmpty && menu['products'] is List) {
          for (var productJson in menu['products']) {
            try {
              final mutableProduct = Map<String, dynamic>.from(productJson);
              if (mutableProduct['vendor_id'] == null || mutableProduct['vendor_id'].toString().isEmpty) mutableProduct['vendor_id'] = vendorId;
              if (vendor != null && mutableProduct['vendor_name'] == null) mutableProduct['vendor_name'] = vendor.name;
              allProducts.add(Product.fromJson(mutableProduct));
            } catch (e) {
              print('❌ Error parsing product: $e');
            }
          }
        }
      }
      print('✅ Successfully parsed ${allProducts.length} dishes from menus');
      return allProducts;
    }

    // For shops
    if (!response.containsKey('products')) {
      print('⚠️ Response does not contain "products" key');
      return [];
    }
    
    final productsData = response['products'];

    if (productsData is! List) {
      print('❌ Products is not a list: ${productsData.runtimeType}');
      return [];
    }

    final List<Product> products = [];

    for (int i = 0; i < productsData.length; i++) {
      try {
        // ✅ Inject vendor_id
        final mutableProduct = Map<String, dynamic>.from(productsData[i]);
        if (mutableProduct['vendor_id'] == null || 
            mutableProduct['vendor_id'].toString().isEmpty ||
            mutableProduct['vendor_id'] == '0') {
          print('⚠️ Injecting vendor_id for product: ${mutableProduct['name']}');
          mutableProduct['vendor_id'] = vendorId;
        }
        if (vendor != null && mutableProduct['vendor_name'] == null) {
          mutableProduct['vendor_name'] = vendor.name;
        }
        
        final product = Product.fromJson(mutableProduct);
        products.add(product);
      } catch (e) {
        print('❌ Error parsing product $i: $e');
      }
    }

    print('✅ Successfully parsed ${products.length} products');
    return products;

  } catch (e, stackTrace) {
    print('❌ ProductService error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}
  /// Get products by category
  Future<List<Product>> getProductsByCategory(String vendorId, String categoryId) async {
    try {
      final response = await _apiService.get(
        '/api/vendors/$vendorId/categories/$categoryId/products',
      );

      if (!response.containsKey('products')) {
        return [];
      }

      final productsData = response['products'];
      if (productsData is! List) return [];

      return productsData
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching products by category: $e');
      rethrow;
    }
  }

  /// Search products within a vendor
  Future<List<Product>> searchVendorProducts(String vendorId, String query) async {
    try {
      final response = await _apiService.get(
        '/api/vendors/$vendorId/products/search?q=$query',
      );

      if (!response.containsKey('products')) {
        return [];
      }

      final productsData = response['products'];
      if (productsData is! List) return [];

      return productsData
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error searching products: $e');
      return [];
    }
  }
}