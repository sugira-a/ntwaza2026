import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/api/api_service.dart';
import '../services/realtime/realtime_service.dart';

class AdminOrderProvider with ChangeNotifier {
  final ApiService _apiService;
  Timer? _autoRefreshTimer;
  StreamSubscription? _orderUpdatesSub;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  int _currentPage = 1;
  int _perPage = 50;
  int _total = 0;
  int _pages = 0;
  String? _statusFilter;

  AdminOrderProvider({required ApiService apiService}) : _apiService = apiService;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get total => _total;
  int get pages => _pages;
  String? get statusFilter => _statusFilter;

  Future<void> initialize({int autoRefreshSeconds = 10}) async {
    await fetchOrders();
    startAutoRefresh(intervalSeconds: autoRefreshSeconds);
    _startRealtime();
  }

  void startAutoRefresh({int intervalSeconds = 10}) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      fetchOrders(silent: true);
    });
  }

  void stopAutoRefresh() => _autoRefreshTimer?.cancel();

  Future<void> fetchOrders({
    bool silent = false,
    int page = 1,
    int perPage = 50,
    String? status,
  }) async {
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
      _currentPage = page;
      _perPage = perPage;
      _statusFilter = status;

      var endpoint = '/api/admin/orders?page=$page&per_page=$perPage';
      if (status != null && status.isNotEmpty) {
        endpoint += '&status=$status';
      }

      final response = await _apiService.get(endpoint);

      final List list = (response['orders'] as List?) ?? [];
      _orders = list.map((j) => Order.fromJson(Map<String, dynamic>.from(j))).toList();

      _total = (response['total'] as int?) ?? _orders.length;
      _pages = (response['pages'] as int?) ?? 1;

      if (!silent) _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('error 401') ||
          err.contains('missing authorization') ||
          err.contains('invalid token') ||
          err.contains('error 403') ||
          err.contains('admin access required') ||
          err.contains('forbidden')) {
        stopAutoRefresh();
      }

      _error = 'Failed to load orders: $e';
      if (!silent) _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('❌ Admin orders fetch error: $e');
      }
    }
  }

  void _startRealtime() {
    _orderUpdatesSub?.cancel();
    _orderUpdatesSub = RealtimeService().orderUpdates.listen((_) {
      fetchOrders(silent: true, page: _currentPage, perPage: _perPage, status: _statusFilter);
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    _orderUpdatesSub?.cancel();
    super.dispose();
  }
}

