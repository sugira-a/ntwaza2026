import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/address_provider.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../models/delivery_address.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _taglineFade;
  String _statusText = '';
  bool _isRequestingPermissions = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _taglineFade = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    _fadeController.forward();
    _scaleController.forward();

    // Start permission flow after splash animation plays
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _runStartupFlow();
    });
  }

  Future<void> _runStartupFlow() async {
    if (!mounted) return;

    try {
      await _doStartupFlow();
    } catch (e) {
      print('⚠️ Startup flow error: $e');
    }

    // Always navigate to home, even if something failed/timed out
    if (mounted) context.go('/');
  }

  Future<void> _doStartupFlow() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenPermissions = prefs.getBool('has_seen_permissions') ?? false;
    final locationPermission = await Geolocator.checkPermission();
    final hasLocation = locationPermission == LocationPermission.whileInUse ||
        locationPermission == LocationPermission.always;

    // Wait for addressProvider to finish loading from SharedPreferences
    final addressProvider = Provider.of<AddressProvider>(context, listen: false);
    // Give it a moment to load (it was kicked off in main.dart)
    for (int i = 0; i < 10; i++) {
      if (!addressProvider.isLoading || addressProvider.hasAddresses) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (hasLocation && hasSeenPermissions) {
      // Returning user with permission — capture location if no addresses
      if (!addressProvider.hasAddresses) {
        setState(() {
          _isRequestingPermissions = true;
          _statusText = 'Finding nearby vendors...';
        });
        // Let GPS resolve with its own internal timeouts (15s high + 8s low)
        await _captureCurrentLocation();
      }
      return;
    }

    // New user or missing permissions - request them
    setState(() {
      _isRequestingPermissions = true;
      _statusText = 'Setting up...';
    });

    // 1. Request notification permission (fire-and-forget, don't block)
    _requestNotifications();
    if (!mounted) return;

    // 2. Request location permission (native popup — NO timeout on this)
    setState(() => _statusText = 'Getting your location...');
    final locationGranted = await _requestLocation();
    if (!mounted) return;

    if (!locationGranted) {
      // Try once more
      setState(() => _statusText = 'Location is needed for delivery');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      final retryGranted = await _requestLocation();
      if (!mounted) return;

      if (!retryGranted) {
        await prefs.setBool('has_seen_permissions', true);
        // Permission denied — don't create a fake Kigali address.
        // The home screen will prompt the user to add their real location.
        return;
      }
    }

    // 3. Get and save current location — GPS has its own internal timeouts
    setState(() => _statusText = 'Finding nearby vendors...');
    await _captureCurrentLocation();
    if (!mounted) return;

    // 4. Mark permissions seen
    await prefs.setBool('has_seen_permissions', true);
  }

  Future<void> _requestNotifications() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();

      final plugin = FlutterLocalNotificationsPlugin();
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (_) {}
  }

  Future<bool> _requestLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return true;
      }
      // Shows native OS popup
      permission = await Geolocator.requestPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<void> _captureCurrentLocation() async {
    try {
      final locationService = LocationService();
      // Use cached location if available, only force refresh if no location at all
      final position =
          await locationService.getCurrentLocation(forceRefresh: !locationService.hasLocation);

      if (position != null && mounted) {
        String addressText = 'Kigali, Rwanda';
        try {
          // Add timeout to reverse geocoding — it can hang indefinitely
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 3), onTimeout: () => []);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final street = p.street ?? '';
            final subLocality = p.subLocality ?? '';
            final locality =
                p.locality ?? p.subAdministrativeArea ?? 'Kigali';
            if (street.isNotEmpty) {
              addressText = subLocality.isNotEmpty
                  ? '$street, $subLocality, $locality'
                  : '$street, $locality';
            } else if (subLocality.isNotEmpty) {
              addressText = '$subLocality, $locality';
            } else {
              addressText = '$locality, Rwanda';
            }
          }
        } catch (_) {}

        final address = DeliveryAddress(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fullAddress: addressText,
          latitude: position.latitude,
          longitude: position.longitude,
          label: addressText,
          isDefault: true,
          createdAt: DateTime.now(),
        );

        final addressProvider =
            Provider.of<AddressProvider>(context, listen: false);
        await addressProvider.addAddress(address);
        addressProvider.selectAddress(address);
      }
    } catch (e) {
      print('⚠️ Location capture failed: $e');
      // Don't create a fake Kigali address — let the user set their real location
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative green circle top-right
          Positioned(
            right: -90,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF66D36E).withOpacity(0.10),
              ),
            ),
          ),
          // Subtle white circle bottom-left
          Positioned(
            left: -60,
            bottom: 40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),

          // Centered branding
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NTWAZA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF66D36E).withOpacity(0.45),
                            blurRadius: 30,
                          ),
                          Shadow(
                            color: const Color(0xFF66D36E).withOpacity(0.15),
                            blurRadius: 80,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: _taglineFade,
                      child: const Text(
                        'Fast.  Fresh.  On time.',
                        style: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 14,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom status indicator
          if (_isRequestingPermissions)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_statusText.isNotEmpty) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF66D36E)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
