import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/api/api_service.dart';
import '../services/realtime/realtime_service.dart';
import '../utils/helpers.dart';
import 'dart:async';

class VendorOrderProvider with ChangeNotifier {
  final ApiService _apiService;
  Timer? _autoRefreshTimer;
  static const String _vendorOrdersBase = '/api/orders/vendor';
  static const int _defaultAutoRefreshSeconds = 15;
  StreamSubscription? _orderUpdatesSub;
  
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = false;
  String? _error;
  String _currentFilter = 'all';
  int _unreadNotificationCount = 0;
  
  VendorOrderProvider({required ApiService apiService}) : _apiService = apiService;
  
  List<Order> get orders => _filteredOrders.isEmpty && _currentFilter == 'all' ? _orders : _filteredOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentFilter => _currentFilter;
  int get unreadNotificationCount => _unreadNotificationCount;
  
  int get pendingCount => _orders.where((o) => o.status == OrderStatus.pending).length;
  int get confirmedCount => _orders.where((o) => o.status == OrderStatus.confirmed).length;
  int get preparingCount => _orders.where((o) => o.status == OrderStatus.preparing).length;
  int get readyCount => _orders.where((o) => o.status == OrderStatus.ready).length;
  int get completedCount => _orders.where((o) => o.status == OrderStatus.completed).length;
  int get totalActiveOrders => pendingCount + confirmedCount + preparingCount + readyCount;
  
  double get todayRevenue {
    final today = nowInRwanda();
    return _orders.where((o) {
      final orderDate = toRwandaTime(o.createdAt);
      return orderDate.year == today.year &&
        orderDate.month == today.month &&
        orderDate.day == today.day &&
        o.status == OrderStatus.completed;
    }).fold(0.0, (sum, o) => sum + o.total);
  }
  
  int get todayOrderCount {
    final today = nowInRwanda();
    return _orders.where((o) {
      final orderDate = toRwandaTime(o.createdAt);
      return orderDate.year == today.year &&
        orderDate.month == today.month &&
        orderDate.day == today.day;
    }).length;
  }
  
  Future<void> initialize({int autoRefreshSeconds = _defaultAutoRefreshSeconds}) async {
    await fetchOrders();
    await fetchUnreadNotificationCount();
    startAutoRefresh(intervalSeconds: autoRefreshSeconds);
    _startRealtime();
  }

  void _startRealtime() {
    _orderUpdatesSub?.cancel();
    _orderUpdatesSub = RealtimeService().orderUpdates.listen((payload) {
      try {
        final dynamic orderJson = payload['order'] ?? payload;
        if (orderJson is Map) {
          final order = Order.fromJson(Map<String, dynamic>.from(orderJson));
          _updateLocalOrder(order);
          return;
        }
      } catch (_) {
        // Fallback: refresh silently
      }
      fetchOrders(silent: true);
    });
  }
  
