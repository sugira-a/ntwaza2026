import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/special_offer_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/vendor.dart';
import '../../models/special_offer.dart';
import '../../models/product.dart';
import '../../models/delivery_address.dart';
import '../../screens/vendor/vendor_detail_screen.dart';
import '../../screens/map/location_picker_screen.dart';
import '../../screens/vendor/widgets/product_detail_modal.dart';
import '../../services/api/api_service.dart';
import '../../services/location_service.dart';
import '../../services/realtime/realtime_service.dart';
import '../loading/shimmer_loading.dart';
import 'draggable_ai_assistant.dart';

class CustomerHomeContent extends StatefulWidget {
  const CustomerHomeContent({super.key});

  @override
  State<CustomerHomeContent> createState() => _CustomerHomeContentState();
}

class _CustomerHomeContentState extends State<CustomerHomeContent> {
  final List<String> _categories = ['All', 'Restaurants', 'Supermarkets', 'Others'];
  String _selectedCategory = 'All';
  int? _hoveredCardIndex;
  int _selectedNavIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isInitializing = true;
  DeliveryAddress? _currentAddress;
  final Map<String, Future<Uint8List?>> _vendorImageFutureCache = {};

  // Real-time listeners for auto-refresh (WhatsApp-style)
  StreamSubscription<Map<String, dynamic>>? _orderUpdatesSub;
  StreamSubscription<Map<String, dynamic>>? _notificationsSub;
  StreamSubscription<Map<String, dynamic>>? _contentUpdatesSub;
  DateTime? _lastAutoRefresh;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
      _setupRealtimeListeners();
    });
  }

  /// Listen to real-time socket events and auto-refresh data when changes occur
  void _setupRealtimeListeners() {
    final realtime = RealtimeService();

    // Listen for order updates (e.g. order status changes)
    _orderUpdatesSub = realtime.orderUpdates.listen((payload) {
      if (!mounted) return;
      // Auto-refresh offers & vendors when order-related events arrive
      _throttledAutoRefresh();
    });

    // Listen for push notifications (new offers, vendor changes, etc.)
    _notificationsSub = realtime.notifications.listen((payload) {
      if (!mounted) return;
      final type = payload['type'] as String? ?? '';
      // Auto-refresh on content-relevant notifications
      if (type.contains('offer') || type.contains('vendor') || type.contains('promo') || type.contains('update')) {
        _throttledAutoRefresh();
      }
      // Always refresh notification badge count
      try {
        context.read<NotificationProvider>().fetchUnreadCount();
      } catch (_) {}
    });

    // Listen for content updates (offers changed, vendor status changed, etc.)
    _contentUpdatesSub = realtime.contentUpdates.listen((payload) {
      if (!mounted) return;
      _throttledAutoRefresh();
    });
  }

  /// Throttle auto-refresh to at most once every 15 seconds to avoid spamming
  void _throttledAutoRefresh() {
    final now = DateTime.now();
    if (_lastAutoRefresh != null && now.difference(_lastAutoRefresh!).inSeconds < 15) {
      return;
    }
    _lastAutoRefresh = now;
    _autoRefreshContent();
  }

  /// Silently refresh offers and vendor data in the background (no loading indicator)
  Future<void> _autoRefreshContent() async {
    if (!mounted) return;
    try {
      // Refresh special offers
      await context.read<SpecialOfferProvider>().fetchHomepageOffers();
    } catch (_) {}
    try {
      // Refresh vendors
      final address = _currentAddress;
      if (address != null) {
        await context.read<VendorProvider>().fetchVendors(forceRefresh: true);
      }
    } catch (_) {}
  }

  Future<void> _initializeApp() async {
    try {
      final vendorProvider = context.read<VendorProvider>();
      final addressProvider = context.read<AddressProvider>();
      
      // Initialize push notifications in the background (don't block UI)
      try {
        final notificationProvider = context.read<NotificationProvider>();
        // Fire-and-forget: don't await, let it run in background
        notificationProvider.initialize(pollingInterval: 60).catchError((e) {
          print('⚠️ Customer notification init: $e');
        });
      } catch (e) {
        print('⚠️ Customer notification init: $e');
      }
      
      // First, try to load cached vendors (instant, no API call)
      await vendorProvider.loadCachedVendors();
      
      // addressProvider was already initialized in main.dart — no need to call again
      
      // Prefer the address selected during splash, then default, then first saved
      var defaultAddress = addressProvider.selectedAddress 
          ?? addressProvider.defaultAddress 
          ?? addressProvider.savedAddresses.firstOrNull;
      
      // Auto-detect location if no saved address
      if (defaultAddress == null) {
        defaultAddress = await _autoDetectLocation(addressProvider);
      }
      
      if (defaultAddress != null) {
        // Ensure it's selected for this session
        addressProvider.selectAddress(defaultAddress);
        setState(() {
          _currentAddress = defaultAddress;
          _isInitializing = false;
        });
        
        // If we already have cached vendors, don't block - load in background
        if (vendorProvider.vendors.isNotEmpty) {
          // Load fresh data in background without blocking UI
          _loadVendorsForAddress(defaultAddress, forceRefresh: false);
        } else {
          // No cached vendors, we need to wait for load
          await _loadVendorsForAddress(defaultAddress, forceRefresh: false);
        }
      } else {
        // No address found — first-time user: go straight to the map picker
        setState(() => _isInitializing = false);
        if (mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
          );
          if (result != null && result is DeliveryAddress) {
            if (!_isLocationOutOfKigali(result.latitude, result.longitude)) {
              await addressProvider.addAddress(result);
              addressProvider.selectAddress(result);
              setState(() => _currentAddress = result);
              await _loadVendorsForAddress(result);
            }
          }
        }
      }
    } catch (e) {
      print('Error initializing app: $e');
      setState(() => _isInitializing = false);
    }
  }

  /// Auto-detect current location and create address
  Future<DeliveryAddress?> _autoDetectLocation(AddressProvider addressProvider) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      
      final locationService = LocationService();
      // Use cached location if available to avoid another long GPS wait
      final position = await locationService.getCurrentLocation(forceRefresh: !locationService.hasLocation);
      if (position == null) return null;

      String addressText = 'Kigali, Rwanda';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude,
        ).timeout(const Duration(seconds: 3), onTimeout: () => []);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final street = p.street ?? '';
          final subLocality = p.subLocality ?? '';
          final locality = p.locality ?? p.subAdministrativeArea ?? 'Kigali';
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

      await addressProvider.addAddress(address);
      addressProvider.selectAddress(address);
      return address;
    } catch (e) {
      print('Error auto-detecting location: $e');
      return null;
    }
  }

  Future<void> _loadVendorsForAddress(DeliveryAddress address, {bool forceRefresh = false}) async {
    try {
      final vendorProvider = context.read<VendorProvider>();
      
      // Set the delivery address in vendor provider
      vendorProvider.setDeliveryAddress(address);
      
      // Check if location is within Kigali
      if (_isLocationOutOfKigali(address.latitude, address.longitude)) {
        // Don't load vendors if out of service area
        return;
      }
      
      // Smart fetch: only calls API if cache expired or location changed significantly
      final shouldFetch = forceRefresh || vendorProvider.shouldFetchVendors(
        lat: address.latitude,
        lng: address.longitude,
      );
      
      if (shouldFetch) {
        await vendorProvider.fetchVendors(forceRefresh: forceRefresh);
      } else {
        print('📦 Using cached vendors - no API call needed');
      }
      // Always fetch special offers independently (they change frequently)
      _fetchRealSpecialOffers();
      
      // Mark address as used
      await context.read<AddressProvider>().markAddressAsUsed(address.id);
    } catch (e) {
      print('Error loading vendors: $e');
    }
  }

  bool _isLocationOutOfKigali(double lat, double lng) {
    const kigaliLat = -1.9441;
    const kigaliLng = 30.0619;
    const maxDistanceKm = 25;

    final distance = Geolocator.distanceBetween(lat, lng, kigaliLat, kigaliLng) / 1000;
    return distance > maxDistanceKm;
  }

  Future<void> _fetchRealSpecialOffers() async {
    try {
      final specialOfferProvider = context.read<SpecialOfferProvider>();
      await specialOfferProvider.fetchHomepageOffers();
    } catch (e) {
      print('Error fetching special offers: $e');
    }
  }

  @override
  void dispose() {
    _orderUpdatesSub?.cancel();
    _notificationsSub?.cancel();
    _contentUpdatesSub?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ==================== SEARCH & NAVIGATION ====================
  
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      context.read<SearchProvider>().clearSearch();
      context.read<VendorProvider>().clearSearch();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final searchProvider = context.read<SearchProvider>();
        final vendorProvider = context.read<VendorProvider>();
        
        searchProvider.setUserLocation(vendorProvider.userLocation);
        searchProvider.unifiedSearch(query.trim());
      }
    });
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedNavIndex = index);
    switch (index) {
      case 0:
        _searchController.clear();
        context.read<SearchProvider>().clearSearch();
        context.read<VendorProvider>().clearSearch();
        _handleCategoryTap('All');
        break;
      case 1: _handleCategoryTap('Restaurants'); break;
      case 2: _handleCategoryTap('Supermarkets'); break;
      case 3: 
        final authProvider3 = context.read<AuthProvider>();
        if (authProvider3.isAuthenticated) {
          context.push('/cart');
        } else {
          _showLoginPrompt(context, 'Please login to view your cart');
        }
        break;
      case 4:
        final authProvider4 = context.read<AuthProvider>();
        if (authProvider4.isAuthenticated) {
          context.push('/profile');
        } else {
          _showLoginPrompt(context, 'Please login to view your profile');
        }
        break;
    }
  }

  Future<void> _handleCategoryTap(String category) async {
    setState(() => _selectedCategory = category);
    
    final vendorProvider = context.read<VendorProvider>();
    
    try {
      // Use client-side filtering for all categories (including 'All')
      await vendorProvider.fetchVendorsByCategory(category);
    } catch (e) {
      print('Error fetching category: $e');
    }
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  // ==================== DIALOGS & MENUS ====================
  
  void _showLoginPrompt(BuildContext context, String message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.login_rounded, color: Color(0xFF2E7D32), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Login Required',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(context); 
              context.go('/login'); 
            }, 
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ), 
            child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w600))
          ),
        ],
      ),
    );
  }

  void _showOrdersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Orders'),
        content: const SizedBox(
          width: 300, height: 400, 
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Your orders will appear here', style: TextStyle(color: Colors.grey)),
            ])
          )
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            ListTile(leading: const Icon(Icons.email), title: const Text('Email'), subtitle: Text(authProvider.user?.email ?? '')),
            ListTile(leading: const Icon(Icons.badge), title: const Text('Role'), subtitle: Text(authProvider.user?.role ?? 'Customer')),
            ListTile(leading: const Icon(Icons.account_circle_rounded), title: const Text('User ID'), subtitle: Text(authProvider.user?.id?.toString() ?? 'N/A')),
          ]
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showSettingsMenu(BuildContext context, bool isDarkMode, ThemeProvider themeProvider, Color cardColor, Color textColor, Color subtextColor) {
    final authProvider = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, color: textColor, size: 22),
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(
              height: 1,
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            ),
            
            // Menu items
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildMenuItemWithIcon(
                      icon: Icons.auto_awesome,
                      iconColor: const Color(0xFF2E7D32),
                      title: 'AI Assistant',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/ai-assistant');
                      },
                      textColor: textColor,
                      subtextColor: subtextColor,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 16),
                    if (authProvider.isAuthenticated) ...[
                      _buildMenuItemWithIcon(
                        icon: Icons.assignment_turned_in,
                        iconColor: const Color(0xFF2E7D32),
                        title: 'My Orders',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/my-orders');
                        },
                        textColor: textColor,
                        subtextColor: subtextColor,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),

                      _buildMenuItemWithIcon(
                        icon: Icons.favorite_rounded,
                        iconColor: Colors.redAccent,
                        title: 'My Wishlist',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/wishlist');
                        },
                        textColor: textColor,
                        subtextColor: subtextColor,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),

                      _buildMenuItemWithIcon(
                        icon: Icons.settings,
                        iconColor: Colors.grey[700]!,
                        title: 'Settings',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/profile');
                        },
                        textColor: textColor,
                        subtextColor: subtextColor,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),
                      _buildMenuItemWithIcon(
                        icon: Icons.power_settings_new,
                        iconColor: Colors.red[600]!,
                        title: 'Logout',
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Confirm Logout'),
                              content: const Text('Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext); // Close dialog
                                    Navigator.pop(context); // Close menu
                                    authProvider.logout();
                                    context.go('/');
                                  },
                                  child: const Text(
                                    'Logout',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        textColor: textColor,
                        subtextColor: subtextColor,
                        isDarkMode: isDarkMode,
                      ),
                    ] else ...[
                      _buildMenuItemWithIcon(
                        icon: Icons.login,
                        iconColor: const Color(0xFF2E7D32),
                        title: 'Login',
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/login');
                        },
                        textColor: textColor,
                        subtextColor: subtextColor,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),
                      _buildMenuItemWithIcon(
                        icon: Icons.app_registration,
                        iconColor: Colors.orange[700]!,
                        title: 'Sign Up',
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/register');
                        },
                        textColor: textColor,
                        subtextColor: subtextColor,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Brand footer
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: Column(
                  children: [
                    Text(
                      'NTWAZA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2E7D32),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Order We Deliver',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemWithIcon({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    required Color textColor,
    required Color subtextColor,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String? subtitle, VoidCallback onTap, IconData? trailingIcon, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
                if (subtitle != null) Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
            if (trailingIcon != null) Icon(trailingIcon, size: 14, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  Widget _buildSearchHeader(BuildContext context, bool isDarkMode, Color cardColor, Color textColor, Color subtextColor, 
    VendorProvider vendorProvider, AuthProvider authProvider, ThemeProvider themeProvider) {
  return Container(
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: isDarkMode ? cardColor : const Color(0xFFF8F8F8), 
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.06), blurRadius: 6, offset: const Offset(0, 1))]
    ),
    child: SafeArea(
      bottom: false,
      maintainBottomViewPadding: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('NTWAZA', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5), maxLines: 1),
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: () => _showAddressManagementDialog(context, isDarkMode, cardColor, textColor, subtextColor),
                        child: Row(
                          children: [
                            Icon(
                              _currentAddress != null ? Icons.location_on_rounded : Icons.location_off,
                              size: 14,
                              color: _currentAddress != null ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _currentAddress?.shortAddress ?? _currentAddress?.fullAddress ?? 'Choose location',
                                style: TextStyle(fontSize: 11, color: subtextColor, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, size: 16, color: subtextColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!authProvider.isAuthenticated)
                  TextButton(
                    onPressed: () => context.go('/login'), 
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black, 
                      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[100], 
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8)
                    ),
                    child: Text('Login', style: TextStyle(color: textColor, fontWeight: FontWeight.w600))
                  ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _showSettingsMenu(context, isDarkMode, themeProvider, cardColor, textColor, subtextColor), 
                  icon: Icon(Icons.more_vert, color: textColor, size: 28), 
                  tooltip: 'Menu'
                ),
              ]
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6), 
            child: Container(
              height: 40,
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search here',
                  hintStyle: TextStyle(color: subtextColor, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: subtextColor, size: 20),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: Icon(Icons.clear, color: subtextColor, size: 18), 
                        onPressed: () { 
                          _searchController.clear(); 
                          context.read<SearchProvider>().clearSearch();
                          context.read<VendorProvider>().clearSearch(); 
                        }
                      ) 
                    : null,
                  filled: true, 
                  fillColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), 
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), 
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), 
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
            )
          ),
        ],
      ),
    ),
  );
}

