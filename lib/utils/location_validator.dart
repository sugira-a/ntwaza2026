// lib/utils/location_validator.dart
// Centralized Kigali service area validation

import 'package:geolocator/geolocator.dart';

class LocationValidator {
  // Kigali City Center coordinates (City Hall)
  static const double kigaliCenterLat = -1.9536;
  static const double kigaliCenterLng = 30.0606;
  
  // Service radius in kilometers
  static const double serviceRadiusKm = 25.0;
  
  /// Check if a location is within Kigali service area
  static bool isWithinServiceArea(double latitude, double longitude) {
    final distanceInMeters = Geolocator.distanceBetween(
      latitude,
      longitude,
      kigaliCenterLat,
      kigaliCenterLng,
    );
    
    final distanceInKm = distanceInMeters / 1000;
    return distanceInKm <= serviceRadiusKm;
  }
  
  /// Get distance from Kigali center in kilometers
  static double getDistanceFromKigali(double latitude, double longitude) {
    final distanceInMeters = Geolocator.distanceBetween(
      latitude,
      longitude,
      kigaliCenterLat,
      kigaliCenterLng,
    );
    
    return distanceInMeters / 1000;
  }
  
  /// Get user-friendly error message for out-of-service locations
  static String getOutOfServiceMessage(double latitude, double longitude) {
    final distance = getDistanceFromKigali(latitude, longitude);
    final exceedBy = (distance - serviceRadiusKm).toStringAsFixed(1);
    
    return 'Sorry, we currently only serve within Kigali (${serviceRadiusKm}km radius). '
           'This location is ${exceedBy}km outside our service area.';
  }
  
  /// Validate and return result with details
  static LocationValidationResult validate(double latitude, double longitude) {
    final distance = getDistanceFromKigali(latitude, longitude);
    final isValid = distance <= serviceRadiusKm;
    
    return LocationValidationResult(
      isValid: isValid,
      distanceFromCenter: distance,
      message: isValid 
          ? 'Location is within Kigali service area'
          : getOutOfServiceMessage(latitude, longitude),
    );
  }
}

/// Result object for location validation
class LocationValidationResult {
  final bool isValid;
  final double distanceFromCenter;
  final String message;
  
  LocationValidationResult({
    required this.isValid,
    required this.distanceFromCenter,
    required this.message,
  });
  
  @override
  String toString() => 'LocationValidationResult(isValid: $isValid, distance: ${distanceFromCenter.toStringAsFixed(2)}km)';
}