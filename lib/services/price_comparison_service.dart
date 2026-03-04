// lib/services/price_comparison_service.dart
/// Service to compare product prices across vendors
import 'api/api_service.dart';
import '../models/product.dart';

class PriceComparison {
  final String vendorId;
  final String vendorName;
  final double price;
  final double? discountedPrice;
  final bool isDiscounted;
  final double distance;

  PriceComparison({
    required this.vendorId,
    required this.vendorName,
    required this.price,
    this.discountedPrice,
    required this.distance,
  }) : isDiscounted = discountedPrice != null && discountedPrice < price;

  double get savingsAmount => (price - (discountedPrice ?? price)).abs();
  double get savingsPercent => (savingsAmount / price * 100).clamp(0, 100);
  bool get isCheapest => false; // Set by calling function
}

class PriceComparisonService {
  final ApiService _apiService = ApiService();

  /// Find same product across vendors with different prices
  /// Returns list of vendors selling product sorted by price
  Future<List<PriceComparison>> compareProductPrice({
    required String productName,
    required String productId,
    required double userLatitude,
    required double userLongitude,
  }) async {
    try {
      print('\n💰 PRICE COMPARISON: $productName');

      final response = await _apiService.post(
        '/api/products/compare',
        body: {
          'product_id': productId,
          'product_name': productName,
          'latitude': userLatitude,
          'longitude': userLongitude,
        },
      );

      if (response['success'] != true) {
        print('⚠️  No price comparison available');
        return [];
      }

      final comparisons = (response['comparisons'] as List?)
          ?.map((item) => PriceComparison(
            vendorId: item['vendor_id'] as String,
            vendorName: item['vendor_name'] as String,
            price: double.parse('${item['price'] ?? 0}'),
            discountedPrice: item['discounted_price'] != null
                ? double.parse('${item['discounted_price']}')
                : null,
            distance: double.parse('${item['distance'] ?? 0}'),
          ))
          .toList() ?? [];

      // Sort by price (cheapest first)
      comparisons.sort((a, b) => 
        (a.discountedPrice ?? a.price).compareTo(b.discountedPrice ?? b.price));

      print('✅ Found ${comparisons.length} vendors selling $productName');
      for (var c in comparisons) {
        final price = c.discountedPrice ?? c.price;
        print('   - ${c.vendorName}: RWF ${price.toStringAsFixed(0)}');
      }

      return comparisons;
    } catch (e) {
      print('❌ Price comparison error: $e');
      return [];
    }
  }

  /// Get cheapest vendor for product (simple query)
  Future<PriceComparison?> getCheapestVendor({
    required String productName,
    required double userLatitude,
    required double userLongitude,
  }) async {
    final comparisons = await compareProductPrice(
      productName: productName,
      productId: productName.toLowerCase().replaceAll(' ', '_'),
      userLatitude: userLatitude,
      userLongitude: userLongitude,
    );

    return comparisons.isNotEmpty ? comparisons.first : null;
  }

  /// Compare similar items and get savings potential
  Future<Map<String, dynamic>> getSavingsOpportunity({
    required List<String> productNames,
    required double userLatitude,
    required double userLongitude,
  }) async {
    try {
      print('\n💸 BASKET SAVINGS ANALYSIS: ${productNames.length} items');

      double totalNormalPrice = 0;
      double totalCheapestPrice = 0;
      final details = <Map<String, dynamic>>[];

      for (var productName in productNames) {
        final comparisons = await compareProductPrice(
          productName: productName,
          productId: productName.toLowerCase().replaceAll(' ', '_'),
          userLatitude: userLatitude,
          userLongitude: userLongitude,
        );

        if (comparisons.isNotEmpty) {
          final cheapest = comparisons.first;
          final normalPrice = comparisons.last.price;
          
          totalNormalPrice += normalPrice;
          totalCheapestPrice += (cheapest.discountedPrice ?? cheapest.price);

          details.add({
            'product': productName,
            'normal_price': normalPrice,
            'cheapest_price': cheapest.discountedPrice ?? cheapest.price,
            'cheapest_vendor': cheapest.vendorName,
            'savings': normalPrice - (cheapest.discountedPrice ?? cheapest.price),
          });
        }
      }

      final totalSavings = totalNormalPrice - totalCheapestPrice;
      final savingsPercent = totalNormalPrice > 0
          ? (totalSavings / totalNormalPrice * 100).clamp(0, 100)
          : 0.0;

      print('✅ Total potential savings: RWF ${totalSavings.toStringAsFixed(0)} (${savingsPercent.toStringAsFixed(1)}%)');

      return {
        'success': true,
        'total_normal_price': totalNormalPrice,
        'total_cheapest_price': totalCheapestPrice,
        'potential_savings': totalSavings,
        'savings_percent': savingsPercent,
        'details': details,
      };
    } catch (e) {
      print('❌ Savings analysis error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