// NEW: Address Management Dialog
void _showAddressManagementDialog(BuildContext context, bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
  final addressProvider = context.read<AddressProvider>();
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: textColor),
                    const SizedBox(width: 12),
                    Text('Delivery Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: subtextColor),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              
              // Saved Addresses List
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (addressProvider.savedAddresses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.location_off, size: 48, color: subtextColor),
                              const SizedBox(height: 16),
                              Text('No saved addresses', style: TextStyle(color: subtextColor)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...addressProvider.savedAddresses.map((address) {
                        final isSelected = _currentAddress?.id == address.id;
                        return Dismissible(
                          key: Key(address.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: sheetContext,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Address'),
                                content: Text('Delete "${address.shortAddress}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ) ?? false;
                          },
                          onDismissed: (_) async {
                            await addressProvider.deleteAddress(address.id);
                            if (_currentAddress?.id == address.id) {
                              final newDefault = addressProvider.defaultAddress ?? addressProvider.savedAddresses.firstOrNull;
                              setState(() => _currentAddress = newDefault);
                              if (newDefault != null) _loadVendorsForAddress(newDefault);
                            }
                            setSheetState(() {});
                          },
                          child: ListTile(
                            leading: Icon(
                              address.isDefault ? Icons.home_rounded : Icons.location_on_rounded,
                              color: isSelected ? Colors.green : subtextColor,
                            ),
                            title: Text(
                              address.shortAddress,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              address.fullAddress,
                              style: TextStyle(color: subtextColor, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, size: 20, color: subtextColor),
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      Navigator.pop(sheetContext);
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LocationPickerScreen(initialAddress: address),
                                        ),
                                      );
                                      if (result != null && result is DeliveryAddress) {
                                        if (!_isLocationOutOfKigali(result.latitude, result.longitude)) {
                                          await addressProvider.updateAddress(result.copyWith(id: address.id));
                                          setState(() => _currentAddress = result.copyWith(id: address.id));
                                          await _loadVendorsForAddress(result);
                                        }
                                      }
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: sheetContext,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Address'),
                                          content: Text('Delete "${address.shortAddress}"?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await addressProvider.deleteAddress(address.id);
                                        if (_currentAddress?.id == address.id) {
                                          final newDefault = addressProvider.defaultAddress ?? addressProvider.savedAddresses.firstOrNull;
                                          setState(() => _currentAddress = newDefault);
                                          if (newDefault != null) _loadVendorsForAddress(newDefault);
                                        }
                                        setSheetState(() {});
                                      }
                                    } else if (value == 'default') {
                                      await addressProvider.setDefaultAddress(address.id);
                                      setSheetState(() {});
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                                    if (!address.isDefault)
                                      const PopupMenuItem(value: 'default', child: Row(children: [Icon(Icons.home_rounded, size: 18), SizedBox(width: 8), Text('Set as default')])),
                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              
                              if (_isLocationOutOfKigali(address.latitude, address.longitude)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('This address is outside Kigali. Please select a location within Kigali.'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 5),
                                  ),
                                );
                                return;
                              }
                              
                              setState(() => _currentAddress = address);
                              await _loadVendorsForAddress(address);
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
              
              // Add New Address Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
                      );
                      
                      if (result != null && result is DeliveryAddress) {
                        if (_isLocationOutOfKigali(result.latitude, result.longitude)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sorry, we only serve within Kigali. Please select a location within Kigali.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 5),
                            ),
                          );
                          return;
                        }
                        
                        setState(() => _currentAddress = result);
                        await _loadVendorsForAddress(result);
                      }
                    },
                    icon: const Icon(Icons.add_location_alt, size: 22),
                    label: const Text('Add New Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
  Widget _buildBottomNav(bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(Icons.home_rounded, Icons.home_rounded, 'Home', 0, textColor, subtextColor, isDarkMode)),
              Expanded(child: _buildNavItem(Icons.restaurant_rounded, Icons.restaurant_rounded, 'Restaurants', 1, textColor, subtextColor, isDarkMode)),
              Expanded(child: _buildNavItem(Icons.shopping_bag_rounded, Icons.shopping_bag_rounded, 'Markets', 2, textColor, subtextColor, isDarkMode)),
              Expanded(child: _buildNavItem(Icons.shopping_cart, Icons.shopping_cart, 'Cart', 3, textColor, subtextColor, isDarkMode)),
              Expanded(child: _buildNavItem(Icons.account_circle_outlined, Icons.account_circle_rounded, 'Profile', 4, textColor, subtextColor, isDarkMode)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData outlinedIcon, IconData filledIcon, String label, int index, Color textColor, Color subtextColor, bool isDarkMode) {
    final isSelected = _selectedNavIndex == index;
    final selectedTextColor = isDarkMode ? Colors.black : Colors.black;
    return InkWell(
      onTap: () => _onNavItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isSelected ? filledIcon : outlinedIcon, color: isSelected ? selectedTextColor : subtextColor, size: 24),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? selectedTextColor : subtextColor)),
        ]),
      ),
    );
  }

  Widget _buildCategoryChip(String category, bool isDarkMode, Color chipColor, Color selectedColor, Color textColor) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => _handleCategoryTap(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : chipColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? Colors.black : (isDarkMode ? Colors.grey[800]! : Colors.grey[300]!), width: 1),
        ),
        child: Text(category, style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    );
  }

  Widget _buildPromotionCircle(SpecialOffer promo, bool isDarkMode, Color cardColor, Color textColor) {
    return _buildOfferBannerCard(promo, isDarkMode, textColor);
  }

  /// Handle offer tap - navigate based on link_type
  void _handleOfferTap(SpecialOffer offer) {
    switch (offer.linkType) {
      case 'vendor':
        if (offer.linkValue != null && offer.linkValue!.isNotEmpty) {
          final vendorProvider = context.read<VendorProvider>();
          try {
            final vendor = vendorProvider.vendors.firstWhere((v) => v.id == offer.linkValue);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => VendorDetailScreen(vendor: vendor),
            ));
          } catch (_) {
            // Vendor not found in list — try by vendorId field
            if (offer.vendorId != null) {
              try {
                final vendor = vendorProvider.vendors.firstWhere((v) => v.id == offer.vendorId.toString());
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => VendorDetailScreen(vendor: vendor),
                ));
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vendor not available'), backgroundColor: Colors.orange),
                );
              }
            }
          }
        }
        break;
      case 'category':
        if (offer.linkValue != null) {
          setState(() {
            _selectedCategory = offer.linkValue!;
          });
        }
        break;
      case 'external':
        if (offer.linkValue != null && offer.linkValue!.isNotEmpty) {
          launchUrl(Uri.parse(offer.linkValue!), mode: LaunchMode.externalApplication);
        }
        break;
      case 'product':
        // Could navigate to product detail
        break;
      default:
        // 'none' — show promo code if available
        final promoCode = offer.promoCode?.trim() ?? '';
        if (promoCode.isNotEmpty && promoCode.toLowerCase() != 'none' && promoCode.toLowerCase() != 'null') {
          final badgeText = offer.discountText.trim();
          final hasBadgeText = badgeText.isNotEmpty && badgeText.toLowerCase() != 'none';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.local_offer, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasBadgeText
                          ? 'Use code $promoCode at checkout for $badgeText!'
                          : 'Use code $promoCode at checkout.',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        break;
    }
  }

  /// Sponsored banner card for featured ads
  Widget _buildOfferBannerCard(SpecialOffer offer, bool isDarkMode, Color textColor) {
    return _OfferAdCard(
      offer: offer,
      isDarkMode: isDarkMode,
      textColor: textColor,
      onTap: () => _handleOfferTap(offer),
    );
  }

  void _showAllVendorsSheet(BuildContext context, List<Vendor> vendors, bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
    final bg = isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF5F6F8);
    final card = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final border = isDarkMode ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final pText = isDarkMode ? Colors.white : const Color(0xFF111111);
    final sText = isDarkMode ? Colors.white54 : const Color(0xFF6B7280);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: bg,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 140,
                pinned: true,
                backgroundColor: isDarkMode ? const Color(0xFF0D1117) : const Color(0xFF0B0F14),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: isDarkMode
                            ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                            : [const Color(0xFF0B0F14), const Color(0xFF1B2028)],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.store_rounded, color: Color(0xFF4CAF50), size: 26),
                            const SizedBox(width: 10),
                            const Text('All Vendors', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            '${vendors.length} ${vendors.length == 1 ? 'vendor' : 'vendors'} available',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              if (vendors.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4CAF50).withOpacity(0.1)),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF4CAF50), size: 30),
                      ),
                      const SizedBox(height: 14),
                      Text('No vendors found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: pText)),
                      const SizedBox(height: 6),
                      Text('Try changing your location or category.', style: TextStyle(fontSize: 13, color: sText)),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final v = vendors[i];
                        final isRestaurant = v.isRestaurant;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: v)));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                // Vendor image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: v.logoUrl != null && v.logoUrl!.isNotEmpty
                                      ? Image.network(v.logoUrl!, width: 72, height: 72, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 72, height: 72,
                                            color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                                            child: Icon(isRestaurant ? Icons.restaurant_rounded : Icons.storefront_rounded, color: Colors.grey[400], size: 28),
                                          ))
                                      : Container(
                                          width: 72, height: 72,
                                          decoration: BoxDecoration(
                                            color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(isRestaurant ? Icons.restaurant_rounded : Icons.storefront_rounded, color: Colors.grey[400], size: 28),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Vendor info
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(v.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pText), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    // Rating, time, distance
                                    Row(children: [
                                      Icon(Icons.star_rounded, size: 14, color: const Color(0xFFFFA000)),
                                      const SizedBox(width: 3),
                                      Text(v.totalRatings == 0 ? 'New' : v.formattedRating, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sText)),
                                      const SizedBox(width: 12),
                                      Icon(Icons.schedule, size: 13, color: sText),
                                      const SizedBox(width: 3),
                                      Text(v.formattedDeliveryTime, style: TextStyle(fontSize: 12, color: sText)),
                                      if (v.formattedDistance != 'D/U') ...[
                                        const SizedBox(width: 12),
                                        Icon(Icons.near_me, size: 13, color: sText),
                                        const SizedBox(width: 3),
                                        Text(v.formattedDistance, style: TextStyle(fontSize: 12, color: sText)),
                                      ],
                                    ]),
                                    const SizedBox(height: 6),
                                    // Status badges
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: v.isOpen ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.red.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(v.isOpen ? 'Open' : 'Closed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: v.isOpen ? const Color(0xFF4CAF50) : Colors.red[400])),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(v.formattedDeliveryFee, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(isRestaurant ? 'Restaurant' : v.category, style: TextStyle(fontSize: 11, color: sText)),
                                    ]),
                                  ]),
                                ),
                                // Arrow
                                Icon(Icons.chevron_right_rounded, color: sText, size: 22),
                              ]),
                            ),
                          ),
                        );
                      },
                      childCount: vendors.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageDeliveryBanner() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    return GestureDetector(
      onTap: () {
        if (!authProvider.isAuthenticated) {
          _showLoginPrompt(context, 'Please login to create a pickup order');
          return;
        }
        context.push('/create-pickup-order');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.black, Colors.grey[900]!], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: 1)],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15), border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5)),
            child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Send a Package', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('Fast pickup & delivery', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: const Text('Ntwaza Now →', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  // 🚚 Ntwaza Now - Pickup Orders Button
  Widget _buildNtwazaNowButton(BuildContext context, bool isDarkMode, Color cardColor, Color textColor) {
    final authProvider = context.watch<AuthProvider>();
    
    return GestureDetector(
      onTap: () {
        if (!authProvider.isAuthenticated) {
          _showLoginPrompt(context, 'Please login to create a pickup order');
          return;
        }
        context.push('/create-pickup-order');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orangeAccent, Colors.deepOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.deepOrange.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ntwaza Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Send packages anywhere fast',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Start Order →',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final isPng = bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
    final isJpeg = bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final isGif = bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x39 || bytes[4] == 0x37) &&
        bytes[5] == 0x61;
    final isWebp = bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return isPng || isJpeg || isGif || isWebp;
  }

  List<String> _vendorImageCandidates(String imageUrl) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return [];

    final candidates = <String>{trimmed};
    final uri = Uri.tryParse(trimmed);
    final path = uri?.path ?? trimmed;
    final filename = path.split('/').last;

    if (filename.isNotEmpty) {
      // Try both static folder locations
      candidates.add('${ApiService.baseUrl}/static/uploads/vendors/$filename');
      candidates.add('${ApiService.baseUrl}/uploads/vendors/$filename');
      candidates.add('${ApiService.baseUrl}/static/uploads/$filename');
      candidates.add('${ApiService.baseUrl}/uploads/$filename');
    }

    return candidates.toList();
  }

  Future<Uint8List?> _fetchVendorImageBytes(
    String imageUrl,
    Map<String, String>? headers,
  ) async {
    final candidates = _vendorImageCandidates(imageUrl);
    for (final url in candidates) {
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final bytes = response.bodyBytes;
          final contentType = response.headers['content-type'] ?? '';
          final looksLikeImage = _looksLikeImage(bytes);
          if (!contentType.startsWith('image/') && !looksLikeImage) {
            print('❌ Vendor image is not an image ($contentType): $url');
            continue;
          }
          if (!looksLikeImage) {
            print('❌ Vendor image has invalid bytes: $url');
            continue;
          }
          return bytes;
        }
        print('❌ Vendor image load failed (${response.statusCode}): $url');
      } catch (e) {
        print('❌ Vendor image load error: $url ($e)');
      }
    }
    return null;
  }

  Widget _buildVendorImagePlaceholder(
    IconData businessIcon,
    bool isDarkMode, {
    double? width,
    double? height,
    bool showText = true,
  }) {
    return Container(
      width: width,
      height: height,
      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            businessIcon,
            size: showText ? 60 : 28,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          if (showText) ...[
            const SizedBox(height: 8),
            Text(
              'No image',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorImage(
    String imageUrl, {
    required bool isDarkMode,
    required IconData businessIcon,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    bool showText = true,
  }) {
    if (imageUrl.trim().isEmpty) {
      return _buildVendorImagePlaceholder(
        businessIcon,
        isDarkMode,
        width: width,
        height: height,
        showText: showText,
      );
    }

    final token = context.read<AuthProvider>().token;
    final uri = Uri.tryParse(imageUrl);
    final apiUri = Uri.tryParse(ApiService.baseUrl);
    final isSameOrigin = uri != null &&
        apiUri != null &&
        uri.scheme == apiUri.scheme &&
        uri.host == apiUri.host &&
        uri.port == apiUri.port;
    
    // Don't use auth for static uploads even on same origin
    final isStaticUpload = imageUrl.contains('/static/uploads/');
    final shouldUseAuth = isSameOrigin && !isStaticUpload && token != null && token.isNotEmpty;
    final headers = shouldUseAuth ? {'Authorization': 'Bearer $token'} : null;

    if (kIsWeb && (headers == null || !isSameOrigin)) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildVendorImagePlaceholder(
            businessIcon,
            isDarkMode,
            width: width,
            height: height,
            showText: showText,
          );
        },
      );
    }

    final candidates = _vendorImageCandidates(imageUrl);
    final cacheKey = '${headers?['Authorization'] ?? 'anon'}|${candidates.join('|')}';
    final future = _vendorImageFutureCache.putIfAbsent(
      cacheKey,
      () => _fetchVendorImageBytes(imageUrl, headers),
    );

    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: width,
            height: height,
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null) {
          return _buildVendorImagePlaceholder(
            businessIcon,
            isDarkMode,
            width: width,
            height: height,
            showText: showText,
          );
        }

        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
        );
      },
    );
  }

  // ==================== VENDOR CARDS ====================

  /// Get today's hours text for a vendor
  String _getTodayHours(Vendor vendor) {
    if (vendor.workingHours == null || vendor.workingHours!.isEmpty) return '';
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final todayKey = days[DateTime.now().weekday - 1];
    final dayData = vendor.workingHours![todayKey];
    if (dayData == null || dayData is! Map) return '';
    final isOpen = dayData['open'] == true;
    final openTime = dayData['open_time'] ?? '';
    final closeTime = dayData['close_time'] ?? '';
    if (openTime.toString().isNotEmpty && closeTime.toString().isNotEmpty) {
      return isOpen ? '$openTime – $closeTime' : '';
    }
    return isOpen ? 'Open' : '';
  }

  Widget _buildVendorCard(Vendor vendor, int index, bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
    final isHovered = _hoveredCardIndex == index;
    final imageUrl = vendor.logoUrl.isNotEmpty 
        ? vendor.logoUrl 
        : (vendor.bannerUrl != null && vendor.bannerUrl!.isNotEmpty 
            ? vendor.bannerUrl! 
            : '');
    
    final businessType = vendor.category.toLowerCase();
    IconData businessIcon = Icons.storefront_rounded;
    String typeLabel = 'Store';
    if (businessType.contains('restaurant')) {
      businessIcon = Icons.restaurant_rounded;
      typeLabel = 'Restaurant';
    } else if (businessType.contains('supermarket') || businessType.contains('market')) {
      businessIcon = Icons.shopping_cart;
      typeLabel = 'Supermarket';
    } else if (businessType.contains('grocery')) {
      businessIcon = Icons.shopping_basket;
      typeLabel = 'Grocery';
    }

    final distanceText = vendor.formattedDistance;
    final deliveryFeeText = vendor.formattedDeliveryFee;
    final deliveryTime = vendor.formattedDeliveryTime;

    final statusColor = vendor.isOpen 
        ? (isDarkMode ? const Color(0xFF81C784) : const Color(0xFF4CAF50))
        : (isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF9E9E9E));
    final borderCol = isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade200;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredCardIndex = index),
      onExit: (_) => setState(() => _hoveredCardIndex = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.06),
                blurRadius: isHovered ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VendorDetailScreen(vendor: vendor))),
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section
                Expanded(
                  flex: 3, 
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                        child: ColorFiltered(
                          colorFilter: vendor.isOpen 
                              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                              : ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                          child: _buildVendorImage(
                            imageUrl.isNotEmpty ? imageUrl : 'https://picsum.photos/seed/vendor$index/400/300',
                            isDarkMode: isDarkMode,
                            businessIcon: businessIcon,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      // Type label
                      Positioned(
                        top: 10, left: 10, 
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(businessIcon, size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(typeLabel, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                          ]),
                        )
                      ),
                      // Status dot
                      Positioned(
                        top: 10, right: 10, 
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              vendor.isOpen ? 'Open' : 'Closed',
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          ]),
                        )
                      ),
                    ],
                  )
                ),
                // Info section — clean & professional
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Vendor name
                      Text(
                        vendor.name, 
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.w700, 
                          color: textColor, 
                          letterSpacing: -0.3,
                        ), 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // --- 2×2 grid layout for vendor info ---
                      Row(children: [
                        // Rating (left)
                        Expanded(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star_rounded, size: 13, color: isDarkMode ? const Color(0xFFFFD54F) : const Color(0xFFFFA000)),
                            const SizedBox(width: 3),
                            (vendor.totalRatings == 0)
                              ? Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDarkMode ? const Color(0xFFFFD54F) : const Color(0xFFFF8F00)))
                              : Text(vendor.formattedRating, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtextColor)),
                          ]),
                        ),
                        // Distance (right)
                        if (distanceText != 'D/U')
                          Expanded(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.near_me, size: 12, color: subtextColor),
                              const SizedBox(width: 3),
                              Flexible(child: Text(distanceText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor), overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                      ]),
                      const SizedBox(height: 5),
                      Row(children: [
                        // Delivery time (left)
                        Expanded(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.schedule, size: 12, color: subtextColor),
                            const SizedBox(width: 3),
                            Flexible(child: Text(deliveryTime, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor), overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                        // Delivery fee (right)
                        Expanded(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDarkMode ? const Color(0xFF1B5E20) : const Color(0xFF4CAF50)).withOpacity(isDarkMode ? 0.15 : 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                deliveryFeeText, 
                                style: TextStyle(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.w600, 
                                  color: isDarkMode ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                            if (!vendor.isDeliverable) ...[
                              const SizedBox(width: 4),
                              Text('Too far', style: TextStyle(fontSize: 9, color: subtextColor, fontWeight: FontWeight.w500)),
                            ],
                          ]),
                        ),
                      ]),
                    ],
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(Vendor vendor, bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
    // Use logoUrl first, then bannerUrl as fallback, then placeholder
    final imageUrl = vendor.logoUrl.isNotEmpty 
        ? vendor.logoUrl 
        : (vendor.bannerUrl != null && vendor.bannerUrl!.isNotEmpty 
            ? vendor.bannerUrl! 
            : 'https://picsum.photos/seed/vendor${vendor.id}/200/200');
    final deliveryTime = vendor.formattedDeliveryTime;
    final distanceText = vendor.formattedDistance;
    final borderCol = isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade200;
    final statusColor = vendor.isOpen
        ? (isDarkMode ? const Color(0xFF81C784) : const Color(0xFF4CAF50))
        : (isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF9E9E9E));
    
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VendorDetailScreen(vendor: vendor))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white, 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol, width: 0.5),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8), 
            child: _buildVendorImage(
              imageUrl,
              isDarkMode: isDarkMode,
              businessIcon: Icons.storefront_rounded,
              width: 56,
              height: 56,
              showText: false,
            )
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(vendor.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor, letterSpacing: -0.2), maxLines: 1),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.star_rounded, size: 12, color: isDarkMode ? const Color(0xFFFFD54F) : Colors.amber.shade700),
                const SizedBox(width: 3),
                (vendor.totalRatings == 0)
                  ? Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor))
                  : Text(vendor.formattedRating, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor)),
                Text('  ·  ', style: TextStyle(color: subtextColor.withOpacity(0.5), fontSize: 11)),
                Icon(Icons.schedule, size: 12, color: subtextColor),
                const SizedBox(width: 3),
                Text(deliveryTime, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.near_me, size: 11, color: subtextColor),
                const SizedBox(width: 3),
                Text(distanceText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor)),
              ]),
            ])
          ),
          const SizedBox(width: 8),
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 18, color: subtextColor.withOpacity(0.5)),
        ]),
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isDarkMode, Color cardColor, Color textColor, [Color? subtextColor]) {
    final price = product.price;
    final priceText = 'Rwf $price';
    // Fix image URL - ensure it has proper base URL
    String imageUrl = product.imageUrl;
    if (imageUrl.isEmpty) {
      imageUrl = 'https://picsum.photos/seed/${product.id}/200/200';
    } else if (!imageUrl.startsWith('http')) {
      // Add base URL for relative paths
      final baseUrl = ApiService.baseUrl;
      imageUrl = imageUrl.startsWith('/') ? '$baseUrl$imageUrl' : '$baseUrl/$imageUrl';
    }
    final vendorName = product.vendorName?.isNotEmpty == true ? product.vendorName! : null;
    final finalSubtextColor = subtextColor ?? Colors.grey[600]!;
    
    print('🔗 Loading search product image: $imageUrl');
    
    // Check if vendor is open
    final vendorProvider = context.read<VendorProvider>();
    final vendor = vendorProvider.vendors.firstWhere(
      (v) => v.id == product.vendorId,
      orElse: () => Vendor(
        id: product.vendorId,
        name: product.vendorName ?? 'Unknown Vendor',
        category: '',
        logoUrl: '',
        rating: 0,
        totalRatings: 0,
        latitude: 0,
        longitude: 0,
        prepTimeMinutes: 0,
        deliveryFee: 0,
        isOpen: false,
      ),
    );
    
    final isVendorClosed = !vendor.isOpen;
    
    return GestureDetector(
      onTap: () async {
            Vendor? vendorForNav;
            try {
              vendorForNav = vendorProvider.vendors.firstWhere(
                (v) => v.id == product.vendorId,
              );
            } catch (e) {
              vendorForNav = Vendor(
                id: product.vendorId,
                name: product.vendorName ?? 'Unknown Vendor',
                category: '',
                logoUrl: '',
                rating: 0,
                totalRatings: 0,
                latitude: 0,
                longitude: 0,
                prepTimeMinutes: 0,
                deliveryFee: 0,
                isOpen: vendor.isOpen,
              );
            }
            await showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => ProductDetailModal(product: product, vendor: vendorForNav!),
            );
          },
      child: Opacity(
        opacity: isVendorClosed ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor, 
            borderRadius: BorderRadius.circular(12),
            border: isVendorClosed ? Border.all(color: Colors.grey[400]!, width: 1) : null,
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 80,
                          height: 80,
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ Search product image error: $error for ${imageUrl}');
                        return Container(
                          width: 80,
                          height: 80,
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          child: Icon(Icons.inventory_2, color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                        );
                      },
                    ),
                  ),
                  if (isVendorClosed)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black.withOpacity(0.4),
                        ),
                        child: Center(
                          child: Text(
                            'CLOSED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              backgroundColor: Colors.red.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isVendorClosed ? Colors.grey : textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (vendorName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        vendorName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: finalSubtextColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      priceText,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isVendorClosed ? Colors.grey : Colors.green[700]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: isVendorClosed ? Colors.grey : finalSubtextColor),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SEARCH COMPONENTS ====================

  Widget _buildSearchFilterChip(String label, SearchFilter filter, SearchProvider provider, int count) {
    final isSelected = provider.filter == filter;
    return GestureDetector(
      onTap: () => provider.setFilter(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.black : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(count.toString(), style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(SearchProvider searchProvider, bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
    if (searchProvider.isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.black));
    }

    if (searchProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(searchProvider.error!, style: TextStyle(color: textColor)),
          ],
        ),
      );
    }

    if (!searchProvider.hasResults) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Show search history suggestions
          if (searchProvider.searchHistory.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Searches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                GestureDetector(
                  onTap: () => searchProvider.clearHistory(),
                  child: Text('Clear all', style: TextStyle(fontSize: 12, color: subtextColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...searchProvider.searchHistory.map((q) => ListTile(
              dense: true,
              leading: Icon(Icons.history_rounded, size: 18, color: subtextColor),
              title: Text(q, style: TextStyle(color: textColor, fontSize: 14)),
              trailing: GestureDetector(
                onTap: () => searchProvider.removeHistoryItem(q),
                child: Icon(Icons.close, size: 16, color: subtextColor),
              ),
              onTap: () {
                _searchController.text = q;
                searchProvider.unifiedSearch(q);
              },
              contentPadding: EdgeInsets.zero,
            )),
            const SizedBox(height: 16),
          ],
          Center(
            child: Column(
              children: [
                Icon(Icons.search_off, size: 64, color: subtextColor),
                const SizedBox(height: 16),
                Text('No results for "${searchProvider.searchQuery}"', style: TextStyle(color: textColor, fontSize: 16)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _buildSearchFilterChip('All', SearchFilter.all, searchProvider, searchProvider.totalResults),
            const SizedBox(width: 8),
            _buildSearchFilterChip('Vendors', SearchFilter.vendors, searchProvider, searchProvider.vendors.length),
            const SizedBox(width: 8),
            _buildSearchFilterChip('Products', SearchFilter.products, searchProvider, searchProvider.products.length),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('${searchProvider.totalResults} results for "${searchProvider.searchQuery}"', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: subtextColor)),
        ),
        const SizedBox(height: 16),
        if (searchProvider.filteredVendors.isNotEmpty) ...[
          Text('Vendors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 12),
          ...searchProvider.filteredVendors.map((vendor) => _buildSearchResultCard(vendor, isDarkMode, cardColor, textColor, subtextColor)),
          const SizedBox(height: 24),
        ],
        if (searchProvider.filteredProducts.isNotEmpty) ...[
          Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 12),
          ...searchProvider.filteredProducts.map((product) => _buildProductCard(product, isDarkMode, cardColor, textColor, subtextColor)),
        ],
      ],
    );
  }

  // ==================== SCREENS ====================

Widget _buildLocationSelectionOverlay(bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
  final addressProvider = context.read<AddressProvider>();
  final savedAddresses = addressProvider.savedAddresses;
  
  return Container(
    color: Colors.black.withOpacity(0.5),
    child: Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, size: 28, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                'Choose Delivery Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Select a saved address or use your current location.',
                style: TextStyle(fontSize: 13, color: subtextColor, height: 1.4),
                textAlign: TextAlign.center,
              ),
              
              // Saved Addresses Section
              if (savedAddresses.isNotEmpty) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Saved Addresses',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subtextColor),
                  ),
                ),
                const SizedBox(height: 10),
                ...savedAddresses.take(3).map((address) => _buildSavedAddressTile(address, isDarkMode, textColor, subtextColor)),
              ],
              
              const SizedBox(height: 20),
              
              // Use Current Location
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _handleSetLocation(),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Use Current Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              
              // Search Location
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _handleSearchLocation(),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search Location in Kigali', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              
              // Service note
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 14, color: subtextColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Service Area: Kigali only (within 25km radius)',
                      style: TextStyle(fontSize: 11, color: subtextColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Saved address tile for location overlay
Widget _buildSavedAddressTile(DeliveryAddress address, bool isDarkMode, Color textColor, Color subtextColor) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: isDarkMode ? const Color(0xFF252525) : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () async {
          setState(() => _currentAddress = address);
          await _loadVendorsForAddress(address);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  address.label == 'Home' ? Icons.home_rounded : 
                  address.label == 'Work' ? Icons.work_rounded : Icons.place_rounded,
                  color: const Color(0xFF2E7D32),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.label ?? 'Saved Location',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.fullAddress,
                      style: TextStyle(fontSize: 12, color: subtextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: subtextColor, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

// Handle location permission and selection - improved auto-detect
Future<void> _handleSetLocation() async {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Color(0xFF2E7D32),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Detecting your location',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please wait...',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) Navigator.pop(context); // Close loading
      if (mounted) {
        _showLocationPermissionDeniedDialog();
      }
      return;
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: false,
      ).timeout(const Duration(seconds: 15));

      if (mounted) Navigator.pop(context); // Close loading

      if (_isLocationOutOfKigali(position.latitude, position.longitude)) {
        if (mounted) {
          _showLocationError('Your location is outside Kigali. Please search for an address within our service area.');
        }
        return;
      }

      // Go to location picker with current position
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialAddress: DeliveryAddress(
              id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
              label: 'Current Location',
              fullAddress: 'Loading address...',
              latitude: position.latitude,
              longitude: position.longitude,
              createdAt: DateTime.now(),
            ),
          ),
        ),
      );

      if (result != null && result is DeliveryAddress) {
        if (_isLocationOutOfKigali(result.latitude, result.longitude)) {
          if (mounted) {
            _showLocationError('This location is outside Kigali service area.');
          }
          return;
        }
        setState(() => _currentAddress = result);
        await _loadVendorsForAddress(result);
      }
    } else {
      if (mounted) Navigator.pop(context); // Close loading
      await Geolocator.openAppSettings();
    }
  } catch (e) {
    if (mounted) Navigator.pop(context); // Close loading
    print('Error getting location: $e');
    if (mounted) {
      _showLocationError('Unable to get location. Please try again or search manually.');
    }
  }
}

