// lib/services/product_stock_service.dart
/// Service to handle product stock status
import 'api/api_service.dart';

class StockStatus {
  final String productId;
  final int quantity;
  final bool isAvailable;
  final bool isLowStock;
  final DateTime lastUpdated;

  StockStatus({
    required this.productId,
    required this.quantity,
    required this.isAvailable,
    required this.isLowStock,
    required this.lastUpdated,
  });

  String get displayText {
    if (!isAvailable) return '❌ Out of Stock';
    if (isLowStock) return '⚠️  Only $quantity left!';
    return '✅ ${quantity > 50 ? quantity : quantity} in stock';
  }

  String get displayColor {
    if (!isAvailable) return '#FF5252';  // Red
    if (isLowStock) return '#FFC107';    // Orange  
    return '#4CAF50';                  // Green
  }
}

class ProductStockService {
  final ApiService _apiService = ApiService();

  /// Get stock status for a product
  Future<StockStatus?> getStockStatus(String productId) async {
    try {
      final response = await _apiService.get(
        '/api/products/$productId/stock',
      );

      if (response['success'] != true) {
        return null;
      }

      return StockStatus(
        productId: productId,
        quantity: response['quantity'] ?? 0,
        isAvailable: response['is_available'] ?? false,
        isLowStock: response['is_low_stock'] ?? false,
        lastUpdated: DateTime.parse(
          response['last_updated'] ?? DateTime.now().toIso8601String()
        ),
      );
    } catch (e) {
      print('❌ Stock check error: $e');
      return null;
    }
  }

  /// Get stock for multiple products
  Future<Map<String, StockStatus>> getStockForProducts(
    List<String> productIds,
  ) async {
    try {
      final results = <String, StockStatus>{};

      for (var productId in productIds) {
        final status = await getStockStatus(productId);
        if (status != null) {
          results[productId] = status;
        }
      }

      return results;
    } catch (e) {
      print('❌ Bulk stock check error: $e');
      return {};
    }
  }

  /// Subscribe to stock notifications
  Future<bool> notifyWhenAvailable(String productId) async {
    try {
      final response = await _apiService.post(
        '/api/products/$productId/notify-stock',
        body: {},
      );

      return response['success'] ?? false;
    } catch (e) {
      print('❌ Notification signup error: $e');
      return false;
    }
  }
}
