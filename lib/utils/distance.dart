import 'package:geolocator/geolocator.dart';

/// Calculate distance in km using Vincenty formula (more accurate than Haversine)
double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
}