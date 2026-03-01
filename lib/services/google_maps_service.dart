import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/env_config.dart';
import '../core/constants/api_endpoints.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleMapsService {
  static final _logger = Logger();
  
  /// Get accurate road distance & duration via backend API
  static Future<Map<String, dynamic>?> getRoadDistance({
    required Position userLocation,
    required double destinationLat,
    required double destinationLng,
  }) async {
    try {
      _logger.i('🚗 Calculating road distance via backend API');
      _logger.i('📍 From: ${userLocation.latitude},${userLocation.longitude}');
      _logger.i('📍 To: $destinationLat,$destinationLng');
      
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        _logger.w('⚠️ No auth token found, using fallback');
        return _calculateHaversineFallback(userLocation, destinationLat, destinationLng);
      }
      
      // Call backend endpoint
      final url = Uri.parse('${ApiEndpoints.baseUrl}/api/maps/road-distance');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'origin_lat': userLocation.latitude,
          'origin_lng': userLocation.longitude,
          'dest_lat': destinationLat,
          'dest_lng': destinationLng,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Backend timeout'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        _logger.i('✅ Road distance: ${data['distanceText']}, '
                  'Duration: ${data['durationText']}');
        
        return {
          'distanceKm': data['distanceKm'],
          'distanceText': data['distanceText'],
          'durationMinutes': data['durationMinutes'],
          'durationText': data['durationText'],
          'isAccurate': data['isAccurate'],
          'source': data['source'],
        };
      } else {
        _logger.w('⚠️ Backend returned ${response.statusCode}, using fallback');
      }
      
    } catch (e) {
      _logger.e('❌ Backend API error: $e');
    }
    
    // Fallback to Haversine
    _logger.w('⚠️ Using fallback distance calculation');
    return _calculateHaversineFallback(userLocation, destinationLat, destinationLng);
  }
  
  /// Platform-specific API key selection via EnvConfig (build-time injection)
  static String _getPlatformApiKey() => EnvConfig.googleMapsApiKey;

  /// Get current platform name
  static String _getCurrentPlatform() {
    if (kIsWeb) return 'Web';
    return 'Mobile';
  }
  
  /// Fallback: Vincenty distance calculation with road factor
  static Map<String, dynamic> _calculateHaversineFallback(
    Position userLocation,
    double destLat,
    double destLng,
  ) {
    // Use Vincenty formula via Geolocator (more accurate than Haversine)
    final distanceMeters = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      destLat,
      destLng,
    );
    final distanceKm = distanceMeters / 1000.0;
    
    // Apply road factor for Kigali (hilly terrain, winding roads)
    final estimatedRoadDistance = distanceKm * 1.4;
    final estimatedMinutes = (estimatedRoadDistance * 2.5).round();
    
    _logger.w('⚠️ Using fallback distance: ${estimatedRoadDistance.toStringAsFixed(1)}km (straight-line: ${distanceKm.toStringAsFixed(1)}km)');
    
    return {
      'distanceKm': estimatedRoadDistance,
      'distanceText': '~${estimatedRoadDistance.toStringAsFixed(1)} km',
      'durationMinutes': estimatedMinutes,
      'durationText': '~$estimatedMinutes mins',
      'isAccurate': false,
      'source': 'vincenty_estimated',
      'warning': 'Road distance estimated. GPS may be inaccurate.',
    };
  }
  
  static double _toRadians(double degrees) => degrees * (pi / 180);
  
  /// Calculate delivery fee based on road distance
  static double calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= 2.0) {
      return 0.0;
    } else if (distanceKm <= 5.0) {
      return 500.0;
    } else if (distanceKm <= 10.0) {
      return 1000.0;
    } else if (distanceKm <= 15.0) {
      return 1500.0;
    } else {
      return 1500.0 + ((distanceKm - 15.0) * 200.0);
    }
  }
  
  /// Calculate total delivery time
  static int calculateTotalDeliveryTime({
    required int prepTimeMinutes,
    required int travelTimeMinutes,
  }) {
    const bufferMinutes = 10;
    return prepTimeMinutes + travelTimeMinutes + bufferMinutes;
  }
  
  /// Format delivery time for display
  static String formatDeliveryTime(int minutes) {
    if (minutes < 60) {
      return '$minutes mins';
    } else {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      return remainingMins > 0 ? '${hours}h ${remainingMins}m' : '${hours}h';
    }
  }
  
  /// Validate API key for current platform
  static Future<bool> validateApiKey() async {
    try {
      final apiKey = _getPlatformApiKey();
      final platform = _getCurrentPlatform();
      
      _logger.i('🔑 Validating $platform API key...');
      
      final testUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=-1.9706,30.1044'
        '&destinations=-1.9441,30.0619'
        '&mode=driving'
        '&key=$apiKey'
      );
      
      final response = await http.get(testUrl).timeout(
        const Duration(seconds: 5),
      );
      
      final isValid = response.statusCode == 200;
      _logger.i('✅ $platform API key: ${isValid ? 'VALID' : 'INVALID'}');
      
      return isValid;
    } catch (e) {
      _logger.e('❌ Error validating API key: $e');
      return false;
    }
  }
  
  /// Test all API keys
  static Future<Map<String, bool>> testAllApiKeys() async {
    final results = <String, bool>{};
    
    try {
      // Test each key
      for (final entry in {
        'web': EnvConfig.googleMapsWebKey,
        'android': EnvConfig.googleMapsAndroidKey,
        'ios': EnvConfig.googleMapsIosKey,
      }.entries) {
        final testUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=-1.9706,30.1044'
          '&destinations=-1.9441,30.0619'
          '&mode=driving'
          '&key=${entry.value}'
        );
        final resp = await http.get(testUrl).timeout(
          const Duration(seconds: 5),
        );
        results[entry.key] = resp.statusCode == 200;
      }
      
      _logger.i('🔑 API Key Test Results: $results');
      
    } catch (e) {
      _logger.e('❌ Error testing API keys: $e');
      results['error'] = false;
    }
    
    return results;
  }
}