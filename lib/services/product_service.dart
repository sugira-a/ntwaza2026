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
        ? '/api/vendors/$vendorId/menus'
        : '/api/vendors/$vendorId/categories';
    
    print('🔍 ProductService: Fetching ${isRestaurant ? "menus" : "categories"} for vendor: $vendorId');
    print('🌐 Using endpoint: $endpoint');

    final response = await _apiService.get(endpoint);

    print('📦 ProductService: Raw response: $response');

    final dataKey = response.containsKey('menus') ? 'menus' : 'categories';
    
    if (!response.containsKey(dataKey)) {
      print('⚠️ Response does not contain "$dataKey" key');
      print('📋 Available keys: ${response.keys.toList()}');
      return [];
    }

    final categoriesData = response[dataKey];

    if (categoriesData is! List) {
      print('❌ $dataKey is not a list: ${categoriesData.runtimeType}');
      return [];
    }

    print('📦 Parsing ${categoriesData.length} $dataKey...');

    final List<ProductCategory> categories = [];

    for (int i = 0; i < categoriesData.length; i++) {
      try {
        print('🔄 Parsing category $i: ${categoriesData[i]['name']}');
        
        // ✅ CRITICAL FIX: Inject vendor_id into each product before parsing
        final categoryJson = Map<String, dynamic>.from(categoriesData[i]);
        if (categoryJson['products'] is List) {
          categoryJson['products'] = (categoryJson['products'] as List).map((productJson) {
            // Create a mutable copy of the product JSON
            final mutableProduct = Map<String, dynamic>.from(productJson);
            
            // ✅ Ensure vendor_id is set
            if (mutableProduct['vendor_id'] == null || 
                mutableProduct['vendor_id'].toString().isEmpty ||
                mutableProduct['vendor_id'] == '0') {
              print('⚠️ Product "${mutableProduct['name']}" missing vendor_id, injecting: $vendorId');
              mutableProduct['vendor_id'] = vendorId;
            }
            
            // Also inject vendor name if available
            if (vendor != null && 
                (mutableProduct['vendor_name'] == null || 
                 mutableProduct['vendor_name'].toString().isEmpty)) {
              mutableProduct['vendor_name'] = vendor.name;
            }
            
            return mutableProduct;
          }).toList();
        }
        
        final category = ProductCategory.fromJson(categoryJson);
        categories.add(category);
        print('✅ ${isRestaurant ? "Menu" : "Category"}: ${category.name} with ${category.products.length} products');
        
        // Verify vendor_id was injected
        for (var product in category.products) {
          if (product.vendorId == '0' || product.vendorId.isEmpty) {
            print('❌ WARNING: Product ${product.name} still has invalid vendor_id: ${product.vendorId}');
          }
        }
        
      } catch (e, stackTrace) {
        print('❌ Error parsing ${isRestaurant ? "menu" : "category"} $i: $e');
        print('📋 Raw JSON: ${categoriesData[i]}');
        print('Stack trace: $stackTrace');
      }
    }

    print('✅ Successfully parsed ${categories.length} ${isRestaurant ? "menus" : "categories"}');
    return categories;

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
        ? '/api/vendors/$vendorId/menus'
        : '/api/vendors/$vendorId/products';
    
    print('🔍 ProductService: Fetching products for vendor: $vendorId (${isRestaurant ? "restaurant" : "shop"})');
    print('🌐 Using endpoint: $endpoint');

    final response = await _apiService.get(endpoint);

    // For restaurants, flatten menus/categories into products
    if (isRestaurant) {
      final dataKey = response.containsKey('menus') ? 'menus' : 'categories';
      final menusData = response[dataKey];
      if (menusData is! List) return [];
      
      final List<Product> allProducts = [];
      for (var menu in menusData) {
        if (menu['products'] is List) {
          for (var productJson in menu['products']) {
            try {
              // ✅ Inject vendor_id
              final mutableProduct = Map<String, dynamic>.from(productJson);
              if (mutableProduct['vendor_id'] == null || 
                  mutableProduct['vendor_id'].toString().isEmpty) {
                mutableProduct['vendor_id'] = vendorId;
              }
              if (vendor != null && mutableProduct['vendor_name'] == null) {
                mutableProduct['vendor_name'] = vendor.name;
              }
              allProducts.add(Product.fromJson(mutableProduct));
            } catch (e) {
              print('❌ Error parsing product: $e');
            }
          }
        }
      }
      print('✅ Successfully parsed ${allProducts.length} products from menus');
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