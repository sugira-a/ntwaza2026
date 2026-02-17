import 'package:flutter/material.dart';
import '../services/api/api_service.dart';

class RiderProvider with ChangeNotifier {
  final ApiService _apiService;

  RiderProvider({required ApiService apiService}) : _apiService = apiService;

  List<Map<String, dynamic>> _riders = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get riders => _riders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRiders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _apiService.get('/api/admin/riders');
      if (resp is Map && resp['success'] == true && resp['riders'] is List) {
        _riders = List<Map<String, dynamic>>.from(resp['riders']);
      } else {
        _error = resp is Map ? (resp['error']?.toString() ?? 'Failed to load riders') : 'Failed to load riders';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRider(Map<String, dynamic> data) async {
    try {
      final resp = await _apiService.post('/api/admin/riders', data);
      if (resp is Map && resp['success'] == true) {
        await fetchRiders();
        return true;
      }
      _error = resp is Map ? (resp['error']?.toString() ?? 'Failed to create rider') : 'Failed to create rider';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignOrderToRider(String riderId, String orderId) async {
    try {
      final resp = await _apiService.post('/api/riders/$riderId/assign-order', {'order_id': orderId});
      return resp is Map && resp['success'] == true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
