// lib/providers/pickup_order_provider.dart
import 'package:flutter/material.dart';
import '../models/pickup_order.dart';
import '../services/api/api_service.dart';
import '../utils/helpers.dart';

class PickupOrderProvider extends ChangeNotifier {
  final ApiService _apiService;

  // State management
  List<PickupOrder> _pickupOrders = [];
  List<PickupOrder> _pendingOrders = [];
  List<PickupOrder> _assignedOrders = [];
  PickupOrder? _selectedOrder;
  bool _isLoading = false;
  String? _error;

  // Pagination
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalOrders = 0;

  // Filters for admin
  PickupOrderStatus? _selectedStatus;
  String? _selectedRiderId;

  PickupOrderProvider({required ApiService apiService}) : _apiService = apiService;

  // Getters
  List<PickupOrder> get pickupOrders => _pickupOrders;
  List<PickupOrder> get pendingOrders =>
      _pickupOrders.where((o) => o.status == PickupOrderStatus.pending).toList();
  List<PickupOrder> get assignedOrders =>
      _pickupOrders.where((o) => o.riderId != null && o.status != PickupOrderStatus.delivered).toList();
    List<PickupOrder> get riderAssignedOrders => _assignedOrders;
  PickupOrder? get selectedOrder => _selectedOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalOrders => _totalOrders;
  int get currentPage => _currentPage;

  // Fetch all pickup orders (admin)
  Future<void> fetchAllPickupOrders({int page = 1}) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.get(
        '/api/pickup-orders?page=$page&pageSize=$_pageSize',
      );

      if (response['success'] != null && response['success'] as bool) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        _pickupOrders = (data['orders'] as List<dynamic>?)
                ?.map((json) => PickupOrder.fromJson(json as Map<String, dynamic>))
                .toList() ??
            [];
        _totalOrders = data['total'] as int? ?? 0;
        _currentPage = page;

