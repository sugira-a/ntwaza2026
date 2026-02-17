import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ntwaza/models/order.dart';
import 'package:ntwaza/providers/rider_order_provider.dart';
import 'package:ntwaza/services/api/api_service.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel localNotificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const MethodChannel localNotificationsChannelAlt =
      MethodChannel('flutter_local_notifications');

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});

    localNotificationsChannel.setMockMethodCallHandler(
      (MethodCall methodCall) async => null,
    );
    localNotificationsChannelAlt.setMockMethodCallHandler(
      (MethodCall methodCall) async => null,
    );
  });

  tearDownAll(() {
    localNotificationsChannel.setMockMethodCallHandler(null);
    localNotificationsChannelAlt.setMockMethodCallHandler(null);
  });

  Map<String, dynamic> buildOrderJson({
    String id = '1',
    String status = 'pending',
  }) {
    return {
      'id': id,
      'order_number': 'ORD-$id',
      'customer_id': 'c1',
      'customer_name': 'Customer',
      'vendor_id': 'v1',
      'vendor_name': 'Vendor',
      'status': status,
      'subtotal': 10.0,
      'delivery_fee': 2.0,
      'total': 12.0,
      'created_at': DateTime.now().toIso8601String(),
      'items': [],
      'payment_method': 'cash',
    };
  }

  group('RiderOrderProvider', () {
    late MockApiService api;
    late RiderOrderProvider provider;

    setUp(() {
      api = MockApiService();
      provider = RiderOrderProvider(apiService: api);
    });

    test('fetchAvailableOrders loads list on success', () async {
      when(() => api.get('/api/rider/available-orders')).thenAnswer(
        (_) async => {
          'success': true,
          'orders': [buildOrderJson(id: '1')],
        },
      );

      await provider.fetchAvailableOrders();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.availableOrders.length, 1);
      expect(provider.availableOrders.first.id, '1');
    });

    test('fetchAvailableOrders sets error on failure', () async {
      when(() => api.get('/api/rider/available-orders')).thenAnswer(
        (_) async => {
          'success': false,
          'error': 'failed',
        },
      );

      await provider.fetchAvailableOrders();

      expect(provider.isLoading, isFalse);
      expect(provider.availableOrders, isEmpty);
      expect(provider.error, 'failed');
    });

    test('fetchAssignedOrders loads list on success', () async {
      when(() => api.get('/api/rider/orders')).thenAnswer(
        (_) async => {
          'success': true,
          'orders': [buildOrderJson(id: '2', status: 'confirmed')],
        },
      );

      await provider.fetchAssignedOrders();

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.orders.length, 1);
      expect(provider.orders.first.status, OrderStatus.confirmed);
    });

    test('fetchDeliveryHistory loads list on success', () async {
      when(() => api.get('/api/rider/orders/history')).thenAnswer(
        (_) async => {
          'success': true,
          'orders': [buildOrderJson(id: '3', status: 'completed')],
        },
      );

      await provider.fetchDeliveryHistory();

      expect(provider.isLoadingHistory, isFalse);
      expect(provider.error, isNull);
      expect(provider.deliveryHistory.length, 1);
      expect(provider.deliveryHistory.first.status, OrderStatus.completed);
    });

    test('acceptOrder removes order and refreshes assigned list', () async {
      when(() => api.get('/api/rider/available-orders')).thenAnswer(
        (_) async => {
          'success': true,
          'orders': [buildOrderJson(id: '10')],
        },
      );
      when(() => api.post('/api/rider/orders/10/accept', any())).thenAnswer(
        (_) async => {'success': true},
      );
      when(() => api.get('/api/rider/orders')).thenAnswer(
        (_) async => {'success': true, 'orders': []},
      );

      await provider.fetchAvailableOrders();
      final result = await provider.acceptOrder('10');

      expect(result, isTrue);
      expect(provider.availableOrders, isEmpty);
      verify(() => api.post('/api/rider/orders/10/accept', any())).called(1);
      verify(() => api.get('/api/rider/orders')).called(1);
    });

    test('rejectOrder removes order from available list', () async {
      when(() => api.get('/api/rider/available-orders')).thenAnswer(
        (_) async => {
          'success': true,
          'orders': [buildOrderJson(id: '11')],
        },
      );
      when(() => api.post('/api/rider/orders/11/reject', any())).thenAnswer(
        (_) async => {'success': true},
      );

      await provider.fetchAvailableOrders();
      final result = await provider.rejectOrder('11');

      expect(result, isTrue);
      expect(provider.availableOrders, isEmpty);
      verify(() => api.post('/api/rider/orders/11/reject', any())).called(1);
    });

    test('updateOrderStatus refreshes assigned list on success', () async {
      when(() => api.put('/api/rider/orders/12/status', any())).thenAnswer(
        (_) async => {'success': true},
      );
      when(() => api.get('/api/rider/orders')).thenAnswer(
        (_) async => {'success': true, 'orders': []},
      );

      final result = await provider.updateOrderStatus('12', 'picked_up');

      expect(result, isTrue);
      verify(() => api.put('/api/rider/orders/12/status', any())).called(1);
      verify(() => api.get('/api/rider/orders')).called(1);
    });
  });
}
