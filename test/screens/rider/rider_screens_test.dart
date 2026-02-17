import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:ntwaza/models/order.dart';
import 'package:ntwaza/models/user_model.dart';
import 'package:ntwaza/providers/auth_provider.dart';
import 'package:ntwaza/providers/rider_order_provider.dart';
import 'package:ntwaza/providers/theme_provider.dart';
import 'package:ntwaza/screens/rider/rider_dashboard.dart';
import 'package:ntwaza/screens/rider/rider_delivery_history.dart';
import 'package:ntwaza/screens/rider/rider_orders_screen.dart';

class MockRiderOrderProvider extends Mock implements RiderOrderProvider {}
class MockThemeProvider extends Mock implements ThemeProvider {}
class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;

  Order buildOrder({
    String id = '1',
    OrderStatus status = OrderStatus.confirmed,
  }) {
    return Order(
      id: id,
      orderNumber: 'ORD-$id',
      customerId: 'c$id',
      customerName: 'Customer $id',
      vendorId: 'v$id',
      vendorName: 'Vendor $id',
      status: status,
      subtotal: 10,
      deliveryFee: 2,
      total: 12,
      createdAt: DateTime.now(),
      items: <OrderItem>[],
      paymentMethod: 'cash',
      deliveryInfo: DeliveryInfo(
        address: '123 Street',
        latitude: 1.0,
        longitude: 2.0,
      ),
      vendorLatitude: 1.0,
      vendorLongitude: 2.0,
      estimatedArrivalTime: DateTime.now().add(const Duration(minutes: 30)),
      minutesRemaining: 30,
    );
  }

  Widget buildApp({
    required Widget child,
    required RiderOrderProvider riderProvider,
    required ThemeProvider themeProvider,
    AuthProvider? authProvider,
  }) {
    final providers = <SingleChildWidget>[
      Provider<RiderOrderProvider>.value(value: riderProvider),
      Provider<ThemeProvider>.value(value: themeProvider),
    ];
    if (authProvider != null) {
      providers.add(Provider<AuthProvider>.value(value: authProvider));
    }

    return MultiProvider(
      providers: providers,
      child: MaterialApp(home: child),
    );
  }

  void stubRiderProviderBase(MockRiderOrderProvider provider) {
    when(() => provider.fetchAssignedOrders()).thenAnswer((_) async {});
    when(() => provider.fetchAvailableOrders()).thenAnswer((_) async {});
    when(() => provider.fetchDeliveryHistory()).thenAnswer((_) async {});
    when(() => provider.startAutoRefresh()).thenReturn(null);
    when(() => provider.startAutoRefresh(any())).thenReturn(null);
    when(() => provider.stopAutoRefresh()).thenReturn(null);
    when(() => provider.isLoading).thenReturn(false);
    when(() => provider.isLoadingHistory).thenReturn(false);
    when(() => provider.error).thenReturn(null);
    when(() => provider.availableOrders).thenReturn(<Order>[]);
    when(() => provider.orders).thenReturn(<Order>[]);
    when(() => provider.deliveryHistory).thenReturn(<Order>[]);
  }

  testWidgets('RiderOrdersScreen shows empty state', (tester) async {
    final riderProvider = MockRiderOrderProvider();
    final themeProvider = MockThemeProvider();

    stubRiderProviderBase(riderProvider);
    when(() => themeProvider.isDarkMode).thenReturn(false);

    await tester.pumpWidget(
      buildApp(
        child: const RiderOrdersScreen(),
        riderProvider: riderProvider,
        themeProvider: themeProvider,
      ),
    );

    expect(find.text('No active deliveries'), findsOneWidget);
  });

  testWidgets('RiderOrdersScreen shows error state', (tester) async {
    final riderProvider = MockRiderOrderProvider();
    final themeProvider = MockThemeProvider();

    stubRiderProviderBase(riderProvider);
    when(() => riderProvider.error).thenReturn('Network error');
    when(() => themeProvider.isDarkMode).thenReturn(false);

    await tester.pumpWidget(
      buildApp(
        child: const RiderOrdersScreen(),
        riderProvider: riderProvider,
        themeProvider: themeProvider,
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Network error'), findsOneWidget);
  });

  testWidgets('RiderOrdersScreen renders order card', (tester) async {
    final riderProvider = MockRiderOrderProvider();
    final themeProvider = MockThemeProvider();

    stubRiderProviderBase(riderProvider);
    when(() => riderProvider.orders).thenReturn([buildOrder()]);
    when(() => themeProvider.isDarkMode).thenReturn(false);

    await tester.pumpWidget(
      buildApp(
        child: const RiderOrdersScreen(),
        riderProvider: riderProvider,
        themeProvider: themeProvider,
      ),
    );

    expect(find.text('ORD-1'), findsOneWidget);
  });

  testWidgets('RiderDeliveryHistory shows empty state', (tester) async {
    final riderProvider = MockRiderOrderProvider();
    final themeProvider = MockThemeProvider();

    stubRiderProviderBase(riderProvider);
    when(() => riderProvider.deliveryHistory).thenReturn(<Order>[]);
    when(() => themeProvider.isDarkMode).thenReturn(false);

    await tester.pumpWidget(
      buildApp(
        child: const RiderDeliveryHistory(),
        riderProvider: riderProvider,
        themeProvider: themeProvider,
      ),
    );
    await tester.pump();

    expect(find.text('No delivery history'), findsOneWidget);
  });

  testWidgets('RiderDashboard shows tabs and stats', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final riderProvider = MockRiderOrderProvider();
    final themeProvider = MockThemeProvider();
    final authProvider = MockAuthProvider();

    stubRiderProviderBase(riderProvider);
    when(() => riderProvider.availableOrders).thenReturn([buildOrder(id: '1'), buildOrder(id: '2')]);
    when(() => riderProvider.orders).thenReturn([buildOrder(id: '3')]);
    when(() => riderProvider.deliveryHistory).thenReturn([
      buildOrder(id: '4', status: OrderStatus.completed),
      buildOrder(id: '5', status: OrderStatus.completed),
      buildOrder(id: '6', status: OrderStatus.completed),
    ]);

    when(() => themeProvider.isDarkMode).thenReturn(false);

    when(() => authProvider.isAuthenticated).thenReturn(true);
    when(() => authProvider.user).thenReturn(
      UserModel(email: 'rider@example.com', role: 'rider', firstName: 'Rider'),
    );

    await tester.pumpWidget(
      buildApp(
        child: const RiderDashboard(),
        riderProvider: riderProvider,
        themeProvider: themeProvider,
        authProvider: authProvider,
      ),
    );

    await tester.pump();

    expect(find.text('Available'), findsWidgets);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });
}