// Show permission denied dialog
void _showLocationPermissionDeniedDialog() {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off, color: Colors.red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Location Permission Required',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'Please enable location access in your device settings to use this feature, or search for a location manually.',
        style: TextStyle(
          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          fontSize: 14,
          height: 1.4,
        ),
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
            Navigator.pop(context);
            Geolocator.openAppSettings();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
}

// Handle search location
Future<void> _handleSearchLocation() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
  );

  if (result != null && result is DeliveryAddress) {
    if (_isLocationOutOfKigali(result.latitude, result.longitude)) {
      if (mounted) {
        _showLocationError('This location is outside Kigali service area.');
      }
      return;
    }
    setState(() => _currentAddress = result);
    await _loadVendorsForAddress(result);
  }
}

// Show location error snackbar
void _showLocationError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: const Color(0xFFD32F2F),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ),
  );
}
// Minimal no-vendors overlay — clean & professional
Widget _buildNoVendorsOverlay(bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
  String label;
  IconData icon;

  if (_selectedCategory == 'All' || _selectedCategory.isEmpty) {
    label = 'No vendors in this area';
    icon = Icons.storefront;
  } else if (_selectedCategory == 'Others') {
    label = 'Coming soon';
    icon = Icons.schedule;
  } else {
    label = 'No ${_selectedCategory.toLowerCase()} available';
    icon = Icons.storefront;
  }

  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          // Location action for 'All'
          if (_selectedCategory == 'All' || _selectedCategory.isEmpty) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
                );
                if (result != null && result is DeliveryAddress) {
                  if (_isLocationOutOfKigali(result.latitude, result.longitude)) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('We only serve within Kigali'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                    return;
                  }
                  setState(() => _currentAddress = result);
                  await _loadVendorsForAddress(result);
                }
              },
              child: Text(
                'Change location',
                style: TextStyle(
                  color: const Color(0xFF2E7D32),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _handleCategoryTap('All'),
              child: Text(
                'View all',
                style: TextStyle(
                  color: const Color(0xFF2E7D32),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
 Widget _buildNormalVendorList(BuildContext context, VendorProvider vendorProvider, SpecialOfferProvider specialOfferProvider, 
    bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
  // Sort vendors: open shops first, then by rating
  final displayVendors = List<Vendor>.from(vendorProvider.vendors)
    ..sort((a, b) {
      // Open shops first
      if (a.isOpen != b.isOpen) {
        return (b.isOpen ? 1 : 0) - (a.isOpen ? 1 : 0);
      }
      // Then by rating (highest first)
      return b.rating.compareTo(a.rating);
    });
  final specialOffers = specialOfferProvider.validHomepageOffers;

  if (vendorProvider.isLoading) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: subtextColor,
        ),
      ),
    );
  }

  // DON'T call _buildNoVendorsScreen here - let the main build handle it
  // This breaks the recursion

  return RefreshIndicator(
    onRefresh: () async {
      if (_currentAddress != null) {
        // Force refresh when user pulls to refresh
        await _loadVendorsForAddress(_currentAddress!, forceRefresh: true);
      }
    },
    color: Colors.black,
    child: ListView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 4),
        _buildPackageDeliveryBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(children: [
            Expanded(child: Text('Browse Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor))),
            GestureDetector(
              onTap: () => _showAllVendorsSheet(context, displayVendors, isDarkMode, cardColor, textColor, subtextColor),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.menu_rounded, size: 18, color: textColor),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _categories.map((category) => _buildCategoryChip(category, isDarkMode, cardColor, Colors.black, textColor)).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCategory == 'All' ? 'Featured Vendors' : _selectedCategory,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
              ),
              Text('(${displayVendors.length} found)', style: TextStyle(fontSize: 13, color: subtextColor)),
            ],
          ),
        ),
        if (displayVendors.isNotEmpty) ...[
          // First 2 vendors (row of 2) — use LayoutBuilder to match GridView aspect ratio
          if (displayVendors.length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  final cardHeight = cardWidth / 0.78;
                  return SizedBox(
                    height: cardHeight,
                    child: Row(
                      children: [
                        Expanded(child: _buildVendorCard(displayVendors[0], 0, isDarkMode, cardColor, textColor, subtextColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildVendorCard(displayVendors[1], 1, isDarkMode, cardColor, textColor, subtextColor)),
                      ],
                    ),
                  );
                },
              ),
            )
          else if (displayVendors.length == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  final cardHeight = cardWidth / 0.78;
                  return SizedBox(
                    height: cardHeight,
                    child: Row(
                      children: [
                        Expanded(child: _buildVendorCard(displayVendors[0], 0, isDarkMode, cardColor, textColor, subtextColor)),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  );
                },
              ),
            ),
          // Sponsored / Featured ads - horizontal carousel
          if (specialOffers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FeaturedOffersCarousel(
              offers: specialOffers,
              isDarkMode: isDarkMode,
              textColor: textColor,
              onOfferTap: _handleOfferTap,
            ),
            const SizedBox(height: 8),
          ],
          // Remaining vendors (from index 2 onwards)
          if (displayVendors.length > 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: displayVendors.length - 2,
                itemBuilder: (context, index) {
                  final Vendor vendor = displayVendors[index + 2];
                  return _buildVendorCard(vendor, index + 2, isDarkMode, cardColor, textColor, subtextColor);
                },
              ),
            ),
        ],
        const SizedBox(height: 80),
      ],
    ),
  );
}

