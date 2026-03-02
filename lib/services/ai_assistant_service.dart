import 'api/api_service.dart';
import '../providers/cart_provider.dart';
import '../providers/vendor_provider.dart';

class AiAssistantService {
  final ApiService _apiService = ApiService();

  /// Build context from current app state (cart, vendors, etc.)
  Map<String, dynamic> buildContext({
    CartProvider? cartProvider,
    VendorProvider? vendorProvider,
  }) {
    final ctx = <String, dynamic>{};

    // Send current cart items so AI knows what user has
    if (cartProvider != null && cartProvider.items.isNotEmpty) {
      ctx['cart_items'] = cartProvider.items.map((item) => {
        'name': item.product.name,
        'price': item.product.price,
        'quantity': item.quantity,
        'total': item.totalPrice,
      }).toList();
      ctx['cart_total'] = cartProvider.totalPrice;
      ctx['cart_item_count'] = cartProvider.itemCount;
    }

    // Send available vendors
    if (vendorProvider != null && vendorProvider.vendors.isNotEmpty) {
      ctx['vendors_summary'] = vendorProvider.vendors.take(10).map((v) => {
        'name': v.name,
        'category': v.category,
        'is_open': v.isOpen,
        'rating': v.rating,
        'delivery_fee': v.deliveryFee,
      }).toList();
    }

    return ctx;
  }

  Future<String> sendMessage({
    required String message,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? history,
  }) async {
    final response = await _apiService.post('/api/ai/assistant', {
      'message': message,
      'context': context ?? {},
      'history': history ?? [],
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      return (response['reply'] ?? '').toString();
    }

    final error = response is Map<String, dynamic>
        ? (response['error'] ?? 'AI assistant unavailable')
        : 'AI assistant unavailable';
    throw Exception(error);
  }
}
