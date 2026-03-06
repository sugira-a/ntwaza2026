// lib/services/payment_service.dart
import 'dart:async';
import 'api/api_service.dart';

/// Service for handling IntouchPay mobile money payments.
class PaymentService {
  final ApiService _api = ApiService();

  /// Initiate a mobile money payment for an order.
  /// Returns { success, message, payment_id, payment_code, requesttransactionid }.
  Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    required String paymentMethod, // 'momo'
    required String phoneNumber,
  }) async {
    try {
      final result = await _api.post('/api/payments/initiate', {
        'order_id': orderId,
        'phone_number': phoneNumber,
      });
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  /// Poll payment status until completed/failed or timeout.
  /// Returns the latest payment status map.
  Future<Map<String, dynamic>> pollPaymentStatus(
    String paymentId, {
    Duration timeout = const Duration(minutes: 3),
    Duration interval = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final result = await checkPaymentStatus(paymentId);
      final status = result['payment']?['status'] ?? 'pending';
      if (status == 'completed' || status == 'failed') {
        return result;
      }
      await Future.delayed(interval);
    }
    return {'success': false, 'error': 'Payment status check timed out'};
  }

  /// Check payment status once.
  Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    try {
      final result = await _api.get('/api/payments/status/$paymentId');
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