// REPLACE the entire build method:
@override
Widget build(BuildContext context) {
  final themeProvider = context.watch<ThemeProvider>();
  final authProvider = context.watch<AuthProvider>();
  final vendorProvider = context.watch<VendorProvider>();
  final searchProvider = context.watch<SearchProvider>();
  final specialOfferProvider = context.watch<SpecialOfferProvider>();

  final isDarkMode = themeProvider.isDarkMode;
  final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
  final cardColor = isDarkMode ? const Color(0xFF121212) : Colors.white;  // Same as background for invisible cards
  final textColor = isDarkMode ? Colors.white : Colors.black;
  final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

  final isSearching = searchProvider.searchQuery.isNotEmpty;

  if (_isInitializing) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: subtextColor,
          ),
        ),
      ),
    );
  }

  // Build the main content
  Widget mainContent;
  
  if (_currentAddress == null) {
    // Show location selection WITH app chrome
    mainContent = _buildLocationSelectionOverlay(isDarkMode, cardColor, textColor, subtextColor);
  } else if (vendorProvider.vendors.isEmpty && !vendorProvider.isLoading && !isSearching && vendorProvider.error == null) {
    // Show no vendors only when there's no error (not a temporary failure)
    mainContent = _buildNoVendorsOverlay(isDarkMode, cardColor, textColor, subtextColor);
  } else {
    // Normal content
    mainContent = isSearching
        ? _buildSearchResults(searchProvider, isDarkMode, cardColor, textColor, subtextColor)
        : _buildNormalVendorList(context, vendorProvider, specialOfferProvider, isDarkMode, cardColor, textColor, subtextColor);
  }

  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: isDarkMode 
      ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
      : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    child: Scaffold(
    backgroundColor: backgroundColor,
    body: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchHeader(context, isDarkMode, cardColor, textColor, subtextColor, vendorProvider, authProvider, themeProvider),
            Expanded(child: mainContent),
          ],
        ),
        // Draggable AI Assistant
        const DraggableAiAssistant(),
      ],
    ),
    bottomNavigationBar: _buildBottomNav(isDarkMode, cardColor, textColor, subtextColor),
  ));
}}


