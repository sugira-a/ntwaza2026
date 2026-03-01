// lib/screens/map/location_picker_screen.dart
// Complete updated version with improved My Location button

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../models/delivery_address.dart';
import '../../providers/address_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/location_validator.dart';
import '../../services/api/api_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../config/env_config.dart';

class LocationPickerScreen extends StatefulWidget {
  final DeliveryAddress? initialAddress;

  const LocationPickerScreen({super.key, this.initialAddress});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = 'Move map to select location';
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = true;
  bool _isCentering = false;
  bool _isMapReady = false;
  String? _addressError;
  bool _isOutsideServiceArea = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _additionalInfoController = TextEditingController();
  String? _selectedLabel;
  Timer? _debounce;
  Set<Circle> _circles = {};
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _isSearching = false;

  // Dark mode map style
  static const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [{"color": "#4e4e4e"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';

  // Default to Kigali center if location fails
  static const LatLng _kigaliCenter = LatLng(
    LocationValidator.kigaliCenterLat, 
    LocationValidator.kigaliCenterLng
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _createServiceAreaCircle();
  }

  void _createServiceAreaCircle() {
    _circles = {
      Circle(
        circleId: const CircleId('service_area'),
        center: _kigaliCenter,
        radius: LocationValidator.serviceRadiusKm * 1000, // Convert to meters
        fillColor: Colors.green.withOpacity(0.1),
        strokeColor: Colors.green.withOpacity(0.5),
        strokeWidth: 2,
      ),
    };
  }

  Future<void> _initializeLocation() async {
    try {
      if (widget.initialAddress != null) {
        // Use provided address
        _selectedLocation = LatLng(
          widget.initialAddress!.latitude,
          widget.initialAddress!.longitude,
        );
        _additionalInfoController.text = widget.initialAddress!.additionalInfo ?? '';
        _selectedLabel = widget.initialAddress!.label;
        _validateSelectedLocation();
        setState(() => _isLoadingLocation = false);
        
        // If address is a placeholder, fetch the real address
        if (widget.initialAddress!.fullAddress == 'Loading address...' ||
            widget.initialAddress!.fullAddress.isEmpty) {
          _selectedAddress = 'Fetching address...';
          _getAddressFromLatLng(_selectedLocation!, showError: false);
        } else {
          _selectedAddress = widget.initialAddress!.fullAddress;
        }
      } else {
        // Try to get current location with timeout
        await _getCurrentLocationWithTimeout();
      }
    } catch (e) {
      // Fall back to Kigali center
      _setDefaultLocation();
    }
  }

  Future<void> _getCurrentLocationWithTimeout() async {
    try {
      // Check if location services are enabled first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationServicesDisabledDialog();
        }
        _setDefaultLocation();
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
        _setDefaultLocation();
        return;
      }

      if (permission == LocationPermission.denied) {
        _setDefaultLocation();
        return;
      }

      // Get location with improved timeout and retry logic
      Position? position;
      int retries = 0;
      const maxRetries = 3;
      
      while (retries < maxRetries) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            forceAndroidLocationManager: false,
            timeLimit: const Duration(seconds: 12),
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Location request timeout');
            },
          );
          break; // Success, exit retry loop
        } catch (e) {
          retries++;
          if (retries >= maxRetries) {
            throw e;
          }
          // Wait before retry
          await Future.delayed(Duration(seconds: retries));
        }
      }

      if (position == null) {
        _setDefaultLocation();
        return;
      }

      _selectedLocation = LatLng(position.latitude, position.longitude);
      _validateSelectedLocation();
      
      // Check if location is outside Kigali
      if (_isOutsideServiceArea) {
        if (mounted) {
          _showOutsideServiceAreaDialog();
        }
      }
      
      setState(() => _isLoadingLocation = false);
      
      // Try to get address, but don't block if it fails
      _getAddressFromLatLng(_selectedLocation!, showError: false);
    } catch (e) {
      _setDefaultLocation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not get your location. Using Kigali center instead.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _getCurrentLocation,
            ),
          ),
        );
      }
    }
  }

  void _showOutsideServiceAreaDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final themeProvider = context.watch<ThemeProvider>();
        final isDarkMode = themeProvider.isDarkMode;
        
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Outside Service Area',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your current location is outside Kigali. We only deliver within ${LocationValidator.serviceRadiusKm}km of Kigali city center.',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please select a location within Kigali to continue',
                        style: TextStyle(
                          color: Colors.amber[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _setDefaultLocation();
              },
              child: Text(
                'Use Kigali Center',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Keep current location but let user search for proper address
              },
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _setDefaultLocation() {
    setState(() {
      _selectedLocation = _kigaliCenter;
      _selectedAddress = 'Kigali City Center (Tap "My Location" to use your position)';
      _isLoadingLocation = false;
      _isOutsideServiceArea = false;
      _addressError = null;
    });
  }

  void _validateSelectedLocation() {
    if (_selectedLocation == null) return;
    
    final validation = LocationValidator.validate(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );
    
    setState(() {
      _isOutsideServiceArea = !validation.isValid;
    });
  }

  Future<void> _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
      });
      return Future.value();
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.length < 2) {
        setState(() => _isSearching = false);
        return;
      }
      await _searchLocationByName(query);
    });

    return Future.value();
  }

  Future<void> _searchLocationByName(String query) async {
    try {
      // Use backend endpoint to avoid CORS issues on web
      final String searchUrl = '${ApiService.baseUrl}/api/geocode/places-search';

      final response = await http.post(
        Uri.parse(searchUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('{"success":false,"error":"timeout"}', 408),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['results'] != null) {
          final List<dynamic> results = data['results'] as List;

          final suggestions = results.map((result) {
            return {
              'address': result['address'] ?? '',
              'secondaryText': result['secondaryText'] ?? '',
              'placeType': result['placeType'] ?? 'Place',
              'fullAddress': result['fullAddress'] ?? '',
              'lat': (result['lat'] as num).toDouble(),
              'lng': (result['lng'] as num).toDouble(),
              'placeId': result['placeId'] ?? '',
              'distance': (result['distance'] as num).toDouble(),
            };
          }).toList();

          if (mounted) {
            setState(() {
              _searchSuggestions = suggestions;
              _isSearching = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _searchSuggestions = [];
              _isSearching = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // Fallback geocoding search for addresses - no longer needed with backend proxy
  Future<void> _searchWithGeocoding(String query) async {
    // Backend already handles fallback, so this is now a no-op
    return;
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusMeters = 6371000; // Earth radius in meters
    final double dLat = _toRadian(lat2 - lat1);
    final double dLon = _toRadian(lon2 - lon1);
    final double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadian(lat1)) * cos(_toRadian(lat2)) * 
        (sin(dLon / 2) * sin(dLon / 2));
    final double c = 2 * asin(sqrt(a));
    return earthRadiusMeters * c;
  }

  double _toRadian(double degree) {
    return degree * 3.141592653589793 / 180;
  }

  IconData _getIconForPlaceType(String? placeType) {
    if (placeType == null || placeType.isEmpty) return Icons.location_on;
    
    switch (placeType.toLowerCase()) {
      case 'bus station':
      case 'transit':
        return Icons.directions_bus;
      case 'restaurant':
        return Icons.restaurant;
      case 'park':
        return Icons.park;
      case 'mall':
      case 'shopping mall':
        return Icons.shopping_bag;
      case 'store':
        return Icons.store;
      case 'hotel':
      case 'lodging':
        return Icons.hotel;
      case 'address':
        return Icons.home_outlined;
      case 'place':
      default:
        return Icons.location_on;
    }
  }

  void _selectSearchSuggestion(Map<String, dynamic> suggestion) {
    final location = LatLng(suggestion['lat'], suggestion['lng']);
    final distance = suggestion['distance'] as double?;
    
    _selectedLocation = location;
    _selectedAddress = suggestion['address'];
    _searchSuggestions = [];
    _searchController.clear();
    _validateSelectedLocation();

    // Show distance warning if location is too far from Kigali center
    if (distance != null && distance > LocationValidator.serviceRadiusKm * 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Location is ${(distance / 1000).toStringAsFixed(1)}km away - outside service area'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (_mapController != null && mounted) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _mapController != null) {
          try {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(location, 16),
            );
          } catch (e) {
            // Silently ignore
          }
        }
      });
    }

    _getAddressFromLatLng(location, showError: false);
    setState(() {});
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Please enable location permissions in your device settings to use your current location. '
          'You can still manually select a delivery location on the map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationServicesDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable location services (GPS) on your device to get your current location. '
          'You can still manually select a delivery location on the map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Enable Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _getAddressFromLatLng(LatLng position, {bool showError = true}) async {
    setState(() {
      _isLoadingAddress = true;
      _addressError = null;
    });

    try {
      // Use backend endpoint to avoid CORS issues on web
      final url = Uri.parse('${ApiService.baseUrl}/api/geocode/reverse');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Address lookup timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['address'] != null) {
          String displayAddress = data['address'] as String;
          
          setState(() {
            _selectedAddress = displayAddress;
            _isLoadingAddress = false;
            _addressError = null;
          });
        } else {
          _setCoordinatesAsAddress(position);
          if (showError && mounted) {
            setState(() {
              _addressError = 'No address found. You can enter it manually below.';
            });
          }
        }
      } else if (response.statusCode == 404) {
        _setCoordinatesAsAddress(position);
        if (showError && mounted) {
          setState(() {
            _addressError = 'No address found. You can enter it manually below.';
          });
        }
      } else {
        _setCoordinatesAsAddress(position);
        if (showError && mounted) {
          setState(() {
            _addressError = 'Unable to fetch address. Tap to enter manually.';
          });
        }
      }
    } catch (e) {
      if (showError && mounted) {
        setState(() {
          _addressError = kIsWeb 
            ? 'Address lookup unavailable on web. Please enter manually.'
            : 'Unable to fetch address. Tap to enter manually.';
        });
      }
      _setCoordinatesAsAddress(position);
    }
  }

  String _extractBestAddress(Map<String, dynamic> result) {
    // Try to build a nice short address from components
    String? placeName;
    String? neighborhood;
    String? locality;
    String? route;
    String? streetNumber;
    
    if (result['address_components'] != null) {
      for (var component in result['address_components']) {
        final types = component['types'] as List<dynamic>;
        final name = component['long_name'] as String?;
        
        if (name != null) {
          if (types.contains('establishment') || types.contains('point_of_interest')) {
            placeName = name;
          } else if (types.contains('neighborhood') || types.contains('sublocality')) {
            neighborhood = name;
          } else if (types.contains('locality')) {
            locality = name;
          } else if (types.contains('route')) {
            route = name;
          } else if (types.contains('street_number')) {
            streetNumber = name;
          }
        }
      }
    }
    
    // Build the display address in order of preference
    List<String> parts = [];
    
    if (placeName != null && placeName.isNotEmpty) {
      parts.add(placeName);
    }
    
    if (route != null && route.isNotEmpty) {
      String streetPart = route;
      if (streetNumber != null && streetNumber.isNotEmpty) {
        streetPart = '$streetNumber $route';
      }
      parts.add(streetPart);
    }
    
    if (neighborhood != null && neighborhood.isNotEmpty && neighborhood != locality) {
      parts.add(neighborhood);
    }
    
    if (locality != null && locality.isNotEmpty) {
      parts.add(locality);
    }
    
    if (parts.isEmpty) {
      // Fallback to formatted address
      return result['formatted_address'] as String;
    }
    
    // Join with commas, but limit to 3 parts for readability
    return parts.take(3).join(', ');
  }

  void _setCoordinatesAsAddress(LatLng position) {
    setState(() {
      _selectedAddress = 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      _isLoadingAddress = false;
    });
  }

  void _showManualAddressInput() {
    final TextEditingController addressController = TextEditingController(
      text: _selectedAddress.startsWith('Location:') ? '' : _selectedAddress,
    );

    showDialog(
      context: context,
      builder: (context) {
        final themeProvider = context.watch<ThemeProvider>();
        final isDarkMode = themeProvider.isDarkMode;
        
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Enter Address Manually',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kIsWeb 
                  ? 'Enter the delivery address for this location.'
                  : 'Automatic address lookup failed. Please enter the address manually.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                autofocus: true,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Full Address',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  hintText: 'e.g., KN 4 Ave, Kimihurura, Kigali',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (addressController.text.trim().isNotEmpty) {
                  setState(() {
                    _selectedAddress = addressController.text.trim();
                    _addressError = null;
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _onMapCreated(GoogleMapController controller) async {
    if (!mounted) return;
    
    _mapController = controller;
    
    // Short delay to let tiles start rendering
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;
    
    setState(() => _isMapReady = true);
    
    if (_selectedLocation != null && mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _mapController != null) {
          try {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
            );
          } catch (e) {
            try {
              _mapController?.moveCamera(
                CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
              );
            } catch (e2) {
              // Silently fail - map will use initial position
            }
          }
        }
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    _selectedLocation = position.target;
    _validateSelectedLocation();
    
    // Clear any previous error
    if (_addressError != null) {
      setState(() => _addressError = null);
    }
  }

  void _onCameraIdle() {
    if (_selectedLocation != null) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 800), () {
        _getAddressFromLatLng(_selectedLocation!, showError: true);
      });
    }
  }

  // Tap on map to select location directly
  void _onMapTap(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _isLoadingAddress = true;
      _addressError = null;
    });
    
    _validateSelectedLocation();
    
    // Move camera to tapped location
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );
    
    // Get address for tapped location
    await _getAddressFromLatLng(position, showError: true);
  }

  /// Recenter map to current location without full-screen loading overlay
  Future<void> _recenterToMyLocation() async {
    if (_isCentering) return;
    try {
      setState(() => _isCentering = true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showLocationServicesDisabledDialog();
        setState(() => _isCentering = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isCentering = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: false,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;

      final location = LatLng(pos.latitude, pos.longitude);

      // Animate camera to new location
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(location, 16),
        );
      }

      setState(() {
        _selectedLocation = location;
        _isCentering = false;
      });

      _validateSelectedLocation();
      await _getAddressFromLatLng(location, showError: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isCentering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get location. Try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoadingLocation = true);

      // Check if location services are enabled first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationServicesDisabledDialog();
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get position with improved accuracy settings
      Position? position;
      int retries = 0;
      
      // Platform-appropriate settings
      final maxRetries = kIsWeb ? 2 : 3;
      final minAccuracyMeters = kIsWeb ? 500.0 : 50.0;
      final desiredAccuracy = kIsWeb ? LocationAccuracy.medium : LocationAccuracy.best;
      final timeoutDuration = kIsWeb ? 10 : 15;

      while (retries < maxRetries) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: desiredAccuracy,
            forceAndroidLocationManager: false,
            timeLimit: Duration(seconds: timeoutDuration),
          ).timeout(
            Duration(seconds: timeoutDuration + 5),
            onTimeout: () {
              throw TimeoutException('Location request timeout');
            },
          );

          final accuracy = position.accuracy;

          // On web, accept any accuracy; on mobile, retry if poor
          if (!kIsWeb && accuracy > minAccuracyMeters && retries < maxRetries - 1) {
            retries++;
            await Future.delayed(Duration(seconds: retries));
            continue;
          }

          break; // Got acceptable accuracy or last retry
        } on TimeoutException {
          retries++;
          if (retries >= maxRetries) {
            throw TimeoutException('Location request timeout after $maxRetries retries');
          }
          await Future.delayed(Duration(seconds: retries));
        }
      }

      if (!mounted || position == null) return;

      final location = LatLng(position.latitude, position.longitude);
      
      // Verify location freshness
      Duration locationAge = Duration.zero;
      if (position.timestamp != null) {
        locationAge = DateTime.now().difference(position.timestamp!);
      }
      
      // Check for impossible location jumps
      final isLocationSuspicious = _selectedLocation != null && 
        _calculateDistance(_selectedLocation!.latitude, _selectedLocation!.longitude, 
                          location.latitude, location.longitude) > 5000;
      
      // Show accuracy warning on mobile only
      if (!kIsWeb && (locationAge.inSeconds > 15 || position.accuracy > 100)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Location accuracy: ${position.accuracy.toStringAsFixed(0)}m. Drag map to adjust if needed.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
      if (isLocationSuspicious) {
        if (mounted) {
          final shouldUse = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Large Location Change'),
              content: const Text('Your location seems to have moved significantly. Use this new location?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Use Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          );
          
          if (shouldUse != true) {
            setState(() => _isLoadingLocation = false);
            return;
          }
        }
      }

      // Check if controller is still valid
      if (_mapController != null && mounted) {
        try {
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted && _mapController != null) {
            await _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(location, 16),
            );
          }
        } catch (e) {
          // Silently ignore - controller may be disposed
        }
      }

      if (!mounted) return;

      setState(() {
        _selectedLocation = location;
        _isLoadingLocation = false;
      });
      
      _validateSelectedLocation();
      
      // Show warning if outside service area
      if (_isOutsideServiceArea && mounted) {
        _showOutsideServiceAreaDialog();
      }
      
      if (mounted) {
        await _getAddressFromLatLng(location);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to get your location. Please try again or select manually on the map.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _getCurrentLocation,
            ),
          ),
        );
      }
    }
  }

  void _confirmLocation() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    // Validate service area
    if (_isOutsideServiceArea) {
      final validation = LocationValidator.validate(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final address = DeliveryAddress(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullAddress: _selectedAddress,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      label: _selectedLabel,
      additionalInfo: _additionalInfoController.text.trim().isNotEmpty
          ? _additionalInfoController.text.trim()
          : null,
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
    );

    // Try to save address
    try {
      final addressProvider = context.read<AddressProvider>();
      addressProvider.addAddress(address);
      addressProvider.selectAddress(address);
      Navigator.pop(context, address);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLabelDialog() {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Label this address',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home, color: Color(0xFF2E7D32)),
              title: Text('Home', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              onTap: () {
                setState(() => _selectedLabel = 'Home');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.work, color: Color(0xFF2E7D32)),
              title: Text('Work', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              onTap: () {
                setState(() => _selectedLabel = 'Work');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFF2E7D32)),
              title: Text('Other', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              onTap: () {
                setState(() => _selectedLabel = 'Other');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    if (_isLoadingLocation) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
        body: SafeArea(
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Google Map with service area circle
          // Google Map with service area circle
GoogleMap(
  key: const ValueKey('google_map_widget'),
  onMapCreated: _onMapCreated,
  initialCameraPosition: CameraPosition(
    target: _selectedLocation ?? _kigaliCenter,
    zoom: 14,
  ),
  onCameraMove: _onCameraMove,
  onCameraIdle: _onCameraIdle,
  onTap: _onMapTap, // Added: Tap to select location
  myLocationEnabled: true,
  myLocationButtonEnabled: false,
  zoomControlsEnabled: false,
  mapToolbarEnabled: false,
  compassEnabled: true,
  rotateGesturesEnabled: true,
  scrollGesturesEnabled: true,
  tiltGesturesEnabled: false,
  zoomGesturesEnabled: true,
  circles: _circles,
  mapType: MapType.normal,
  minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
    Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
    Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
    Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
    Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
  },
),

          // Map Loading Overlay
          if (!_isMapReady)
            Container(
              color: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
              ),
            ),

          // Center Pin - Changes color based on service area
          Center(
            child: Icon(
              Icons.location_on,
              size: 50,
              color: _isOutsideServiceArea ? Colors.red : Colors.green,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),

          // Service Area Warning (when outside)
          if (_isOutsideServiceArea)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Outside service area\nWe only deliver within ${LocationValidator.serviceRadiusKm}km of Kigali',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // My Location Button (Circular button on map)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.4,
            child: FloatingActionButton(
              heroTag: 'location_picker_top',
              mini: true,
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _recenterToMyLocation,
              child: _isCentering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2E7D32),
                      ),
                    )
                  : const Icon(
                      Icons.my_location,
                      color: Color(0xFF2E7D32),
                      size: 22,
                    ),
            ),
          ),

          // Top Bar with Search
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Select Delivery Location',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search places, streets, restaurants...',
                            hintStyle: TextStyle(
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      // Search Suggestions Dropdown
                      if (_searchSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                            ),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchSuggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _searchSuggestions[index];
                              final String mainText = suggestion['address'].toString();
                              final String? secondaryText = suggestion['secondaryText']?.toString();
                              final String? placeType = suggestion['placeType']?.toString();
                              final double distanceKm = (suggestion['distance'] as double) / 1000;
                              
                              return GestureDetector(
                                onTap: () => _selectSearchSuggestion(suggestion),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: index < _searchSuggestions.length - 1
                                        ? Border(
                                            bottom: BorderSide(
                                              color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E7D32).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getIconForPlaceType(placeType),
                                          size: 20,
                                          color: const Color(0xFF2E7D32),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    mainText,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDarkMode ? Colors.white : Colors.black,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (placeType != null && placeType.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      placeType,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w500,
                                                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (secondaryText != null && secondaryText.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      secondaryText,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${distanceKm.toStringAsFixed(1)}km',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Searching...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Re-center to My Location Button (Small circular button)
          Positioned(
            right: 16,
            bottom: 220,
            child: FloatingActionButton(
              heroTag: 'location_picker_bottom',
              mini: true,
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _recenterToMyLocation,
              child: _isCentering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2E7D32),
                      ),
                    )
                  : const Icon(
                      Icons.my_location,
                      color: Color(0xFF2E7D32),
                      size: 24,
                    ),
            ),
          ),

          // Bottom Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Address
                      GestureDetector(
                        onTap: () {
                          if (_addressError != null || _selectedAddress.startsWith('Lat:')) {
                            _showManualAddressInput();
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: _isOutsideServiceArea ? Colors.red : Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delivery Address',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_isLoadingAddress)
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Fetching address...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDarkMode ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      _selectedAddress,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  if (_addressError != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _addressError!,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.edit, size: 14, color: Colors.orange),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Label
                      GestureDetector(
                        onTap: _showLabelDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedLabel == 'Home'
                                    ? Icons.home
                                    : _selectedLabel == 'Work'
                                        ? Icons.work
                                        : Icons.location_on,
                                size: 20,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedLabel ?? 'Add label (Home, Work, etc.)',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Additional Info
                      TextField(
                        controller: _additionalInfoController,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Apartment, floor, gate code (optional)',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                          ),
                          prefixIcon: Icon(
                            Icons.info_outline,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isOutsideServiceArea ? null : _confirmLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isOutsideServiceArea 
                                ? Colors.grey 
                                : const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey,
                          ),
                          child: Text(
                            _isOutsideServiceArea 
                                ? 'Location Outside Service Area' 
                                : 'Confirm Location',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _additionalInfoController.dispose();
    // Do NOT call dispose() on the GoogleMapController for web builds.
    // The web implementation may assert if dispose is called before the
    // underlying JS view is ready. Just clear the reference.
    _mapController = null;
    
    super.dispose();
  }
}