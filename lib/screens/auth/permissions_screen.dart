import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/address_provider.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../models/delivery_address.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({Key? key}) : super(key: key);

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _isLoadingLocation = false;
  bool _isLoadingNotification = false;
  bool _isCheckingPermissions = true;

  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  Future<void> _checkExistingPermissions() async {
    // Check if location permission already granted
    final locationPermission = await Geolocator.checkPermission();
    final hasLocation = locationPermission == LocationPermission.whileInUse ||
        locationPermission == LocationPermission.always;
    
    if (mounted) {
      setState(() {
        _locationGranted = hasLocation;
        _isCheckingPermissions = false;
      });
      
      // If location already granted, get location in background
      if (hasLocation) {
        _captureLocationInBackground();
      }
    }
  }

  Future<void> _captureLocationInBackground() async {
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation(forceRefresh: true);
      
      if (position != null && mounted) {
        await _saveAddressFromPosition(position);
      }
    } catch (e) {
      print('⚠️ Background location capture failed: $e');
    }
  }

  Future<void> _saveAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      String addressText = 'Kigali, Rwanda';
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        addressText = '${placemark.locality ?? placemark.subAdministrativeArea ?? 'Kigali'}, Rwanda';
      }
      
      final address = DeliveryAddress(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fullAddress: addressText,
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'Current Location',
        isDefault: true,
        createdAt: DateTime.now(),
      );
      
      if (mounted) {
        final addressProvider = Provider.of<AddressProvider>(context, listen: false);
        await addressProvider.addAddress(address);
        print('✅ Location saved: $addressText');
      }
    } catch (e) {
      print('⚠️ Error saving address: $e');
      // Save default Kigali location as fallback
      if (mounted) {
        final addressProvider = Provider.of<AddressProvider>(context, listen: false);
        final kigaliAddress = DeliveryAddress(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fullAddress: 'Kigali, Rwanda',
          latitude: -1.9441,
          longitude: 30.0619,
          label: 'Default Location',
          isDefault: true,
          createdAt: DateTime.now(),
        );
        await addressProvider.addAddress(kigaliAddress);
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoadingLocation = true);
    try {
      final permission = await Geolocator.requestPermission();
      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      
      setState(() => _locationGranted = granted);

      if (granted) {
        // Get current location
        final locationService = LocationService();
        final position = await locationService.getCurrentLocation(forceRefresh: true);
        
        if (position != null && mounted) {
          await _saveAddressFromPosition(position);
        }
      }
    } catch (e) {
      print('❌ Location permission error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _isLoadingNotification = true);
    try {
      // Initialize notification service properly
      final notificationService = NotificationService();
      await notificationService.initialize();
      
      // Also request via flutter_local_notifications for compatibility
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      
      await flutterLocalNotificationsPlugin.initialize(initSettings);
      
      bool granted = false;
      
      // Try Android permission
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        try {
          final androidGranted = await androidPlugin.requestNotificationsPermission();
          granted = androidGranted ?? false;
          print('📱 Android notification permission: ${granted ? 'granted' : 'denied'}');
        } catch (e) {
          print('⚠️ Android notification error: $e');
        }
      }
      
      // Try iOS permission  
      try {
        final iosPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        
        if (iosPlugin != null) {
          final iosGranted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          granted = granted || (iosGranted ?? false);
          print('🍎 iOS notification permission: ${iosGranted == true ? 'granted' : 'denied'}');
        }
      } catch (e) {
        print('⚠️ iOS notification error: $e');
      }
      
      setState(() => _notificationGranted = granted);
      
      if (granted) {
        print('✅ Notification permission granted');
        // Get FCM token
        final fcmToken = await notificationService.getFCMToken();
        print('🔑 FCM Token: $fcmToken');
      } else {
        print('ℹ️ Notification permission skipped');
      }
    } catch (e) {
      print('❌ Notification permission error: $e');
      setState(() => _notificationGranted = false);
    } finally {
      if (mounted) {
        setState(() => _isLoadingNotification = false);
      }
    }
  }

  Future<void> _proceedToApp() async {
    if (!_locationGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to proceed'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Save that user has seen permissions
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_permissions', true);
    
    context.go('/');
  }


  @override
  Widget build(BuildContext context) {
    // Show loading while checking existing permissions
    if (_isCheckingPermissions) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF66D36E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF66D36E)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Checking permissions...',
                style: TextStyle(
                  color: Color(0xFFA7AFB6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: null,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF101010),
                      border: Border.all(color: const Color(0xFF1F1F1F)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_moon,
                      color: Color(0xFFEDEFF2),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101010),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1F1F1F)),
                    ),
                    child: const Text(
                      'Step 1 of 2',
                      style: TextStyle(
                        color: Color(0xFFA7AFB6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Let\'s Get Started',
                    style: TextStyle(
                      color: Color(0xFFEDEFF2),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We need a couple of permissions to serve you better',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFA7AFB6),
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap each card to allow and continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF66D36E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _permissionCard(
                    stepNumber: 1,
                    icon: Icons.location_on_rounded,
                    title: 'Location Access',
                    subtitle: 'Required to find restaurants \nand track deliveries',
                    required: true,
                    isGranted: _locationGranted,
                    isLoading: _isLoadingLocation,
                    onRequest: _requestLocationPermission,
                  ),
                  if (_locationGranted) ...[
                    const SizedBox(height: 20),
                    _permissionCard(
                      stepNumber: 2,
                      icon: Icons.notifications_on_rounded,
                      title: 'Notifications',
                      subtitle: 'Get updates on your \norders and offers',
                      required: false,
                      isGranted: _notificationGranted,
                      isLoading: _isLoadingNotification,
                      onRequest: _requestNotificationPermission,
                      onSkip: () => setState(() {}), // Allow skipping
                    ),
                  ],
                  const Spacer(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _locationGranted ? _proceedToApp : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF66D36E),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFF1B1B1B),
                        disabledForegroundColor: const Color(0xFF6B7682),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _locationGranted ? Icons.check_circle_rounded : Icons.location_on_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _locationGranted ? 'Continue to Home' : 'Enable Location to Continue',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0A0A),
            Color(0xFF141414),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -90,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF66D36E).withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            left: -60,
            bottom: 40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionCard({
    required int stepNumber,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool required,
    required bool isGranted,
    required bool isLoading,
    required VoidCallback onRequest,
    VoidCallback? onSkip,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: !isGranted && !isLoading ? onRequest : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F1113),
                  Color(0xFF141618),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isGranted ? const Color(0xFF66D36E) : const Color(0xFF1F1F1F),
                width: isGranted ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isGranted
                        ? const Color(0xFF66D36E).withOpacity(0.15)
                        : const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color:
                        isGranted ? const Color(0xFF66D36E) : const Color(0xFFA7AFB6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFEDEFF2),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (required)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                '*',
                                style: TextStyle(
                                  color: Color(0xFFFF6B6B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFA7AFB6),
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isGranted ? 'Permission granted' : 'Tap to allow',
                        style: TextStyle(
                          color: isGranted ? const Color(0xFF66D36E) : const Color(0xFF8FA3B0),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isGranted)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF66D36E),
                    size: 24,
                  )
                else if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF66D36E)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF66D36E),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF66D36E).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      required ? 'Allow' : 'Enable',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!required && !isGranted)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    color: Color(0xFFA7AFB6),
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
