import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/env_config.dart';

class GoogleMapsService {
  static final _logger = Logger();
  
  /// Get accurate road distance & duration
  static Future<Map<String, dynamic>?> getRoadDistance({
    required Position userLocation,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final origin = '${userLocation.latitude},${userLocation.longitude}';
    final destination = '$destinationLat,$destinationLng';
    
    // ✅ Get platform-specific API key
    final apiKey = _getPlatformApiKey();
    
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=$origin'
      '&destinations=$destination'
      '&mode=driving'
      '&key=$apiKey'
      '&departure_time=now'
    );

    try {
      _logger.i('🚗 Calculating road distance: $origin → $destination');
      _logger.i('📱 Platform: ${_getCurrentPlatform()}');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Google Maps timeout'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && 
            data['rows'].isNotEmpty && 
            data['rows'][0]['elements'].isNotEmpty) {
          
          final element = data['rows'][0]['elements'][0];
          
          if (element['status'] == 'OK') {
            final distanceKm = element['distance']['value'] / 1000.0;
            final durationMinutes = (element['duration']['value'] / 60).round();
            
            _logger.i('✅ Road distance: ${element['distance']['text']}, '
                      'Duration: ${element['duration']['text']}');
            
            return {
              'distanceKm': distanceKm,
              'distanceText': element['distance']['text'],
              'durationMinutes': durationMinutes,
              'durationText': element['duration']['text'],
              'isAccurate': true,
              'source': 'google_maps',
            };
          }
        }
      }
      
      _logger.w('⚠️ Google Maps API failed, using fallback');
      return _calculateHaversineFallback(userLocation, destinationLat, destinationLng);
      
    } catch (e) {
      _logger.e('❌ Google Maps error: $e');
      return _calculateHaversineFallback(userLocation, destinationLat, destinationLng);
    }
  }
  
  /// Platform-specific API key selection via EnvConfig (build-time injection)
  static String _getPlatformApiKey() => EnvConfig.googleMapsApiKey;

  /// Get current platform name
  static String _getCurrentPlatform() {
    if (kIsWeb) return 'Web';
    return 'Mobile';
  }
  
  /// Fallback: Haversine calculation
  static Map<String, dynamic> _calculateHaversineFallback(
    Position userLocation,
    double destLat,
    double destLng,
  ) {
    final distanceKm = _haversineDistance(
      userLocation.latitude,
      userLocation.longitude,
      destLat,
      destLng,
    );
    
    final estimatedRoadDistance = distanceKm * 1.3;
    final estimatedMinutes = (estimatedRoadDistance * 2.5).round();
    
    _logger.w('⚠️ Using fallback distance: ${estimatedRoadDistance.toStringAsFixed(1)}km');
    
    return {
      'distanceKm': estimatedRoadDistance,
      'distanceText': '~${estimatedRoadDistance.toStringAsFixed(1)} km',
      'durationMinutes': estimatedMinutes,
      'durationText': '~$estimatedMinutes mins',
      'isAccurate': false,
      'source': 'haversine_estimated',
      'warning': 'Road distance estimated. GPS may be inaccurate.',
    };
  }
  
  /// Haversine formula
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
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