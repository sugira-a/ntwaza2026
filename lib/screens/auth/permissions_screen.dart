import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import '../../providers/address_provider.dart';
import '../../services/location_service.dart';
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

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoadingLocation = true);
    try {
      final permission = await Geolocator.requestPermission();
      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      
      setState(() => _locationGranted = granted);

      if (granted) {
        // Get current location using LocationService
        final locationService = LocationService();
        final position = await locationService.getCurrentLocation(forceRefresh: true);
        
        if (position != null && mounted) {
          // Get address from coordinates using geocoding
          try {
            final placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            );
            
            if (placemarks.isNotEmpty && mounted) {
              final placemark = placemarks.first;
              
              // Create address object (Kigali fallback location)
              final address = DeliveryAddress(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                fullAddress: '${placemark.locality ?? 'Kigali'}, Rwanda',
                latitude: position.latitude,
                longitude: position.longitude,
                label: 'Home',
                isDefault: true,
                createdAt: DateTime.now(),
              );
              
              // Save to AddressProvider
              if (mounted) {
                try {
                  final addressProvider = 
                      Provider.of<AddressProvider>(context, listen: false);
                  await addressProvider.addAddress(address);
                  
                  print('✅ Location saved successfully: ${address.fullAddress}');
                } catch (e) {
                  print('⚠️ Error saving address, using default Kigali location: $e');
                  // If validation fails, save as default Kigali location
                  if (mounted) {
                    final addressProvider = 
                        Provider.of<AddressProvider>(context, listen: false);
                    final kigaliAddress = DeliveryAddress(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      fullAddress: 'Kigali, Rwanda',
                      latitude: -1.9441,
                      longitude: 30.0619,
                      label: 'Home',
                      isDefault: true,
                      createdAt: DateTime.now(),
                    );
                    await addressProvider.addAddress(kigaliAddress);
                  }
                }
              }
            }
          } catch (e) {
            print('⚠️ Could not get address from geocoding: $e');
            // Fallback: save default Kigali location if geocoding fails
            if (mounted) {
              try {
                final addressProvider = 
                    Provider.of<AddressProvider>(context, listen: false);
                final kigaliAddress = DeliveryAddress(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  fullAddress: 'Kigali, Rwanda',
                  latitude: -1.9441,
                  longitude: 30.0619,
                  label: 'Home',
                  isDefault: true,
                  createdAt: DateTime.now(),
                );
                await addressProvider.addAddress(kigaliAddress);
              } catch (e) {
                print('❌ Failed to save fallback location: $e');
              }
            }
          }
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
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // Initialize the plugin first
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
      } else {
        print('ℹ️ Notification permission skipped or unavailable on this platform');
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
    context.go('/');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D0E),
        elevation: 0,
        leading: null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
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
              if (_locationGranted)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111416),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1F262A),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: const Color(0xFF66D36E),
                        size: 20,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You\'re all set! Permission granted.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFA7AFB6),
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _locationGranted ? _proceedToApp : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66D36E),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFF22282B),
                    disabledForegroundColor: const Color(0xFF6B7682),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _locationGranted ? 'Continue' : 'Enable Location to Continue',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
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
              color: const Color(0xFF111416),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isGranted ? const Color(0xFF66D36E) : const Color(0xFF1F262A),
                width: isGranted ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isGranted
                        ? const Color(0xFF66D36E).withOpacity(0.15)
                        : const Color(0xFF1F262A),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF66D36E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '$stepNumber',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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
