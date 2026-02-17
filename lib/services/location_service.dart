// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin, pi, sin;

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  DateTime? _lastLocationUpdate;
  
  // 🔧 NEW: Location staleness threshold (1 hour)
  static const int _locationStaleMinutes = 60;
  
  Position? get currentPosition => _currentPosition;
  bool get hasLocation => _currentPosition != null;
  
  // 🔧 NEW: Check if location is stale
  bool get isLocationStale {
    if (_lastLocationUpdate == null) return true;
    final minutesSinceUpdate = DateTime.now().difference(_lastLocationUpdate!).inMinutes;
    return minutesSinceUpdate > _locationStaleMinutes;
  }

  /// Check and request location permissions
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Location services are disabled');
      return false;
    }

    // Check current permission status
    permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Location permission permanently denied');
      return false;
    }

    print('✅ Location permission granted');
    return true;
  }

  /// Get current user location with automatic staleness detection
  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    try {
      // 🔧 CRITICAL FIX: Auto-refresh if location is stale
      final shouldRefresh = forceRefresh || isLocationStale;
      
      if (!shouldRefresh && _currentPosition != null) {
        print('📍 Using cached location (${DateTime.now().difference(_lastLocationUpdate!).inMinutes} mins old)');
        return _currentPosition;
      }

      print('🔄 ${shouldRefresh && !forceRefresh ? 'Location is stale, refreshing...' : 'Fetching fresh location...'}');

      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        print('❌ No location permission');
        return null;
      }

      print('📡 Getting current position...');
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10), // 🔧 Add timeout
      );
      
      _lastLocationUpdate = DateTime.now();
      
      print('✅ Location updated: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      print('   Accuracy: ${_currentPosition!.accuracy}m');
      print('   Timestamp: $_lastLocationUpdate');
      
      return _currentPosition;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  /// 🔧 NEW: Force refresh and clear cache
  Future<Position?> forceRefreshLocation() async {
    print('🔄 Force refreshing location...');
    _currentPosition = null;
    _lastLocationUpdate = null;
    return await getCurrentLocation(forceRefresh: true);
  }

  /// 🔧 NEW: Get location info for debugging
  Map<String, dynamic> getLocationInfo() {
    return {
      'has_location': hasLocation,
      'is_stale': isLocationStale,
      'latitude': _currentPosition?.latitude,
      'longitude': _currentPosition?.longitude,
      'accuracy': _currentPosition?.accuracy,
      'last_update': _lastLocationUpdate?.toIso8601String(),
      'minutes_old': _lastLocationUpdate != null 
          ? DateTime.now().difference(_lastLocationUpdate!).inMinutes 
          : null,
    };
  }

  /// Calculate distance between two points in kilometers using Haversine formula
  double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);

    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadians(startLat)) *
            cos(_toRadians(endLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Format distance for display
  String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km';
    }
  }

  /// Calculate estimated delivery time based on distance
  /// Returns a range like "25-35 mins"
  String calculateDeliveryTimeRange(double distanceKm, int prepTimeMinutes) {
    // Average speed: 30 km/h in city traffic
    const double avgSpeedKmPerHour = 30.0;
    
    // Calculate travel time in minutes
    final travelTimeMinutes = (distanceKm / avgSpeedKmPerHour * 60).round();
    
    // Total time = prep time + travel time
    final minTime = prepTimeMinutes + (travelTimeMinutes * 0.8).round(); // -20% for best case
    final maxTime = prepTimeMinutes + (travelTimeMinutes * 1.2).round(); // +20% for worst case
    
    return '$minTime-$maxTime mins';
  }

  /// 🔧 NEW: Calculate dynamic delivery time (matches backend logic)
  int calculateDeliveryTime(double distanceKm) {
    // 15 min prep + 2 min per km (matches Python backend)
    final deliveryTime = (15 + (distanceKm * 2)).round();
    return deliveryTime.clamp(20, 180); // Min 20 mins, max 3 hours
  }

  /// 🔧 NEW: Calculate dynamic delivery fee (matches backend logic)
  double calculateDeliveryFee(double distanceKm, {double baseFee = 2000}) {
    // Base fee + 300 RWF per km beyond 5km (matches Python backend)
    if (distanceKm > 5) {
      return baseFee + ((distanceKm - 5) * 300);
    }
    return baseFee;
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for when permission is permanently denied)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// 🔧 NEW: Start listening to location updates
  Stream<Position> getLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100, // Update every 100 meters
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).map((position) {
      _currentPosition = position;
      _lastLocationUpdate = DateTime.now();
      print('📍 Location updated: ${position.latitude}, ${position.longitude}');
      return position;
    });
  }
}