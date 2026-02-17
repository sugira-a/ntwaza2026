// lib/services/location_persistence_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationPersistenceService {
  static const String _keyLatitude = 'user_latitude';
  static const String _keyLongitude = 'user_longitude';
  static const String _keyAddress = 'user_address';
  static const String _keyCity = 'user_city';
  static const String _keyLastUpdate = 'location_last_update';
  static const String _keyDeviceId = 'device_id';
  
  // Base URL for API
  static const String baseUrl = 'http://localhost:5000/api';
  
  /// Generate or retrieve device ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_keyDeviceId);
    
    if (deviceId == null) {
      // Generate a unique device ID
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      await prefs.setString(_keyDeviceId, deviceId);
      print('📱 Generated new device ID: $deviceId');
    }
    
    return deviceId;
  }
  
  /// Save location locally (SharedPreferences)
  static Future<bool> saveLocationLocally({
    required double latitude,
    required double longitude,
    String? address,
    String? city,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setDouble(_keyLatitude, latitude);
      await prefs.setDouble(_keyLongitude, longitude);
      
      if (address != null) {
        await prefs.setString(_keyAddress, address);
      }
      
      if (city != null) {
        await prefs.setString(_keyCity, city);
      }
      
      await prefs.setString(
        _keyLastUpdate, 
        DateTime.now().toIso8601String()
      );
      
      print('💾 Location saved locally: ($latitude, $longitude)');
      return true;
    } catch (e) {
      print('❌ Error saving location locally: $e');
      return false;
    }
  }
  
  /// Save location to backend (with or without auth)
  static Future<bool> saveLocationToBackend({
    required double latitude,
    required double longitude,
    String? address,
    String? city,
    String? authToken,
  }) async {
    try {
      final deviceId = await getDeviceId();
      
      // Use authenticated or guest endpoint
      final url = authToken != null
          ? '$baseUrl/locations/user/location'
          : '$baseUrl/locations/user/location/save';
      
      final body = {
        'latitude': latitude,
        'longitude': longitude,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (authToken == null) 'device_id': deviceId,
      };
      
      final headers = {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };
      
      print('🌐 Saving location to backend: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        print('✅ Location saved to backend successfully');
        return true;
      } else {
        print('⚠️  Backend save failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error saving location to backend: $e');
      return false;
    }
  }
  
  /// Save location both locally and to backend
  static Future<bool> saveLocation({
    required double latitude,
    required double longitude,
    String? address,
    String? city,
    String? authToken,
  }) async {
    try {
      // Save locally first (always succeeds)
      await saveLocationLocally(
        latitude: latitude,
        longitude: longitude,
        address: address,
        city: city,
      );
      
      // Try to save to backend (may fail if offline)
      await saveLocationToBackend(
        latitude: latitude,
        longitude: longitude,
        address: address,
        city: city,
        authToken: authToken,
      );
      
      return true;
    } catch (e) {
      print('❌ Error in saveLocation: $e');
      return false;
    }
  }
  
  /// Get saved location from local storage
  static Future<Map<String, dynamic>?> getSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final latitude = prefs.getDouble(_keyLatitude);
      final longitude = prefs.getDouble(_keyLongitude);
      
      if (latitude == null || longitude == null) {
        print('📍 No saved location found locally');
        return null;
      }
      
      final address = prefs.getString(_keyAddress);
      final city = prefs.getString(_keyCity);
      final lastUpdate = prefs.getString(_keyLastUpdate);
      
      print('📍 Retrieved saved location: ($latitude, $longitude)');
      
      return {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'city': city,
        'last_update': lastUpdate,
      };
    } catch (e) {
      print('❌ Error getting saved location: $e');
      return null;
    }
  }
  
  /// Get location from backend
  static Future<Map<String, dynamic>?> getLocationFromBackend({
    String? authToken,
  }) async {
    try {
      final deviceId = await getDeviceId();
      
      if (authToken != null) {
        // Authenticated user
        final url = '$baseUrl/locations/user/location';
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('📍 Retrieved location from backend (authenticated)');
          return data['location'];
        }
      } else {
        // Guest user
        final url = '$baseUrl/locations/user/location/get';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'device_id': deviceId}),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('📍 Retrieved location from backend (guest)');
          return data['location'];
        }
      }
      
      print('📍 No location found on backend');
      return null;
    } catch (e) {
      print('❌ Error getting location from backend: $e');
      return null;
    }
  }
  
  /// Get location with fallback: backend -> local storage -> current GPS
  static Future<Map<String, dynamic>?> getLocationWithFallback({
    String? authToken,
    bool requestCurrentIfNotFound = true,
  }) async {
    try {
      // Try backend first
      var location = await getLocationFromBackend(authToken: authToken);
      if (location != null) {
        // Save to local storage for offline access
        await saveLocationLocally(
          latitude: location['latitude'],
          longitude: location['longitude'],
          address: location['address'],
          city: location['city'],
        );
        return location;
      }
      
      // Fallback to local storage
      location = await getSavedLocation();
      if (location != null) {
        return location;
      }
      
      // Last resort: request current location
      if (requestCurrentIfNotFound) {
        print('📍 No saved location found, requesting current location...');
        final currentLocation = await getCurrentLocation();
        
        if (currentLocation != null) {
          // Save the current location
          await saveLocation(
            latitude: currentLocation['latitude'],
            longitude: currentLocation['longitude'],
            authToken: authToken,
          );
          return currentLocation;
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error in getLocationWithFallback: $e');
      return null;
    }
  }
  
  /// Get current GPS location
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      // Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️  Location services are disabled');
        return null;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️  Location permissions denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('⚠️  Location permissions permanently denied');
        return null;
      }
      
      // Get position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      print('📍 Current location: (${position.latitude}, ${position.longitude})');
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting current location: $e');
      return null;
    }
  }
  
  /// Clear saved location
  static Future<bool> clearLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(_keyLatitude);
      await prefs.remove(_keyLongitude);
      await prefs.remove(_keyAddress);
      await prefs.remove(_keyCity);
      await prefs.remove(_keyLastUpdate);
      
      print('🗑️  Cleared saved location');
      return true;
    } catch (e) {
      print('❌ Error clearing location: $e');
      return false;
    }
  }
  
  /// Check if location is stale (older than 24 hours)
  static Future<bool> isLocationStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateStr = prefs.getString(_keyLastUpdate);
      
      if (lastUpdateStr == null) return true;
      
      final lastUpdate = DateTime.parse(lastUpdateStr);
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);
      
      // Consider stale if older than 24 hours
      return difference.inHours > 24;
    } catch (e) {
      print('❌ Error checking location staleness: $e');
      return true;
    }
  }
  
  /// Request location update if stale
  static Future<Map<String, dynamic>?> refreshLocationIfStale({
    String? authToken,
  }) async {
    try {
      final isStale = await isLocationStale();
      
      if (isStale) {
        print('🔄 Location is stale, refreshing...');
        final newLocation = await getCurrentLocation();
        
        if (newLocation != null) {
          await saveLocation(
            latitude: newLocation['latitude'],
            longitude: newLocation['longitude'],
            authToken: authToken,
          );
          return newLocation;
        }
      } else {
        print('✅ Location is fresh');
        return await getSavedLocation();
      }
      
      return null;
    } catch (e) {
      print('❌ Error refreshing location: $e');
      return null;
    }
  }
}