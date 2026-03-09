import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api/api_service.dart';
import '../services/notification_service.dart';
import '../services/realtime/realtime_service.dart';
import '../models/order.dart';

class RiderOrderProvider with ChangeNotifier {
  final ApiService _apiService;
  Timer? _refreshTimer;
  static const int _defaultAutoRefreshSeconds = 30;  // Increased from 15 to 30 seconds
  StreamSubscription? _orderUpdatesSub;
  bool _isDisposed = false;

  // Available orders (to accept)
  List<Order> _availableOrders = [];
  // Keep declined orders hidden locally until app restart
  final Set<String> _declinedOrderIds = {};
  // Assigned/active orders
  List<Order> _orders = [];
  // Completed deliveries
  List<Order> _deliveryHistory = [];
  
  // Earnings data
  Map<String, dynamic> _earnings = {};

  bool _isLoading = false;
  bool _isLoadingHistory = false;
  bool _isLoadingEarnings = false;
  String? _error;

  RiderOrderProvider({required ApiService apiService}) : _apiService = apiService;

  // Getters
  List<Order> get availableOrders => _availableOrders;
  List<Order> get orders => _orders;
  List<Order> get deliveryHistory => _deliveryHistory;
  Map<String, dynamic> get earnings => _earnings;
  bool get isLoading => _isLoading;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingEarnings => _isLoadingEarnings;
  String? get error => _error;

  void _notifySafely() {
    if (_isDisposed) return;
    notifyListeners();
  }

  /// Fetch available orders that rider can accept
  Future<void> fetchAvailableOrders({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final response = await _apiService.get('/api/rider/available-orders');
      if (_isDisposed) return;
      if (response['success'] == true && response['orders'] is List) {
        final incoming = (response['orders'] as List)
            .map((j) => Order.fromJson(j))
            .toList();
        _availableOrders = incoming
            .where((o) => o.id == null || !_declinedOrderIds.contains(o.id))
            .toList();
      } else {
        _error = response['error']?.toString() ?? 'Failed to load available orders';
      }
    } catch (e) {
      if (_isDisposed) return;
      _error = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      print('❌ Error fetching available orders: $e');
    } finally {
      if (!_isDisposed) {
        if (!silent) {
          _isLoading = false;
        }
        notifyListeners();
      }
    }
  }

  /// Accept an available order
  Future<bool> acceptOrder(String orderId) async {
    try {
      final resp = await _apiService.post(
        '/api/rider/orders/$orderId/accept',
        {},
      );
      if (_isDisposed) return false;
      if (resp['success'] == true) {
        _declinedOrderIds.remove(orderId);
        _availableOrders.removeWhere((o) => o.id == orderId);
        await fetchAssignedOrders();
        if (_isDisposed) return false;
        
        // Send notification
        await NotificationService().showLocalNotification(
          title: '🎉 Order Accepted',
          body: 'You have accepted order #$orderId',
        );
        if (_isDisposed) return false;
        
        notifyListeners();
        return true;
      }
      _error = resp['error']?.toString() ?? 'Failed to accept order';
      notifyListeners();
      return false;
    } catch (e) {
      if (_isDisposed) return false;
      _error = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      notifyListeners();
      print('❌ Error accepting order: $e');
      return false;
    }
  }

  /// Reject an available order
  Future<bool> rejectOrder(String orderId) async {
    try {
      final resp = await _apiService.post(
        '/api/rider/orders/$orderId/reject',
        {},
      );
      if (_isDisposed) return false;
      if (resp['success'] == true) {
        _declinedOrderIds.add(orderId);
        _availableOrders.removeWhere((o) => o.id == orderId);
        _orders.removeWhere((o) => o.id == orderId);
        
        // Send notification
        await NotificationService().showLocalNotification(
          title: '❌ Order Declined',
          body: 'You have declined order #$orderId',
        );
        if (_isDisposed) return false;
        
        notifyListeners();
        return true;
      }
      _error = resp['error']?.toString() ?? 'Failed to decline order';
      notifyListeners();
      return false;
    } catch (e) {
      if (_isDisposed) return false;
      _error = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      notifyListeners();
      print('❌ Error declining order: $e');
      return false;
    }
  }