  void startAutoRefresh({int intervalSeconds = _defaultAutoRefreshSeconds}) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      fetchOrders(silent: true);
      fetchUnreadNotificationCount();
    });
  }
  
  void stopAutoRefresh() => _autoRefreshTimer?.cancel();
  
  Future<void> fetchOrders({bool silent = false}) async {
    // Skip if no auth token is present (prevents 401 spam after logout)
    if ((_apiService.authToken ?? _apiService.token) == null) {
      stopAutoRefresh();
      if (!silent) {
        _isLoading = false;
        _error = null;
        notifyListeners();
      }
      return;
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    
    try {
      String endpoint = '$_vendorOrdersBase?page=1&per_page=20';
      if (_currentFilter != 'all') endpoint += '&status=$_currentFilter';
      
      final response = await _apiService.get(endpoint);
      final List ordersList = response['orders'] ?? [];
      
      _orders = ordersList.map((json) => Order.fromJson(json)).toList();
      _applyFilter(_currentFilter);
      
      if (!silent) _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      final err = e.toString().toLowerCase();
      // Stop background polling on auth/permission errors to avoid hammering the backend.
      if (err.contains('error 401') ||
          err.contains('missing authorization') ||
          err.contains('invalid token') ||
          err.contains('error 403') ||
          err.contains('no vendor account found') ||
          err.contains('forbidden')) {
        stopAutoRefresh();
      }
      _error = 'Failed to load orders: $e';
      if (!silent) _isLoading = false;
      notifyListeners();
      print('Error fetching orders: $e');
    }
  }
  
  void setFilter(String filter) {
    _currentFilter = filter;
    _applyFilter(filter);
    notifyListeners();
  }
  
  void _applyFilter(String filter) {
    if (filter == 'all') {
      _filteredOrders = [];
      return;
    }
    final status = OrderStatus.fromString(filter);
    _filteredOrders = _orders.where((o) => o.status == status).toList();
  }
  
  Future<Order?> getOrderById(String orderId) async {
    try {
      final response = await _apiService.get('$_vendorOrdersBase/$orderId');
      final order = Order.fromJson(response['order']);
      
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = order;
        _applyFilter(_currentFilter);
        notifyListeners();
      }
      return order;
    } catch (e) {
      print('Error fetching order: $e');
      return null;
    }
  }
  
  Future<bool> acceptOrder(String orderId, {int? prepTimeMinutes}) async {
    try {
      final currentOrderResponse = await _apiService.get('$_vendorOrdersBase/$orderId');
      final currentOrder = Order.fromJson(currentOrderResponse['order']);
      
      print('🔍 Current order status: ${currentOrder.status.value}');
      
      if (currentOrder.status != OrderStatus.pending) {
        print('⚠️ Order already accepted (status: ${currentOrder.status.value})');
        _updateLocalOrder(currentOrder);
        return true;
      }
      
      final response = await _apiService.put(
        '$_vendorOrdersBase/$orderId/status',
        {
          'status': 'confirmed',
          if (prepTimeMinutes != null) 'prep_time_minutes': prepTimeMinutes,
        },
      );
      
      final order = Order.fromJson(response['order']);
      _updateLocalOrder(order);
      return true;
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Cannot change from confirmed to confirmed') ||
          errorMessage.contains('Order already in confirmed status')) {
        print('✅ Order already confirmed - treating as success');
        await getOrderById(orderId);
        return true;
      }
      
      _error = 'Failed to accept order: $e';
      notifyListeners();
      print('❌ Accept order error: $e');
      return false;
    }
  }
  
  Future<bool> rejectOrder(String orderId, String reason) async {
    try {
      final currentOrder = _orders.firstWhere(
        (o) => o.id == orderId,
        orElse: () => throw Exception('Order not found'),
      );
      
      if (currentOrder.status == OrderStatus.cancelled || currentOrder.status == OrderStatus.completed) {
        print('⚠️ Order cannot be rejected (status: ${currentOrder.status.value})');
        _error = 'Cannot reject order in ${currentOrder.status.value} status';
        notifyListeners();
        return false;
      }
      
      final response = await _apiService.put(
        '$_vendorOrdersBase/$orderId/status',
        {'status': 'cancelled', 'reason': reason},
      );
      
      final order = Order.fromJson(response['order']);
      _updateLocalOrder(order);
      return true;
    } catch (e) {
      _error = 'Failed to reject order: $e';
      notifyListeners();
      print('❌ Reject order error: $e');
      return false;
    }
  }
  
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      final response = await _apiService.put(
        '$_vendorOrdersBase/$orderId/status',
        {'status': status.value},
      );
      final order = Order.fromJson(response['order']);
      _updateLocalOrder(order);
      return true;
    } catch (e) {
      _error = 'Failed to update order: $e';
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> markOrderPreparing(String orderId) => updateOrderStatus(orderId, OrderStatus.preparing);
  Future<bool> markOrderReady(String orderId) => updateOrderStatus(orderId, OrderStatus.ready);
  Future<bool> markOrderCompleted(String orderId) => updateOrderStatus(orderId, OrderStatus.completed);
  
  void _updateLocalOrder(Order order) {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      _orders[index] = order;
    } else {
      _orders.insert(0, order);
    }
    _applyFilter(_currentFilter);
    notifyListeners();
  }
  
  Future<void> fetchUnreadNotificationCount() async {
    try {
      // Skip if no auth token is present
      if ((_apiService.authToken ?? _apiService.token) == null) {
        print('⚠️ Skipping unread notification count fetch - no auth token');
        return;
      }

      final response = await _apiService.get('/api/notifications/unread-count');
      _unreadNotificationCount = response['count'] ?? response['unread_count'] ?? 0;
      notifyListeners();
    } catch (e) {
      print('Error fetching notification count: $e');
      final err = e.toString().toLowerCase();
      if (err.contains('401') || err.contains('authorization') || err.contains('invalid token')) {
        print('🛑 Authorization error while fetching vendor unread count');
      }
    }
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    stopAutoRefresh();
    _orderUpdatesSub?.cancel();
    _orders.clear();
    _filteredOrders.clear();
    super.dispose();
  }
}
