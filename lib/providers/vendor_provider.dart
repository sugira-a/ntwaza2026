import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
  
  // Cache management - persistent storage
  DateTime? _lastFetchTime;
  double? _cachedLatitude;
  double? _cachedLongitude;
  static const int _cacheMinutes = 30;  // Cache for 30 minutes
  static const double _locationThreshold = 0.5;  // 500m threshold for refetch
  static const String _cacheKey = 'cached_vendors';
  static const String _cacheTimeKey = 'vendors_cache_time';
  static const String _cacheLocationKey = 'vendors_cache_location';
  
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
  
  // ==================== CACHE MANAGEMENT ====================
  
  /// Load cached vendors from persistent storage
  Future<bool> loadCachedVendors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache time
      final cacheTimeStr = prefs.getString(_cacheTimeKey);
      if (cacheTimeStr == null) return false;
      
      final cacheTime = DateTime.tryParse(cacheTimeStr);
      if (cacheTime == null) return false;
      
      // Check if cache is expired
      final age = DateTime.now().difference(cacheTime).inMinutes;
      if (age > _cacheMinutes) {
        print('📦 Cache expired (${age}m old)');
        return false;
      }
      
      // Load cached location
      final locationJson = prefs.getString(_cacheLocationKey);
      if (locationJson != null) {
        final loc = json.decode(locationJson);
        _cachedLatitude = loc['lat'];
        _cachedLongitude = loc['lng'];
      }
      
      // Load cached vendors
      final vendorsJson = prefs.getString(_cacheKey);
      if (vendorsJson == null) return false;
      
      final List<dynamic> decoded = json.decode(vendorsJson);
      _vendors = decoded.map((v) => Vendor.fromJson(v)).toList();
      _lastFetchTime = cacheTime;
      
      print('✅ Loaded ${_vendors.length} vendors from cache (${age}m old)');
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error loading cached vendors: $e');
      return false;
    }
  }
  
  /// Save vendors to persistent cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save vendors
      final vendorsJson = json.encode(_vendors.map((v) => v.toJson()).toList());
      await prefs.setString(_cacheKey, vendorsJson);
      
      // Save cache time
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
      
      // Save location
      var (lat, lng) = _coordinates;
      if (lat != null && lng != null) {
        await prefs.setString(_cacheLocationKey, json.encode({'lat': lat, 'lng': lng}));
        _cachedLatitude = lat;
        _cachedLongitude = lng;
      }
      
      print('💾 Saved ${_vendors.length} vendors to cache');
    } catch (e) {
      print('❌ Error saving vendors to cache: $e');
    }
  }
  
  /// Check if location changed significantly (>500m)
  bool _hasLocationChangedSignificantly(double newLat, double newLng) {
    if (_cachedLatitude == null || _cachedLongitude == null) return true;
    
    final distanceKm = Geolocator.distanceBetween(
      _cachedLatitude!, _cachedLongitude!,
      newLat, newLng,
    ) / 1000;
    
    final changed = distanceKm > _locationThreshold;
    if (changed) {
      print('📍 Location changed by ${distanceKm.toStringAsFixed(2)}km (threshold: ${_locationThreshold}km)');
    }
    return changed;
  }
  
  /// Check if we should fetch fresh vendors
  bool shouldFetchVendors({double? lat, double? lng}) {
    // No cache = must fetch
    if (_vendors.isEmpty || _lastFetchTime == null) return true;
    
    // Cache expired = should fetch
    final age = DateTime.now().difference(_lastFetchTime!).inMinutes;
    if (age > _cacheMinutes) return true;
    
    // Location changed significantly = should fetch
    if (lat != null && lng != null && _hasLocationChangedSignificantly(lat, lng)) {
      return true;
    }
    
    return false;
  }
  
  // ==================== Location Management ====================
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
  
  // Vendor Fetching - Smart with persistent caching
  Future<void> fetchVendors({bool forceRefresh = false}) async {
    var (lat, lng) = _coordinates;
    
    // Check if we can use cache
    if (!forceRefresh) {
      // Try memory cache first
      if (_vendors.isNotEmpty && _lastFetchTime != null) {
        if (!shouldFetchVendors(lat: lat, lng: lng)) {
          final age = DateTime.now().difference(_lastFetchTime!).inMinutes;
          print('📦 Using memory cache (${age}m old, ${_vendors.length} vendors)');
          return;
        }
      }
      
      // Try persistent cache if memory is empty
      if (_vendors.isEmpty) {
        final loaded = await loadCachedVendors();
        if (loaded && !shouldFetchVendors(lat: lat, lng: lng)) {
          print('📦 Using disk cache');
          return;
        }
      }
    }
    
    try {
      _isLoading = true;
      _error = null;
      _currentCategory = 'All';
      _searchQuery = '';
      notifyListeners();
      
      print('🚗 Fetching vendors from server...');
      
      // Get or refresh location
      if (lat == null || lng == null) {
        await getUserLocation();
        (lat, lng) = _coordinates;
      }
      
      if (lat == null || lng == null) {
        // Don't throw - keep existing vendors visible instead of showing "no vendors"
        print('⚠️ Location not available yet - keeping existing vendors');
        if (_vendors.isEmpty) {
          await loadCachedVendors();
        }
        _error = null;
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final freshVendors = await _vendorService.getVendors(latitude: lat, longitude: lng);
      // Only replace vendors if we got results; keep old list otherwise
      if (freshVendors.isNotEmpty) {
        _vendors = freshVendors;
      } else if (_vendors.isNotEmpty) {
        print('⚠️ Server returned 0 vendors - keeping cached list');
      } else {
        _vendors = freshVendors;
      }
      _filteredVendors = [];
      _lastFetchTime = DateTime.now();
      
      // Save to persistent cache
      await _saveToCache();
      
      print('✅ Loaded ${_vendors.length} vendors from server');
      
    } catch (e) {
      _error = 'Failed to load vendors: $e';
      print('❌ Error: $e');
      
      // Try to load from cache on error
      if (_vendors.isEmpty) {
        await loadCachedVendors();
      }
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
        // Don't throw - keep existing vendors
        print('⚠️ Location not available - keeping existing vendors');
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final freshVendors = await _vendorService.getVendors(
        category: category,
        latitude: lat,
        longitude: lng,
      );
      if (freshVendors.isNotEmpty || _vendors.isEmpty) {
        _vendors = freshVendors;
      }
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