import '../models/vendor.dart';
import 'api/api_service.dart';

class VendorService {
  final ApiService api;

  VendorService({required this.api});

  // =====================================================
  // GET VENDORS (WITH DISTANCE)
  // =====================================================
  Future<List<Vendor>> getVendors({
    int page = 1,
    int perPage = 20,
    String? category,
    String? search,
    String? city,
    bool? isOpen,
    String sortBy = 'rating',
    double? latitude,
    double? longitude,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      'sort': sortBy,
    };

    if (category != null) params['category'] = category;
    if (search != null) params['search'] = search;
    if (city != null) params['city'] = city;
    if (isOpen != null) params['is_open'] = isOpen.toString();
    if (latitude != null && longitude != null) {
      params['latitude'] = latitude.toString();
      params['longitude'] = longitude.toString();
    }

    final endpoint = Uri(
      path: '/api/vendors',
      queryParameters: params,
    ).toString();

    final response = await api.get(endpoint);
    final List list = response['vendors'] ?? [];

    // DEBUG: Print first vendor's raw JSON
    if (list.isNotEmpty) {
      print('🔍 DEBUG RAW VENDOR JSON:');
      print(list[0]);
      print('🔍 vendor_type field: ${list[0]['vendor_type']}');
    }

    return list.map((e) => Vendor.fromJson(e)).toList();
  }

  // =====================================================
  // SINGLE VENDOR
  // =====================================================
  Future<Vendor> getVendor(
    String vendorId, {
    double? latitude,
    double? longitude,
  }) async {
    final params = <String, String>{};

    if (latitude != null && longitude != null) {
      params['latitude'] = latitude.toString();
      params['longitude'] = longitude.toString();
    }

    final endpoint = Uri(
      path: '/api/vendors/$vendorId',
      queryParameters: params.isEmpty ? null : params,
    ).toString();

    final response = await api.get(endpoint);
    
    // DEBUG: Print vendor detail raw JSON
    print('🔍 DEBUG SINGLE VENDOR RAW JSON:');
    print(response['vendor']);
    print('🔍 vendor_type field: ${response['vendor']['vendor_type']}');
    
    return Vendor.fromJson(response['vendor']);
  }

  // =====================================================
  // CATEGORIES
  // =====================================================
  Future<List<String>> getCategories() async {
    final response = await api.get('/api/vendors/categories');
    final List cats = response['categories'] ?? [];
    return cats.map<String>((c) => c['name'] as String).toList();
  }
}