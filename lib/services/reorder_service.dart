// lib/services/reorder_service.dart
/// Service to handle reordering from order history
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../providers/cart_provider.dart';

class ReorderService {
  static const String _reorderHistoryKey = 'reorder_history';

  /// Add order to reorder history for quick access
  static Future<void> saveReorderOption(Order order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_reorderHistoryKey) ?? [];
      
      final reorderData = {
        'order_id': order.id,
        'vendor_id': order.vendorId,
        'vendor_name': order.vendorName,
        'total_items': order.items.length,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      history.insert(0, jsonEncode(reorderData));
      if (history.length > 10) history.removeAt(history.length - 1);
      
      await prefs.setStringList(_reorderHistoryKey, history);
      print('✅ Reorder saved: ${order.orderNumber}');
    } catch (e) {
      print('❌ Error saving reorder: $e');
    }
  }

  /// Get reorder history (last 10 orders)
  static Future<List<Map<String, dynamic>>> getReorderHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_reorderHistoryKey) ?? [];
      
      return history
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('❌ Error getting reorder history: $e');
      return [];
    }
  }

  /// Reorder items from a previous order
  /// Adds all items from order to cart
  static Future<void> reorderFromOrder(
    Order order,
    CartProvider cartProvider,
  ) async {
    try {
      print('\n🔄 REORDERING: ${order.orderNumber}');
      print('   Items: ${order.items.length}');
      print('   Vendor: ${order.vendorName}');

      for (var item in order.items) {
        // Add each item with same quantity
        await cartProvider.addToCart(
          productId: item.productId,
          productName: item.productName,
          price: item.price,
          quantity: item.quantity,
          vendorId: order.vendorId,
          vendorName: order.vendorName,
        );
      }

      print('✅ Reorder complete! ${order.items.length} items added to cart');
      await saveReorderOption(order);
    } catch (e) {
      print('❌ Reorder error: $e');
      rethrow;
    }
  }

  /// Clear reorder history
  static Future<void> clearReorderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reorderHistoryKey);
  }
}
