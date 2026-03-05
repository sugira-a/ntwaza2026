// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

// Providers
import 'providers/product_detail_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/product_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/vendor_provider.dart';
import 'providers/special_offer_provider.dart';
import 'providers/search_provider.dart';
import 'providers/address_provider.dart';
import 'providers/vendor_order_provider.dart';
import 'providers/admin_order_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/rider_provider.dart';
import 'providers/rider_order_provider.dart';
import 'providers/pickup_order_provider.dart';
import 'providers/review_provider.dart';
import 'providers/wishlist_provider.dart';

// Services
import 'services/product_service.dart';
import 'services/api/api_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';

import 'routes/app_router.dart';

// Constants
import 'core/constants/api_endpoints.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📨 Background message: ${message.notification?.title}');
}

void main() async {
  // Setup error handling for uncaught exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    print('❌ Flutter Error: ${details.exceptionAsString()}');
    print('${details.context}');
  };
  
  PlatformDispatcher.instance.onError = (error, stack) {
    print('❌ Platform Error: $error');
    print('Stack trace: $stack');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Maps Android renderer to fix blank map on Android
  if (!kIsWeb) {
    final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      // Use latest renderer for best performance and tile loading
      try {
        await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
        print('✅ Google Maps Android renderer initialized (latest)');
      } catch (e) {
        print('⚠️ Map renderer initialization failed, trying legacy: $e');
        try {
          await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.legacy);
          print('✅ Google Maps Android renderer initialized (legacy)');
        } catch (e2) {
          print('⚠️ Legacy renderer also failed: $e2');
        }
      }
    }
  }

  // Enable edge-to-edge mode with transparent system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // dark icons for light background
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('✅ Firebase initialized');
  } catch (e) {
    print('⚠️ Firebase initialization failed: $e');
  }

  ApiEndpoints.logCurrentConfig();

  final authProvider = AuthProvider();
  await authProvider.initialize();

  // Initialize AddressProvider (lightweight — reads SharedPreferences)
  final addressProvider = AddressProvider();
  // Await so addresses are loaded before splash checks hasAddresses
  await addressProvider.initialize();

  // Initialize API services
  final apiService = ApiService();
  final locationService = LocationService();

  // Initialize notification service - ONLY for returning users who already granted permissions.
  // For first-time users, the splash screen handles permission flow (location FIRST, then notifications)
  // to avoid the notification dialog blocking the location dialog.
  final notificationService = NotificationService();
  final hasSeenPermissions = (await SharedPreferences.getInstance()).getBool('has_seen_permissions') ?? false;
  if (hasSeenPermissions) {
    notificationService.initialize();
  }

  // Initialize wishlist provider
  final wishlistProvider = WishlistProvider();
  await wishlistProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(
          create: (_) => ProductDetailProvider(productService: ProductService()),
        ),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider.value(value: addressProvider),
        ChangeNotifierProvider(create: (_) => CartProvider(apiService)),
        ChangeNotifierProvider(create: (_) => VendorProvider(apiService: apiService, locationService: locationService)),
        ChangeNotifierProvider(create: (_) => SpecialOfferProvider(apiService)),
        ChangeNotifierProvider(create: (_) => VendorOrderProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => AdminOrderProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(apiService: apiService, notificationService: notificationService)),
        ChangeNotifierProvider(create: (_) => RiderProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => RiderOrderProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => PickupOrderProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider.value(value: wishlistProvider),
      ],
      child: MyApp(router: AppRouter.router),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({Key? key, required this.router}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        // Set system UI overlay style based on theme
        final systemUiStyle = themeProvider.isDarkMode
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.black,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.white,
                systemNavigationBarIconBrightness: Brightness.dark,
              );
        
        SystemChrome.setSystemUIOverlayStyle(systemUiStyle);
        
        return MaterialApp.router(
          title: 'Ntwaza',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          routerConfig: router,
          builder: (context, child) {
            return ScaffoldMessenger(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