  /// Fetch assigned/active orders (with retry for transient failures)
  Future<void> fetchAssignedOrders({bool silent = false, int retries = 2}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final response = await _apiService.get('/api/rider/orders');
      if (_isDisposed) return;
      if (response['success'] == true && response['orders'] is List) {
        _orders = (response['orders'] as List)
            .map((j) => Order.fromJson(j))
            .toList();
      } else {
        _error = response['error']?.toString() ?? 'Failed to load orders';
      }
    } catch (e) {
      if (_isDisposed) return;
      // Retry on transient network failures (e.g. browser fetch limit)
      if (retries > 0 && e.toString().contains('Failed to fetch')) {
        print('🔄 Retrying fetchAssignedOrders ($retries retries left)...');
        await Future.delayed(const Duration(seconds: 2));
        if (_isDisposed) return;
        return fetchAssignedOrders(silent: silent, retries: retries - 1);
      }
      _error = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      print('❌ Error fetching assigned orders: $e');
    } finally {
      if (!_isDisposed) {
        if (!silent) {
          _isLoading = false;
        }
        notifyListeners();
      }
    }
  }

  /// Fetch delivery history (completed orders)
  Future<void> fetchDeliveryHistory() async {
    _isLoadingHistory = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _apiService.get('/api/rider/orders/history');
      if (_isDisposed) return;
      if (response['success'] == true && response['orders'] is List) {
        _deliveryHistory = (response['orders'] as List)
            .map((j) => Order.fromJson(j))
            .toList();
      } else {
        _error = response['error']?.toString() ?? 'Failed to load history';
      }
    } catch (e) {
      if (_isDisposed) return;
      _error = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      print('❌ Error fetching delivery history: $e');
    } finally {
      if (!_isDisposed) {
        _isLoadingHistory = false;
        notifyListeners();
      }
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final resp = await _apiService.put(
        '/api/rider/orders/$orderId/status',
        {'status': status},
      );
      if (_isDisposed) return false;
      if (resp['success'] == true) {
        await fetchAssignedOrders();
        if (_isDisposed) return false;
        
        // Send notification
        String statusDisplay = status;
        switch (status) {
          case 'picked_up':
            statusDisplay = 'Picked Up';
            break;
          case 'in_transit':
            statusDisplay = 'In Transit';
            break;
          case 'delivered':
            statusDisplay = 'Delivered';
            break;
        }
        
        await NotificationService().showLocalNotification(
          title: '✅ Order Status Updated',
          body: 'Order #$orderId is now $statusDisplay',
        );
        if (_isDisposed) return false;
        
        return true;
      }
      
      // Enhanced error handling for authorization issues
      final errorMsg = resp['error']?.toString() ?? 'Failed to update order';
      if (errorMsg.toLowerCase().contains('not authorized') || 
          errorMsg.toLowerCase().contains('authorization')) {
        _error = 'You are not assigned to this order. Please ensure you have accepted the order before updating its status.';
      } else {
        _error = errorMsg;
      }
      notifyListeners();
      return false;
    } catch (e) {
      if (_isDisposed) return false;
      final errorStr = e.toString();
      if (errorStr.toLowerCase().contains('not authorized') || 
          errorStr.toLowerCase().contains('403')) {
        _error = 'Authorization Error: This order may not be assigned to you. Please check with support if this persists.';
      } else {
        _error = errorStr;
      }
      notifyListeners();
      print('❌ Error updating order status: $e');
      return false;
    }
  }

  /// Fetch rider earnings
  Future<void> fetchEarnings() async {
    _isLoadingEarnings = true;
    _error = null;
    _notifySafely();
    try {
      final response = await _apiService.get('/api/rider/earnings');
      if (_isDisposed) return;
      if (response['success'] == true && response['earnings'] is Map) {
        _earnings = Map<String, dynamic>.from(response['earnings']);
      } else {
        _error = response['error']?.toString() ?? 'Failed to load earnings';
      }
    } catch (e) {
      if (_isDisposed) return;
      _error = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      print('❌ Error fetching earnings: $e');
    } finally {
      if (!_isDisposed) {
        _isLoadingEarnings = false;
        _notifySafely();
      }
    }
  }

  /// Verify vendor pickup code (rider picks up from vendor)
  Future<Map<String, dynamic>?> verifyVendorPickupCode(String orderId, String code) async {
    try {
      final resp = await _apiService.post(
        '/api/rider/orders/$orderId/verify-vendor-pickup',
        {'code': code},
      );
      if (_isDisposed) return null;
      if (resp['success'] == true) {
        await fetchAssignedOrders();
        if (_isDisposed) return null;
        return resp;
      }
      _error = resp['error']?.toString() ?? 'Invalid vendor pickup code';
      notifyListeners();
      return resp;
    } catch (e) {
      if (_isDisposed) return null;
      final raw = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      _error = _friendlyVerificationError(raw, isVendor: true);
      notifyListeners();
      return {'success': false, 'error': _error};
    }
  }

  /// Verify customer delivery code (rider delivers to customer)
  Future<Map<String, dynamic>?> verifyCustomerDeliveryCode(String orderId, String code) async {
    try {
      final resp = await _apiService.post(
        '/api/rider/orders/$orderId/verify-customer-delivery',
        {'code': code},
      );
      if (_isDisposed) return null;
      if (resp['success'] == true) {
        await fetchAssignedOrders();
        if (_isDisposed) return null;
        await fetchDeliveryHistory();
        if (_isDisposed) return null;
        return resp;
      }
      _error = resp['error']?.toString() ?? 'Invalid customer delivery code';
      notifyListeners();
      return resp;
    } catch (e) {
      if (_isDisposed) return null;
      final raw = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      _error = _friendlyVerificationError(raw, isVendor: false);
      notifyListeners();
      return {'success': false, 'error': _error};
    }
  }

  /// Convert raw verification errors into friendly messages
  String _friendlyVerificationError(String raw, {required bool isVendor}) {
    final lower = raw.toLowerCase();
    final attemptsMatch = RegExp(r'(\d+)\s*attempts?\s*remaining').firstMatch(lower);
    final who = isVendor ? 'vendor' : 'customer';

    if (lower.contains('invalid') && attemptsMatch != null) {
      final remaining = attemptsMatch.group(1);
      return 'Wrong code. Please ask the $who for the correct code. You have $remaining attempt${remaining == '1' ? '' : 's'} left.';
    }
    if (lower.contains('invalid')) {
      return 'The code you entered is incorrect. Please double-check with the $who and try again.';
    }
    if (lower.contains('locked') || lower.contains('blocked') || lower.contains('0 attempt')) {
      return 'Too many failed attempts. Please contact support for help.';
    }
    return raw;
  }

  /// Release stale orders that are blocking new acceptances
  Future<bool> releaseStaleOrders() async {
    try {
      final resp = await _apiService.post('/api/rider/release-stale-orders', {});
      if (_isDisposed) return false;
      if (resp['success'] == true) {
        await fetchAssignedOrders();
        if (_isDisposed) return false;
        await fetchAvailableOrders();
        if (_isDisposed) return false;
        notifyListeners();
        return true;
      }
      _error = resp['error']?.toString() ?? 'Failed to release stale orders';
      notifyListeners();
      return false;
    } catch (e) {
      if (_isDisposed) return false;
      _error = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
      notifyListeners();
      return false;
    }
  }

  /// Auto-refresh available orders periodically
  void startAutoRefresh([int seconds = _defaultAutoRefreshSeconds]) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: seconds), (_) async {
      await fetchAvailableOrders(silent: true);
      if (!_isDisposed) await fetchAssignedOrders(silent: true);
    });

    _orderUpdatesSub?.cancel();
    _orderUpdatesSub = RealtimeService().orderUpdates.listen((_) {
      fetchAvailableOrders(silent: true);
      fetchAssignedOrders(silent: true);
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _orderUpdatesSub?.cancel();
    _orderUpdatesSub = null;
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    stopAutoRefresh();
    _isDisposed = true;
    _orderUpdatesSub?.cancel();
    super.dispose();
  }
}
