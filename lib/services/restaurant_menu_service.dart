// lib/services/restaurant_menu_service.dart
/// Enhanced restaurant menu service with better error handling and debugging
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/vendor.dart';
import 'api/api_service.dart';

class RestaurantMenuService {
  final ApiService _apiService = ApiService();

  /// Get restaurant menus with detailed error logging
  Future<List<ProductCategory>> getRestaurantMenus(String vendorId, {Vendor? vendor}) async {
    try {
      print('\n' + '='*60);
      print('🍽️  RESTAURANT MENU SERVICE: Fetching menus for vendor $vendorId');
      print('='*60);

      final endpoint = '/api/vendors/$vendorId/menus';
      print('📡 Endpoint: $endpoint');

      final response = await _apiService.get(endpoint);
      print('✅ Response received. Status check passed.');
      print('📋 Response keys: ${response.keys.toList()}');

      // Check for menus key
      if (!response.containsKey('menus')) {
        print('⚠️  CRITICAL: No "menus" key in response!');
        print('🔍 Debugging info:');
        print('   - Response type: ${response.runtimeType}');
        print('   - Response keys: ${response.keys.toList()}');
        print('   - Full response: $response');
        return [];
      }

      final menusData = response['menus'];

      if (menusData is! List) {
        print('❌ ERROR: menus is not a list, it\'s ${menusData.runtimeType}');
        print('   Content: $menusData');
        return [];
      }

      print('📊 Received ${menusData.length} menus');

      if (menusData.isEmpty) {
        print('⚠️  WARNING: Menu list is empty!');
        print('   Vendor ID: $vendorId');
        print('   Vendor name: ${vendor?.name ?? "unknown"}');
        return [];
      }

      final List<ProductCategory> categories = [];

      for (int i = 0; i < menusData.length; i++) {
        try {
          final menuData = menusData[i];
          print('\n  Menu $i:');
          print('    - Type: ${menuData.runtimeType}');
          print('    - Keys: ${(menuData is Map) ? menuData.keys.toList() : 'not a map'}');

          if (menuData is! Map) {
            print('    ❌ Menu is not a Map, skipping');
            continue;
          }

          final categoryJson = Map<String, dynamic>.from(menuData);
          final menuName = categoryJson['name'] ?? 'Unknown Menu';
          print('    - Name: $menuName');

          // Handle products within the menu
          if (categoryJson['products'] is List) {
            final productCount = (categoryJson['products'] as List).length;
            print('    - Products: $productCount');

            categoryJson['products'] = (categoryJson['products'] as List).map((productJson) {
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
              return mutableProduct;
            }).toList();
          } else {
            print('    ⚠️  No products list found, setting empty');
            categoryJson['products'] = [];
          }

          final category = ProductCategory.fromJson(categoryJson);
          categories.add(category);
          print('    ✅ Added menu: ${category.name} (${category.products.length} products)');
        } catch (e, st) {
          print('    ❌ Error parsing menu $i: $e');
          print('       Stack: $st');
        }
      }

      print('\n✅ SUCCESS: Loaded ${categories.length} menus');
      print('='*60 + '\n');
      return categories;
    } catch (e, stackTrace) {
      print('\n❌ FATAL ERROR in getRestaurantMenus:');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      print('='*60 + '\n');
      rethrow;
    }
  }

  /// Verify if vendor supports menu system
  Future<bool> supportsMenuSystem(String vendorId) async {
    try {
      final response = await _apiService.get('/api/vendors/$vendorId');
      return response['uses_menu_system'] ?? false;
    } catch (e) {
      print('❌ Error checking menu system support: $e');
      return false;
    }
  }
}
