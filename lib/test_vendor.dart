// lib/test_vendor.dart
import 'models/vendor.dart';

void testVendor() {
  print('Testing Vendor import...');
  final v = Vendor(
    id: '1',
    name: 'Test',
    category: 'Test',
    logoUrl: '',
    rating: 5.0,
    totalRatings: 0,
    latitude: 0,
    longitude: 0,
    prepTimeMinutes: 30,
  );
  print('✅ Vendor works: ${v.name}');
}