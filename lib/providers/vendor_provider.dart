import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/vendor.dart';
import '../models/delivery_address.dart';
import '../services/api/api_service.dart';
import '../services/vendor_service.dart';
import '../services/location_service.dart';

class VendorProvider with ChangeNotifier {
  final VendorService _vendorService;
  
  List<Vendor> _vendors = [];
  List<Vendor> _filteredVendors = [];
  bool _isLoading = false;
  String? _error;
  Position? _userLocation;
  DeliveryAddress? _selectedDeliveryAddress;
  String _currentCategory = 'All';
  String _searchQuery = '';
  
  VendorProvider({
    required ApiService apiService,
    required LocationService locationService,
  }) : _vendorService = VendorService(api: apiService);
  
  // Getters
  List<Vendor> get vendors => _filteredVendors.isEmpty && _searchQuery.isEmpty 
      ? _vendors : _filteredVendors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Position? get userLocation => _userLocation;
  DeliveryAddress? get selectedDeliveryAddress => _selectedDeliveryAddress;
  bool get hasLocation => _userLocation != null || _selectedDeliveryAddress != null;
  String get currentCategory => _currentCategory;
  String get searchQuery => _searchQuery;
  
  // Get current coordinates (from delivery address or GPS)
  (double?, double?) get _coordinates {
    if (_selectedDeliveryAddress != null) {
      return (_selectedDeliveryAddress!.latitude, _selectedDeliveryAddress!.longitude);
    }
    if (_userLocation != null) {
      return (_userLocation!.latitude, _userLocation!.longitude);
    }
    return (null, null);
  }
  
  // Location Management
  Future<Position?> getUserLocation() async {
    try {
      print('📍 Getting user location...');
      _userLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      
      if (_userLocation != null) {
        print('✅ Location: ${_userLocation!.latitude}, ${_userLocation!.longitude}');
      }
      
      notifyListeners();
      return _userLocation;
    } catch (e) {
      print('❌ Location error: $e');
      return null;
    }
  }

  Future<void> setDefaultKigaliLocation() async {
    _userLocation = Position(
      latitude: -1.9441,
      longitude: 30.0619,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    print('✅ Default Kigali location set');
    notifyListeners();
  }
  
  void setDeliveryAddress(DeliveryAddress? address) {
    _selectedDeliveryAddress = address;
    
    if (address != null) {
      _userLocation = Position(
        latitude: address.latitude,
        longitude: address.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      print('✅ Delivery address: ${address.fullAddress}');
      print('📍 Coordinates: ${address.latitude}, ${address.longitude}');
    }
    
    notifyListeners();
  }
  
  // Search & Filter
  void searchVendors(String query) {
    _searchQuery = query.toLowerCase().trim();
    
    if (_searchQuery.isEmpty) {
      _filteredVendors = [];
    } else {
      _filteredVendors = _vendors.where((vendor) {
        // Use the actual Vendor model properties
        // Adjust these property names based on your Vendor model
        final name = vendor.name.toLowerCase();
        final category = vendor.category.toLowerCase();
        
        return name.contains(_searchQuery) || 
               category.contains(_searchQuery);
      }).toList();
      
      print('🔍 Search "$_searchQuery": ${_filteredVendors.length} results');
    }
    
    notifyListeners();
  }
  
  void clearSearch() {
    _searchQuery = '';
    _filteredVendors = [];
    notifyListeners();
  }
  
  // Vendor Fetching
  Future<void> fetchVendors({bool forceRefresh = false}) async {
    try {
      _isLoading = true;
      _error = null;
      _currentCategory = 'All';
      _searchQuery = '';
      notifyListeners();
      
      print('🚗 Fetching all vendors...');
      
      // Get or refresh location
      var (lat, lng) = _coordinates;
      
      if (lat == null || lng == null) {
        await getUserLocation();
        (lat, lng) = _coordinates;
      }
      
      if (lat == null || lng == null) {
        throw Exception('Location required for delivery calculations');
      }
      
      _vendors = await _vendorService.getVendors(latitude: lat, longitude: lng);
      _filteredVendors = [];
      
      print('✅ Loaded ${_vendors.length} vendors');
      
    } catch (e) {
      _error = 'Failed to load vendors: $e';
      print('❌ Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> fetchVendorsByCategory(String category) async {
    try {
      _isLoading = true;
      _error = null;
      _currentCategory = category;
      _searchQuery = '';
      notifyListeners();
      
      print('🔍 Fetching $category vendors...');
      
      var (lat, lng) = _coordinates;
      
      if (lat == null || lng == null) {
        await getUserLocation();
        (lat, lng) = _coordinates;
      }
      
      if (lat == null || lng == null) {
        throw Exception('Location required');
      }
      
      _vendors = await _vendorService.getVendors(
        category: category,
        latitude: lat,
        longitude: lng,
      );
      _filteredVendors = [];
      
      print('✅ Found ${_vendors.length} $category vendors');
      
    } catch (e) {
      _error = 'Failed to load $category vendors: $e';
      print('❌ Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> refresh() async {
    print('🔄 Refreshing vendors...');
    await fetchVendors(forceRefresh: true);
  }
  
  // Vendor Details
  Vendor? getVendorById(String vendorId) {
    try {
      return _vendors.firstWhere((v) => v.id == vendorId);
    } catch (e) {
      return null;
    }
  }
  
  Future<Vendor?> fetchVendorDetails(String vendorId) async {
    try {
      print('📦 Fetching vendor details: $vendorId');
      
      // Use getVendors with a filter or implement a separate endpoint
      // Since getVendorById doesn't exist in VendorService, 
      // we'll just return from local cache
      final vendor = getVendorById(vendorId);
      
      if (vendor == null) {
        print('⚠️ Vendor not found in cache, consider fetching all vendors');
      }
      
      return vendor;
    } catch (e) {
      print('❌ Failed to fetch vendor details: $e');
      return null;
    }
  }
  
  // Category Helpers
  List<String> get availableCategories {
    final categories = _vendors
        .map((v) => v.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }
  
  @override
  void dispose() {
    _vendors.clear();
    _filteredVendors.clear();
    super.dispose();
  }
}