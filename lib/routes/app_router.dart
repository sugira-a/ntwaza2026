import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
// lib/routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/vendor/vendor_main_screen.dart';
import '../screens/vendor/vendor_detail_screen.dart';
import '../screens/customer/profile_screen.dart';
import '../screens/customer/help_support_screen.dart';
import '../screens/customer/my_orders_screen.dart';
import '../screens/customer/privacy_policy_screen.dart';
import '../screens/customer/terms_of_service_screen.dart';
import '../screens/customer/create_pickup_order_screen.dart';
import '../screens/customer/order_detail_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/checkout/checkout_screen.dart';
import '../screens/admin/admin_pickup_orders_screen.dart';
import '../screens/admin/admin_dashboard_pro.dart';
import '../screens/rider/rider_main_screen.dart';
import '../screens/map/location_picker_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/permissions_screen.dart';
import '../providers/vendor_provider.dart';
import '../models/vendor.dart';


class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAuthenticated = authProvider.isAuthenticated;
      final isVendor = authProvider.isVendor;
      final isAdmin = authProvider.isAdmin;
      final isRider = authProvider.isRider;

      final isLoginPage = state.matchedLocation == '/login';
      final isRegisterPage = state.matchedLocation == '/register';

      if (isAuthenticated && isVendor && !isAdmin && state.matchedLocation == '/') {
        return '/vendor';
      }

      if (isAuthenticated && isAdmin && state.matchedLocation == '/') {
        return '/admin';
      }

      if (isAuthenticated && isRider && !isVendor && !isAdmin && state.matchedLocation == '/') {
        return '/rider';
      }

      if (isLoginPage || isRegisterPage) {
        return null;
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      // Permissions
      GoRoute(
        path: '/permissions',
        name: 'permissions',
        builder: (context, state) => const PermissionsScreen(),
      ),
      // Landing / Home
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const LandingScreen(),
      ),
      
      // Authentication
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(email: email, resetToken: token);
        },
      ),
      
      // Vendor Dashboard
      GoRoute(
        path: '/vendor',
        name: 'vendor',
        builder: (context, state) => const VendorMainScreen(),
      ),

      // Admin Dashboard
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminDashboardPro(),
      ),

      // Rider Dashboard
      GoRoute(
        path: '/rider',
        name: 'rider',
        builder: (context, state) => const RiderMainScreen(),
      ),
      
      // Vendor Detail
      GoRoute(
        path: '/vendor-detail/:id',
        name: 'vendor-detail',
        builder: (context, state) {
          final vendorId = state.pathParameters['id']!;
          return VendorDetailWrapper(vendorId: vendorId);
        },
      ),
      
      // Customer Profile
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      
      // My Orders
      GoRoute(
        path: '/my-orders',
        name: 'my-orders',
        builder: (context, state) => const MyOrdersScreen(),
      ),
      
      // Help & Support
      GoRoute(
        path: '/help-support',
        name: 'help-support',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      
        // Privacy Policy
        GoRoute(
          path: '/privacy-policy',
          name: 'privacy-policy',
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
      
        // Terms of Service
        GoRoute(
          path: '/terms-of-service',
          name: 'terms-of-service',
          builder: (context, state) => const TermsOfServiceScreen(),
        ),
      
      // Cart Screen - FIXED
      GoRoute(
        path: '/cart',
        name: 'cart',
        builder: (context, state) {
          print('🛒 Cart route builder called!');
          return const CartScreen();
        },
      ),

      // Checkout
      GoRoute(
        path: '/checkout',
        name: 'checkout',
        builder: (context, state) {
          final extra = state.extra;

          Map<String, List<String>>? selectedItems;
          if (extra is Map<String, List<String>>) {
            selectedItems = extra;
          } else if (extra is Map) {
            // Defensive: handle Map<dynamic, dynamic> etc.
            selectedItems = extra.map((key, value) {
              final vendorId = key.toString();
              final keys =
                  (value is List) ? value.map((e) => e.toString()).toList() : <String>[];
              return MapEntry(vendorId, keys);
            });
          }

          return CheckoutScreen(selectedItems: selectedItems);
        },
      ),

      // Location Picker (used by CheckoutScreen)
      GoRoute(
        path: '/location-picker',
        name: 'location-picker',
        builder: (context, state) => const LocationPickerScreen(),
      ),
      
      // Pickup Order Routes
      GoRoute(
        path: '/create-pickup-order',
        name: 'create-pickup-order',
        builder: (context, state) => const CreatePickupOrderScreen(),
      ),
      
      GoRoute(
        path: '/admin-pickup-orders',
        name: 'admin-pickup-orders',
        builder: (context, state) => const AdminPickupOrdersScreen(),
      ),
      // Order Tracking
      GoRoute(
        path: '/order/track/:id',
        name: 'order-track',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
    ],
    
    // Improved error handling for unknown routes and web restoration
    errorBuilder: (context, state) {
      print('❌ Route error: ${state.uri.path}');
      String message = 'Page not found';
      // Special handling for web route restoration
      if (state.uri.path == '/forgot-password') {
        message = 'The Forgot Password screen cannot be loaded directly after a browser refresh. Please return to the home page and navigate using the app.';
      } else if (state.uri.path == '/reset-password') {
        message = 'The Reset Password screen cannot be loaded directly after a browser refresh. Please return to the home page and navigate using the app.';
      }
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B0F14),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F9D55),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => context.go('/'),
                child: const Text(
                  'Go Home',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Vendor Detail Wrapper
class VendorDetailWrapper extends StatefulWidget {
  final String vendorId;

  const VendorDetailWrapper({super.key, required this.vendorId});

  @override
  State<VendorDetailWrapper> createState() => _VendorDetailWrapperState();
}

class _VendorDetailWrapperState extends State<VendorDetailWrapper> {
  bool _isLoading = true;
  Vendor? _vendor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVendor();
  }

  Future<void> _loadVendor() async {
    try {
      final vendorProvider = Provider.of<VendorProvider>(context, listen: false);
      
      if (vendorProvider.vendors.isEmpty) {
        await vendorProvider.fetchVendors();
      }
      
      final vendor = vendorProvider.vendors.firstWhere(
        (v) => v.id == widget.vendorId,
        orElse: () => throw Exception('Vendor not found'),
      );
      
      if (mounted) {
        setState(() {
          _vendor = vendor;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.black),
              SizedBox(height: 16),
              Text('Loading vendor details...'),
            ],
          ),
        ),
      );
    }

    if (_error != null || _vendor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vendor Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error ?? 'Vendor not found'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return VendorDetailScreen(vendor: _vendor!);
  }
}
