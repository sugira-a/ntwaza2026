// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

// Services
import 'services/product_service.dart';
import 'services/api/api_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';

import 'routes/app_router.dart';

// Constants
import 'core/constants/api_endpoints.dart';

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

  ApiEndpoints.logCurrentConfig();

  final authProvider = AuthProvider();
  await authProvider.initialize();

  // Initialize AddressProvider
  final addressProvider = AddressProvider();
  await addressProvider.initialize();

  // Initialize API services
  final apiService = ApiService();
  final locationService = LocationService();

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

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
