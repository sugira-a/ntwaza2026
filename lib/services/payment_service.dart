// lib/services/payment_service.dart
import '../services/api/api_service.dart';

/// Service for handling K-Pay payments via the backend API.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final ApiService _api = ApiService();

  /// Initiate a K-Pay payment for an order.
  ///
  /// Returns a map with:
  /// - `success`: bool
  /// - `checkout_url`: String (URL to open for payment)
  /// - `ref_id`: String (payment reference)
  /// - `payment_id`: String
  /// - `error`: String (if failed)
  Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    required String paymentMethod,
    String? phoneNumber,
  }) async {
    try {
      final response = await _api.post('/api/payments/initiate', {
        'order_id': orderId,
        'payment_method': paymentMethod,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
      });
      return response;
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to initiate payment: ${e.toString()}',
      };
    }
  }

  /// Check payment status by K-Pay reference ID.
  Future<Map<String, dynamic>> checkPaymentStatus(String refId) async {
    try {
      final response = await _api.get('/api/payments/status/$refId');
      return response;
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to check payment status: ${e.toString()}',
      };
    }
  }

  /// Check payment status for a specific order.
  Future<Map<String, dynamic>> checkOrderPaymentStatus(String orderId) async {
    try {
      final response = await _api.get('/api/payments/order/$orderId/status');
      return response;
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to check order payment: ${e.toString()}',
      };
    }
  }

  /// Get available payment methods from the server.
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final response = await _api.get('/api/payments/methods');
      if (response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['methods'] ?? []);
      }
      return _defaultMethods();
    } catch (e) {
      return _defaultMethods();
    }
  }

  /// Fallback payment methods when server is unreachable.
  List<Map<String, dynamic>> _defaultMethods() {
    return [
      {
        'id': 'cash',
        'name': 'Cash on Delivery',
        'icon': 'money',
        'enabled': true,
        'requires_phone': false,
      },
      {
        'id': 'momo',
        'name': 'Mobile Money (MTN/Airtel)',
        'icon': 'phone_android',
        'enabled': true,
        'requires_phone': true,
      },
    ];
  }
}