/// Horizontally-scrolling, auto-sliding carousel for featured offers
class _FeaturedOffersCarousel extends StatefulWidget {
  final List<SpecialOffer> offers;
  final bool isDarkMode;
  final Color textColor;
  final void Function(SpecialOffer) onOfferTap;

  const _FeaturedOffersCarousel({
    required this.offers,
    required this.isDarkMode,
    required this.textColor,
    required this.onOfferTap,
  });

  @override
  State<_FeaturedOffersCarousel> createState() => _FeaturedOffersCarouselState();
}

class _FeaturedOffersCarouselState extends State<_FeaturedOffersCarousel> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    if (widget.offers.length < 2) return;
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.offers.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.offers.length,
            padEnds: true,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return AnimatedScale(
                scale: index == _currentPage ? 1.0 : 0.92,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: index == _currentPage ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: _OfferAdCard(
                    offer: widget.offers[index],
                    isDarkMode: widget.isDarkMode,
                    textColor: widget.textColor,
                    onTap: () => widget.onOfferTap(widget.offers[index]),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.offers.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.offers.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF10B981)
                      : (widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}


class _OfferAdCard extends StatefulWidget {
  final SpecialOffer offer;
  final bool isDarkMode;
  final Color textColor;
  final VoidCallback? onTap;

  const _OfferAdCard({
    required this.offer,
    required this.isDarkMode,
    required this.textColor,
    this.onTap,
  });

  @override
  State<_OfferAdCard> createState() => _OfferAdCardState();
}

class _OfferAdCardState extends State<_OfferAdCard> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant _OfferAdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCount = oldWidget.offer.imageUrls.length + (oldWidget.offer.imageUrl != null ? 1 : 0);
    final newCount = widget.offer.imageUrls.length + (widget.offer.imageUrl != null ? 1 : 0);
    if (oldCount != newCount) {
      _currentIndex = 0;
      _startAutoSlide();
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  bool _hasText(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    return lower != 'none' && lower != 'null';
  }

  List<String> _resolveImageUrls() {
    final urls = widget.offer.imageUrls.isNotEmpty
        ? widget.offer.imageUrls
        : (_hasText(widget.offer.imageUrl) ? [widget.offer.imageUrl!.trim()] : []);

    return urls.map<String>((url) {
      if (url.startsWith('http')) return url;
      return '${ApiService.baseUrl}/static/uploads/offers/$url';
    }).toList();
  }

  void _startAutoSlide() {
    final images = _resolveImageUrls();
    if (images.length < 2) return;

    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentIndex + 1) % images.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final images = _resolveImageUrls();
    final hasImages = images.isNotEmpty;
    final badgeText = _hasText(widget.offer.discountText) ? widget.offer.discountText : null;
    final title = _hasText(widget.offer.bannerTitle)
        ? widget.offer.bannerTitle!
        : (_hasText(widget.offer.name) ? widget.offer.name : 'Special Offer');
    final subtitle = _hasText(widget.offer.bannerSubtitle)
        ? widget.offer.bannerSubtitle!
        : (_hasText(widget.offer.description) ? widget.offer.description! : null);
    
    // Check if promo code is valid (not null/None/empty)
    final hasValidPromo = _hasText(widget.offer.promoCode) && 
                          widget.offer.promoCode!.toLowerCase() != 'none' && 
                          widget.offer.promoCode!.toLowerCase() != 'null';
    final badgeLabel = hasValidPromo ? 'Sponsored' : 'Ad';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        height: 150,
        decoration: BoxDecoration(
          color: widget.offer.bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isDarkMode ? 0.35 : 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              if (hasImages)
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    return Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(color: widget.offer.bgColor);
                      },
                      errorBuilder: (_, __, ___) => Container(color: widget.offer.bgColor),
                    );
                  },
                )
              else
                Container(color: widget.offer.bgColor),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (badgeText != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.offer.linkType != 'none')
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                  ),
                ),
              if (images.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (index) {
                      final isActive = index == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 14 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}