        notifyListeners();
      } else {
        _setError('Failed to fetch pickup orders');
      }
    } catch (e) {
      _setError('Error fetching pickup orders: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch customer's pickup orders
  Future<void> fetchCustomerPickupOrders(String customerId) async {
    _setLoading(true);
    _clearError();

    try {
      final response =
          await _apiService.get('/api/pickup-orders/customer/$customerId');

      if (response['success'] != null && response['success'] as bool) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        _pickupOrders = (data['orders'] as List<dynamic>?)
                ?.map((json) => PickupOrder.fromJson(json as Map<String, dynamic>))
                .toList() ??
            [];

        notifyListeners();
      } else {
        _setError('Failed to fetch customer orders');
      }
    } catch (e) {
      _setError('Error fetching customer orders: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch rider's assigned orders
  Future<void> fetchRiderPickupOrders(String riderId) async {
    _setLoading(true);
    _clearError();

    try {
      final response =
          await _apiService.get('/api/pickup-orders/rider/$riderId');

      if (response['success'] != null && response['success'] as bool) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        _assignedOrders = (data['orders'] as List<dynamic>?)
                ?.map((json) => PickupOrder.fromJson(json as Map<String, dynamic>))
                .toList() ??
            [];

        notifyListeners();
      } else {
        _setError('Failed to fetch rider orders');
      }
    } catch (e) {
      _setError('Error fetching rider orders: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Create a new pickup order
  Future<PickupOrder?> createPickupOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required Map<String, dynamic> pickupLocation,
    required Map<String, dynamic> dropoffLocation,
    required List<Map<String, dynamic>> items,
    required double amount,
    required double deliveryFee,
    required DateTime scheduledPickupTime,
    required String paymentMethod,
    String? notes,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = {
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'pickupLocation': pickupLocation,
        'dropoffLocation': dropoffLocation,
        'items': items,
        'amount': amount,
        'deliveryFee': deliveryFee,
        'totalAmount': amount + deliveryFee,
        'scheduledPickupTime': scheduledPickupTime.toIso8601String(),
        'status': PickupOrderStatus.pending.name,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'createdAt': nowInRwanda().toIso8601String(),
      };

      final response = await _apiService.post('/api/pickup-orders', payload);

      if (response['success'] != null && response['success'] as bool) {
        final orderData = response['data'] as Map<String, dynamic>? ?? {};
        final newOrder = PickupOrder.fromJson(orderData);

        _pickupOrders.insert(0, newOrder);
        notifyListeners();

        return newOrder;
      } else {
        _setError('Failed to create pickup order');
        return null;
      }
    } catch (e) {
      _setError('Error creating pickup order: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Assign rider to pickup order (admin)
  Future<bool> assignRiderToOrder(String orderId, String riderId, String riderName, String riderPhone) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = {
        'riderId': riderId,
        'riderName': riderName,
        'riderPhone': riderPhone,
        'status': PickupOrderStatus.assignedToRider.name,
        'acceptedAt': nowInRwanda().toIso8601String(),
      };

      final response = await _apiService.put(
        '/api/pickup-orders/$orderId',
        payload,
      );

      if (response['success'] != null && response['success'] as bool) {
        // Update local order
        final index = _pickupOrders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          final updatedOrderData = response['data'] as Map<String, dynamic>? ?? {};
          _pickupOrders[index] = PickupOrder.fromJson(updatedOrderData);
          notifyListeners();
        }
        return true;
      } else {
        _setError('Failed to assign rider');
        return false;
      }
    } catch (e) {
      _setError('Error assigning rider: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update pickup order status (rider)
  Future<bool> updateOrderStatus(
    String orderId,
    PickupOrderStatus newStatus, {
    double? riderLatitude,
    double? riderLongitude,
    String? pickupCode,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = {
        'status': newStatus.name,
        'riderLatitude': riderLatitude,
        'riderLongitude': riderLongitude,
      };

      if (pickupCode != null && pickupCode.trim().isNotEmpty) {
        payload['pickupCode'] = pickupCode.trim();
      }

      // Add timestamp based on status
      if (newStatus == PickupOrderStatus.pickedUp) {
        payload['pickedUpAt'] = nowInRwanda().toIso8601String();
      } else if (newStatus == PickupOrderStatus.delivered) {
        payload['deliveredAt'] = nowInRwanda().toIso8601String();
      }

      final response = await _apiService.put(
        '/api/pickup-orders/$orderId',
        payload,
      );

      if (response['success'] != null && response['success'] as bool) {
        // Update local order
        final index = _pickupOrders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          final updatedOrderData = response['data'] as Map<String, dynamic>? ?? {};
          _pickupOrders[index] = PickupOrder.fromJson(updatedOrderData);
          
          // Also update assigned orders if this is a rider view
          final assignedIndex = _assignedOrders.indexWhere((o) => o.id == orderId);
          if (assignedIndex != -1) {
            _assignedOrders[assignedIndex] = PickupOrder.fromJson(updatedOrderData);
          }
          notifyListeners();
        }
        return true;
      } else {
        _setError('Failed to update order status');
        return false;
      }
    } catch (e) {
      _setError('Error updating order status: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Cancel pickup order
  Future<bool> cancelPickupOrder(String orderId, String reason) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = {
        'status': PickupOrderStatus.cancelled.name,
        'notes': reason,
      };

      final response = await _apiService.put(
        '/api/pickup-orders/$orderId',
        payload,
      );

      if (response['success'] != null && response['success'] as bool) {
        // Update local order
        final index = _pickupOrders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          final updatedOrderData = response['data'] as Map<String, dynamic>? ?? {};
          _pickupOrders[index] = PickupOrder.fromJson(updatedOrderData);
          notifyListeners();
        }
        return true;
      } else {
        _setError('Failed to cancel order');
        return false;
      }
    } catch (e) {
      _setError('Error cancelling order: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get order by ID
  Future<void> fetchOrderById(String orderId) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.get('/api/pickup-orders/$orderId');

      if (response['success'] != null && response['success'] as bool) {
        final orderData = response['data'] as Map<String, dynamic>? ?? {};
        _selectedOrder = PickupOrder.fromJson(orderData);
        notifyListeners();
      } else {
        _setError('Failed to fetch order details');
      }
    } catch (e) {
      _setError('Error fetching order: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    if (value) _error = null;
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void setSelectedOrder(PickupOrder? order) {
    _selectedOrder = order;
    notifyListeners();
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void reset() {
    _pickupOrders = [];
    _assignedOrders = [];
    _selectedOrder = null;
    _isLoading = false;
    _error = null;
    _currentPage = 1;
    notifyListeners();
  }
}
