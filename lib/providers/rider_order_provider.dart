import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/api/api_service.dart';
import '../services/notification_service.dart';
import '../services/realtime/realtime_service.dart';
import '../models/order.dart';

class RiderOrderProvider with ChangeNotifier {
  final ApiService _apiService;
  Timer? _refreshTimer;
  static const int _defaultAutoRefreshSeconds = 15;
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
    if (_isDisposed) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          notifyListeners();
        }
      });
      return;
    }
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
      _error = e.toString();
      print('❌ Error fetching available orders: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
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
      if (resp['success'] == true) {
        _declinedOrderIds.remove(orderId);
        _availableOrders.removeWhere((o) => o.id == orderId);
        await fetchAssignedOrders();
        
        // Send notification
        await NotificationService().showLocalNotification(
          title: '🎉 Order Accepted',
          body: 'You have accepted order #$orderId',
        );
        
        notifyListeners();
        return true;
      }
      _error = resp['error']?.toString() ?? 'Failed to accept order';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
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
      if (resp['success'] == true) {
        _declinedOrderIds.add(orderId);
        _availableOrders.removeWhere((o) => o.id == orderId);
        _orders.removeWhere((o) => o.id == orderId);
        
        // Send notification
        await NotificationService().showLocalNotification(
          title: '❌ Order Declined',
          body: 'You have declined order #$orderId',
        );
        
        notifyListeners();
        return true;
      }
      _error = resp['error']?.toString() ?? 'Failed to decline order';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      print('❌ Error declining order: $e');
      return false;
    }
  }

  /// Fetch assigned/active orders
  Future<void> fetchAssignedOrders({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final response = await _apiService.get('/api/rider/orders');
      if (response['success'] == true && response['orders'] is List) {
        _orders = (response['orders'] as List)
            .map((j) => Order.fromJson(j))
            .toList();
      } else {
        _error = response['error']?.toString() ?? 'Failed to load orders';
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Error fetching assigned orders: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
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
      if (response['success'] == true && response['orders'] is List) {
        _deliveryHistory = (response['orders'] as List)
            .map((j) => Order.fromJson(j))
            .toList();
      } else {
        _error = response['error']?.toString() ?? 'Failed to load history';
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Error fetching delivery history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final resp = await _apiService.put(
        '/api/rider/orders/$orderId/status',
        {'status': status},
      );
      if (resp['success'] == true) {
        await fetchAssignedOrders();
        
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
        
        return true;
      }
      _error = resp['error']?.toString() ?? 'Failed to update order';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
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
      if (response['success'] == true && response['earnings'] is Map) {
        _earnings = Map<String, dynamic>.from(response['earnings']);
      } else {
        _error = response['error']?.toString() ?? 'Failed to load earnings';
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Error fetching earnings: $e');
    } finally {
      _isLoadingEarnings = false;
      _notifySafely();
    }
  }

  /// Auto-refresh available orders periodically
  void startAutoRefresh([int seconds = _defaultAutoRefreshSeconds]) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      fetchAvailableOrders(silent: true);
      fetchAssignedOrders(silent: true);
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
  void dispose() {
    stopAutoRefresh();
    _isDisposed = true;
    super.dispose();
  }
}
