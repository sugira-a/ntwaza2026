import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/special_offer_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/address_provider.dart';
import '../../models/vendor.dart';
import '../../models/special_offer.dart';
import '../../models/product.dart';
import '../../models/delivery_address.dart';
import '../../screens/vendor/vendor_detail_screen.dart';
import '../../screens/map/location_picker_screen.dart';
import '../../screens/vendor/widgets/product_detail_modal.dart';
import '../../services/api/api_service.dart';

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
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    setState(() => _isInitializing = true);

    try {
      final addressProvider = context.read<AddressProvider>();
      await addressProvider.initialize();
      
      final defaultAddress = addressProvider.defaultAddress ?? addressProvider.savedAddresses.firstOrNull;
      
      if (defaultAddress != null) {
        setState(() => _currentAddress = defaultAddress);
        await _loadVendorsForAddress(defaultAddress);
      }
      
      setState(() => _isInitializing = false);
    } catch (e) {
      print('Error initializing app: $e');
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _loadVendorsForAddress(DeliveryAddress address) async {
    try {
      final vendorProvider = context.read<VendorProvider>();
      
      // Set the delivery address in vendor provider
      vendorProvider.setDeliveryAddress(address);
      
      // Check if location is within Kigali
      if (_isLocationOutOfKigali(address.latitude, address.longitude)) {
        // Don't load vendors if out of service area
        return;
      }
      
      await vendorProvider.fetchVendors();
      await _fetchRealSpecialOffers();
      
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
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isAuthenticated) {
          context.go('/cart');
        } else {
          _showLoginPrompt(context, 'Please login to view your cart');
        }
        break;
      case 4:
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isAuthenticated) {
          context.go('/profile');
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
      if (category == 'All') {
        await vendorProvider.fetchVendors();
      } else {
        await vendorProvider.fetchVendorsByCategory(category);
      }
    } catch (e) {
      print('Error fetching category: $e');
    }
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  // ==================== DIALOGS & MENUS ====================
  
  void _showLoginPrompt(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(context); 
              context.go('/login'); 
            }, 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ), 
            child: const Text('Login')
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
            ListTile(leading: const Icon(Icons.person), title: const Text('User ID'), subtitle: Text(authProvider.user?.id?.toString() ?? 'N/A')),
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
      builder: (context) => Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: cardColor,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
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
            Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 40),
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
    decoration: BoxDecoration(
      color: cardColor, 
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08), blurRadius: 8, offset: const Offset(0, 2))]
    ),
    child: SafeArea(
      bottom: false, 
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NTWAZA', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showAddressManagementDialog(context, isDarkMode, cardColor, textColor, subtextColor),
                        child: Row(
                          children: [
                            Icon(
                              _currentAddress != null ? Icons.location_on : Icons.location_off,
                              size: 14,
                              color: _currentAddress != null ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _currentAddress?.label ?? _currentAddress?.shortAddress ?? 'Choose location',
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
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showSettingsMenu(context, isDarkMode, themeProvider, cardColor, textColor, subtextColor), 
                  icon: Icon(Icons.more_vert, color: textColor, size: 28), 
                  tooltip: 'Menu'
                ),
              ]
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), 
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Search vendors, restaurants, markets...',
                hintStyle: TextStyle(color: subtextColor),
                prefixIcon: Icon(Icons.search, color: subtextColor),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear, color: subtextColor), 
                      onPressed: () { 
                        _searchController.clear(); 
                        context.read<SearchProvider>().clearSearch();
                        context.read<VendorProvider>().clearSearch(); 
                      }
                    ) 
                  : null,
                filled: true, 
                fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: _onSearchChanged,
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
    builder: (context) => Container(
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
                Icon(Icons.location_on, color: textColor),
                const SizedBox(width: 12),
                Text('Delivery Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: subtextColor),
                  onPressed: () => Navigator.pop(context),
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
                    return ListTile(
                      leading: Icon(
                        address.isDefault ? Icons.home : Icons.location_on,
                        color: isSelected ? Colors.green : subtextColor,
                      ),
                      title: Text(
                        address.label ?? address.shortAddress,
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
                      trailing: isSelected 
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : Icon(Icons.arrow_forward_ios, size: 16, color: subtextColor),
                      onTap: () async {
                        Navigator.pop(context);
                        
                        // CHECK KIGALI RESTRICTION
                        if (_isLocationOutOfKigali(address.latitude, address.longitude)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ This address is outside Kigali. Please select a location within Kigali.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 5),
                            ),
                          );
                          return;
                        }
                        
                        setState(() => _currentAddress = address);
                        await _loadVendorsForAddress(address);
                      },
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
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
                  );
                  
                  if (result != null && result is DeliveryAddress) {
                    // CHECK KIGALI RESTRICTION
                    if (_isLocationOutOfKigali(result.latitude, result.longitude)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Sorry, we only serve within Kigali. Please select a location within Kigali.'),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0, textColor, subtextColor, isDarkMode)),
              Expanded(child: _buildNavItem(Icons.restaurant_outlined, Icons.restaurant, 'Restaurants', 1, textColor, subtextColor, isDarkMode)),
              Expanded(child: _buildNavItem(Icons.shopping_bag_outlined, Icons.shopping_bag, 'Markets', 2, textColor, subtextColor, isDarkMode)),
              Expanded(child: _buildNavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Cart', 3, textColor, subtextColor, isDarkMode)),
              Expanded(child: _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 4, textColor, subtextColor, isDarkMode)),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isSelected ? filledIcon : outlinedIcon, color: isSelected ? selectedTextColor : subtextColor, size: 24),
          const SizedBox(height: 4),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : chipColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.black : (isDarkMode ? Colors.grey[800]! : Colors.grey[300]!), width: 1.5),
        ),
        child: Text(category, style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _buildPromotionCircle(SpecialOffer promo, bool isDarkMode, Color cardColor, Color textColor) {
    // Build robust image URL with validation
    String imageUrl = 'https://picsum.photos/seed/offer${promo.id}/400/300';
    if (promo.imageUrl != null && promo.imageUrl!.isNotEmpty) {
      final trimmedUrl = promo.imageUrl!.trim().toLowerCase();
      // Skip invalid values
      if (trimmedUrl != 'null' && trimmedUrl != 'none' && !trimmedUrl.isEmpty) {
        imageUrl = 'http://localhost:5000/static/uploads/offers/${promo.imageUrl}';
      }
    }
    
    // Professional gradient colors for offer badges
    final _brandTeal = const Color(0xFF2BC2B4);
    final _brandAmber = const Color(0xFFFFB24C);
    
    return GestureDetector(
      onTap: () => print('Tapped on ${promo.name}'),
      child: SizedBox(
        width: 85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Professional circular card with gradient overlay
            Container(
              width: 70, 
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    spreadRadius: 1
                  )
                ],
              ),
              child: Stack(
                children: [
                  // Image
                  ClipOval(
                    child: Image.network(
                      imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_brandTeal.withOpacity(0.1), _brandAmber.withOpacity(0.1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_brandTeal),
                            )
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        // Professional fallback with gradient
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_brandTeal.withOpacity(0.2), _brandAmber.withOpacity(0.2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(Icons.local_offer, color: _brandTeal, size: 32),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Promotion name
            SizedBox(
              height: 14,
              child: Text(
                promo.name, 
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w600, 
                  color: textColor,
                  height: 1.0,
                ), 
                textAlign: TextAlign.center, 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis
              ),
            ),
            const SizedBox(height: 3),
            // Discount badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_brandAmber, _brandAmber.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: _brandAmber.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                promo.discountText, 
                style: const TextStyle(
                  fontSize: 9, 
                  fontWeight: FontWeight.w700, 
                  color: Colors.white,
                  height: 1.0,
                ), 
                textAlign: TextAlign.center, 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis
              ),
            ),
          ],
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
        context.go('/create-pickup-order');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.black, Colors.grey[900]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: 2)],
        ),
        child: Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15), border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Send a Package', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Fast pickup & delivery anywhere', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: const Text('Ntwaza Now →', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ])
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
        context.go('/create-pickup-order');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orangeAccent, Colors.deepOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepOrange.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ntwaza Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send packages anywhere fast',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Start Order →',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 12,
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
              size: 20,
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

  Widget _buildVendorCard(Vendor vendor, int index, bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
    final isHovered = _hoveredCardIndex == index;
    // Use logoUrl first, then bannerUrl as fallback, then placeholder
    final imageUrl = vendor.logoUrl.isNotEmpty 
        ? vendor.logoUrl 
        : (vendor.bannerUrl != null && vendor.bannerUrl!.isNotEmpty 
            ? vendor.bannerUrl! 
            : 'https://picsum.photos/seed/vendor$index/400/300');
    
    print('📦 Vendor Card: ${vendor.name}');
    print('   Raw logoUrl: "${vendor.logoUrl}"');
    print('   Raw bannerUrl: "${vendor.bannerUrl}"');
    print('   Final imageUrl: "$imageUrl"');
    
    final businessName = vendor.name;
    final businessType = vendor.category.toLowerCase();

    IconData businessIcon = Icons.store;
    String typeLabel = 'Store';
    if (businessType.contains('restaurant')) {
      businessIcon = Icons.restaurant;
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredCardIndex = index),
      onExit: (_) => setState(() => _hoveredCardIndex = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isHovered ? -8 : 0, 0),
        child: Card(
          elevation: isHovered ? 8 : 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: cardColor,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VendorDetailScreen(vendor: vendor))),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3, 
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                        child: _buildVendorImage(
                          imageUrl,
                          isDarkMode: isDarkMode,
                          businessIcon: businessIcon,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 12, left: 12, 
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(businessIcon, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(typeLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        )
                      ),
                      Positioned(
                        top: 12, right: 12, 
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: vendor.isOpen ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                          child: Text(vendor.isOpen ? 'OPEN' : 'CLOSED', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        )
                      ),
                    ],
                  )
                ),
                Padding(
                  padding: const EdgeInsets.all(12), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(businessName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor), maxLines: 1),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        (vendor.totalRatings == 0)
                          ? Text('New', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor))
                          : Text(vendor.formattedRating, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                        if (vendor.totalRatings > 0) ...[
                          const SizedBox(width: 4), 
                          Text('(${vendor.totalRatings})', style: TextStyle(fontSize: 11, color: subtextColor))
                        ],
                        const Spacer(),
                        Icon(Icons.access_time, size: 14, color: vendor.isOpen ? Colors.green : Colors.grey),
                        const SizedBox(width: 4),
                        Text(deliveryTime, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: vendor.isOpen ? Colors.green : Colors.grey)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.location_on, size: 12, color: Colors.blue),
                        const SizedBox(width: 3),
                        Flexible(child: Text(distanceText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue), overflow: TextOverflow.ellipsis)),
                        if (distanceText != 'D/U') ...[
                          const SizedBox(width: 16),
                          Text('DF:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black)),
                          const SizedBox(width: 2),
                          Text(deliveryFeeText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
                        ],
                        if (!vendor.isDeliverable) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text('Too far', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w600)),
                          ),
                        ],
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
    
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VendorDetailScreen(vendor: vendor))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor, 
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8), 
            child: _buildVendorImage(
              imageUrl,
              isDarkMode: isDarkMode,
              businessIcon: Icons.store,
              width: 60,
              height: 60,
              showText: false,
            )
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(vendor.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor), maxLines: 1),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.star, size: 12, color: Colors.amber),
                const SizedBox(width: 4),
                (vendor.totalRatings == 0)
                  ? Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtextColor))
                  : Text(vendor.formattedRating, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtextColor)),
                const SizedBox(width: 8),
                Icon(Icons.access_time, size: 12, color: vendor.isOpen ? Colors.green : Colors.grey),
                const SizedBox(width: 4),
                Text(deliveryTime, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: vendor.isOpen ? Colors.green : Colors.grey)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on, size: 12, color: Colors.blue),
                const SizedBox(width: 4),
                Text(distanceText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
              ]),
            ])
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: subtextColor),
        ]),
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isDarkMode, Color cardColor, Color textColor, [Color? subtextColor]) {
    final price = product.price;
    final priceText = 'Rwf $price';
    final imageUrl = product.imageUrl.isNotEmpty ? product.imageUrl : 'https://picsum.photos/seed/${product.id}/200/200';
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
      onTap: isVendorClosed 
        ? () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('This shop is currently closed. Try again when they open.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        : () async {
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: subtextColor),
            const SizedBox(height: 16),
            Text('No results for "${searchProvider.searchQuery}"', style: TextStyle(color: textColor, fontSize: 16)),
          ],
        ),
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
  return Container(
    color: Colors.black.withOpacity(0.4),
    child: Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
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
              'We only serve within Kigali. Please select a location in Kigali to continue.',
              style: TextStyle(fontSize: 13, color: subtextColor, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Use Current Location
            SizedBox(
              width: double.infinity,
              height: 44,
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
              height: 44,
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
  );
}

// Handle location permission and selection
Future<void> _handleSetLocation() async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      final position = await Geolocator.getCurrentPosition();

      if (_isLocationOutOfKigali(position.latitude, position.longitude)) {
        if (mounted) {
          _showLocationError('Your location is outside Kigali. Please search for an address within our service area.');
        }
        return;
      }

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
    } else {
      await Geolocator.openAppSettings();
    }
  } catch (e) {
    print('Error getting location: $e');
    if (mounted) {
      _showLocationError('Unable to get location. Please try again.');
    }
  }
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
// NEW: No vendors overlay (keeps app chrome visible)
Widget _buildNoVendorsOverlay(bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
  // Determine message based on selected category
  String title;
  String message;
  IconData icon;
  
  if (_selectedCategory == 'All' || _selectedCategory.isEmpty) {
    title = 'No Vendors Nearby';
    message = 'We currently don\'t have any vendors in this area. Try changing your location within Kigali.';
    icon = Icons.store_mall_directory_outlined;
  } else if (_selectedCategory == 'Others') {
    title = 'Coming Soon';
    message = 'We\'re working on bringing more service categories to you. Check back soon for more options!';
    icon = Icons.new_releases;
  } else {
    // Category-specific messages
    title = 'No ${_selectedCategory} Available';
    message = 'We don\'t have any ${_selectedCategory.toLowerCase()} available at the moment. Please check back later or try another category.';
    icon = _selectedCategory == 'Restaurants' 
        ? Icons.restaurant
        : _selectedCategory == 'Supermarkets'
            ? Icons.shopping_cart
            : Icons.store;
  }
  
  return Stack(
    children: [
      Opacity(
        opacity: 0.2,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 100, color: subtextColor),
              const SizedBox(height: 16),
              Text(_selectedCategory == 'All' ? 'Browse Vendors' : _selectedCategory, 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
            ],
          ),
        ),
      ),
      
      Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 4),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: Colors.orange[700]),
                  ),
                  const SizedBox(height: 16),
                  Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(color: subtextColor, fontSize: 13, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  // Only show location info and change button for 'All' category
                  if (_selectedCategory == 'All' || _selectedCategory.isEmpty) ...[
                    if (_currentAddress != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.orange[700], size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Current Location', style: TextStyle(fontSize: 10, color: subtextColor, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currentAddress?.label ?? _currentAddress?.shortAddress ?? 'Unknown',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
                          );

                          if (result != null && result is DeliveryAddress) {
                            // CHECK KIGALI RESTRICTION
                            if (_isLocationOutOfKigali(result.latitude, result.longitude)) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('❌ Sorry, we only serve within Kigali. Please select a location within Kigali.'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 5),
                                  ),
                                );
                              }
                              return;
                            }
                            
                            setState(() => _currentAddress = result);
                            await _loadVendorsForAddress(result);
                          }
                        },
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                        label: const Text('Change Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ] else if (_selectedCategory == 'Others') ...[
                    // For Others category, show button to explore other categories
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _handleCategoryTap('All');
                        },
                        icon: const Icon(Icons.explore_outlined, size: 20),
                        label: const Text('Explore Other Categories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ] else ...[
                    // For other categories, show a button to view all categories
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _handleCategoryTap('All');
                        },
                        icon: const Icon(Icons.grid_view, size: 22),
                        label: const Text('View All Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange[700],
                          side: BorderSide(color: Colors.orange[700]!, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.black),
          const SizedBox(height: 16),
          Text('Loading vendors...', style: TextStyle(color: textColor, fontSize: 16)),
        ],
      ),
    );
  }

  // DON'T call _buildNoVendorsScreen here - let the main build handle it
  // This breaks the recursion

  return RefreshIndicator(
    onRefresh: () async {
      if (_currentAddress != null) {
        await _loadVendorsForAddress(_currentAddress!);
      }
    },
    color: Colors.black,
    child: ListView(
      controller: _scrollController,
      children: [
        if (specialOffers.isNotEmpty)
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Special Offers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 107,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: specialOffers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _buildPromotionCircle(specialOffers[index], isDarkMode, cardColor, textColor),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _buildPackageDeliveryBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('Browse Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
        ),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _categories.map((category) => _buildCategoryChip(category, isDarkMode, cardColor, Colors.black, textColor)).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCategory == 'All' ? 'Featured Vendors' : _selectedCategory,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
              ),
              Text('(${displayVendors.length} found)', style: TextStyle(fontSize: 14, color: subtextColor)),
            ],
          ),
        ),
        if (displayVendors.isNotEmpty)
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
              itemCount: displayVendors.length,
              itemBuilder: (context, index) {
                final Vendor vendor = displayVendors[index];
                return _buildVendorCard(vendor, index, isDarkMode, cardColor, textColor, subtextColor);
              },
            ),
          ),
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
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );
  }

  // Build the main content
  Widget mainContent;
  
  if (_currentAddress == null) {
    // Show location selection WITH app chrome
    mainContent = _buildLocationSelectionOverlay(isDarkMode, cardColor, textColor, subtextColor);
  } else if (vendorProvider.vendors.isEmpty && !vendorProvider.isLoading && !isSearching) {
    // Show no vendors WITH app chrome
    mainContent = _buildNoVendorsOverlay(isDarkMode, cardColor, textColor, subtextColor);
  } else {
    // Normal content
    mainContent = isSearching
        ? _buildSearchResults(searchProvider, isDarkMode, cardColor, textColor, subtextColor)
        : _buildNormalVendorList(context, vendorProvider, specialOfferProvider, isDarkMode, cardColor, textColor, subtextColor);
  }

  return Scaffold(
    backgroundColor: backgroundColor,
    body: Column(
      children: [
        _buildSearchHeader(context, isDarkMode, cardColor, textColor, subtextColor, vendorProvider, authProvider, themeProvider),
        Expanded(child: mainContent),
      ],
    ),
    bottomNavigationBar: _buildBottomNav(isDarkMode, cardColor, textColor, subtextColor),
  );
}}