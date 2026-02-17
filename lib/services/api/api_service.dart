import 'dart:io' show Platform, File;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import '../../models/special_offer.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Base URL - Update this to match your backend
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }
  
  // Store auth token
  String? _authToken;
  
  // ADDED: Method names that AuthProvider expects
  void setToken(String? token) {
    _authToken = token;
    print('🔑 Token set: ${token?.substring(0, 20)}...');
  }
  
  void clearToken() {
    _authToken = null;
    print('🔑 Token cleared');
  }
  
  void setAuthToken(String? token) {
    _authToken = token;
  }
  
  String? get authToken => _authToken;
  String? get token => _authToken;

  // Common headers
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  // ============================================================================
  // GENERIC HTTP METHODS
  // ============================================================================

  Future<dynamic> get(String endpoint) async {
    try {
      print('🌐 GET $baseUrl$endpoint');
      
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('❌ GET Error: $e');
      throw Exception('Failed to perform GET request: $e');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      print('🌐 POST $baseUrl$endpoint');
      print('📦 Data: $data');
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: json.encode(data),
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('❌ POST Error: $e');
      throw Exception('Failed to perform POST request: $e');
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      print('🌐 PUT $baseUrl$endpoint');
      
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: json.encode(data),
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('❌ PUT Error: $e');
      throw Exception('Failed to perform PUT request: $e');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      print('🌐 DELETE $baseUrl$endpoint');
      
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('❌ DELETE Error: $e');
      throw Exception('Failed to perform DELETE request: $e');
    }
  }

  // Response handler
  dynamic _handleResponse(http.Response response) {
    print('📡 Response Status: ${response.statusCode}');
    print('📦 Response Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }
      return json.decode(response.body);
    } else {
      String errorMessage = 'Error ${response.statusCode}';
      try {
        final errorBody = json.decode(response.body);
        errorMessage = errorBody['error'] ?? errorBody['message'] ?? errorMessage;
      } catch (_) {
        errorMessage = response.body;
      }
      throw Exception('API Error: $errorMessage');
    }
  }

  // ============================================================================
  // AUTHENTICATION (UPDATED)
  // ============================================================================

  Future<Map<String, dynamic>> registerCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    return await post('/api/auth/register', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'password': password,
      'role': 'customer',
    });
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    
    // Auto-set token if present
    if (response['access_token'] != null) {
      setToken(response['access_token']);
    }
    
    return response;
  }

  Future<void> logout() async {
    _authToken = null;
    // Call backend logout if needed
    try {
      await post('/api/auth/logout', {});
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // ============================================================================
  // USER PROFILE (ADDED FOR AuthProvider)
  // ============================================================================

  /// Update user profile
  Future<dynamic> updateUserProfile(Map<String, dynamic> data, {String? token}) async {
    try {
      print('👤 Updating user profile: $data');
      
      // Temporarily use provided token if available
      final originalToken = _authToken;
      if (token != null) {
        setToken(token);
      }
      
      final response = await put('/api/auth/profile', data);
      
      // Restore original token
      if (token != null && originalToken != null) {
        setToken(originalToken);
      }
      
      return response;
    } catch (e) {
      print('❌ Update profile failed: $e');
      rethrow;
    }
  }

  /// Upload profile image (ADDED FOR AuthProvider)
  Future<dynamic> uploadProfileImage(File imageFile) async {
    try {
      print('📸 Uploading profile image: ${imageFile.path}');
      
      final url = Uri.parse('$baseUrl/api/auth/profile/image');
      final request = http.MultipartRequest('POST', url);
      
      // Add authorization header
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      
      // Add image file
      final imageStream = http.ByteStream(imageFile.openRead());
      final imageLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'profile_image',
        imageStream,
        imageLength,
        filename: imageFile.path.split('/').last,
        contentType: MediaType('image', 'jpeg'),
      );
      
      request.files.add(multipartFile);
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('📸 Upload Status: ${response.statusCode}');
      print('📸 Upload Response: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        throw Exception('Image upload failed: ${response.body}');
      }
    } catch (e) {
      print('❌ Image upload error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // VENDORS
  // ============================================================================

  Future<Map<String, dynamic>> getVendors({
    String? category,
    double? latitude,
    double? longitude,
  }) async {
    String endpoint = '/api/vendors';
    List<String> params = [];
    
    if (category != null && category != 'All') {
      params.add('category=$category');
    }
    if (latitude != null) {
      params.add('latitude=$latitude');
    }
    if (longitude != null) {
      params.add('longitude=$longitude');
    }
    
    if (params.isNotEmpty) {
      endpoint += '?${params.join('&')}';
    }
    
    return await get(endpoint);
  }

  Future<Map<String, dynamic>> getVendorById(String vendorId) async {
    return await get('/api/vendors/$vendorId');
  }

  // ============================================================================
  // PRODUCTS
  // ============================================================================

  Future<Map<String, dynamic>> getVendorProducts(String vendorId) async {
    return await get('/api/vendors/$vendorId/products');
  }

  Future<Map<String, dynamic>> getAllProducts() async {
    return await get('/api/products');
  }

  Future<Map<String, dynamic>> getProductsByCategory(String category) async {
    return await get('/api/products?category=$category');
  }

  Future<Map<String, dynamic>> searchProducts({required String query}) async {
    return await get('/api/products/search?q=$query');
  }

  // ============================================================================
  // SEARCH
  // ============================================================================

  Future<Map<String, dynamic>> unifiedSearch({
    required String query,
    double? userLat,
    double? userLng,
  }) async {
    String endpoint = '/api/search?q=$query';
    
    if (userLat != null && userLng != null) {
      endpoint += '&latitude=$userLat&longitude=$userLng';
    }
    
    return await get(endpoint);
  }

  Future<Map<String, dynamic>> searchVendors({
    required String query,
    double? userLat,
    double? userLng,
  }) async {
    String endpoint = '/api/search/vendors?q=$query';
    
    if (userLat != null && userLng != null) {
      endpoint += '&latitude=$userLat&longitude=$userLng';
    }
    
    return await get(endpoint);
  }

  // ============================================================================
  // SPECIAL OFFERS
  // ============================================================================

  Future<List<SpecialOffer>> getSpecialOffers({
    bool activeOnly = true,
    bool homepageOnly = false,
  }) async {
    String endpoint = '/api/special-offers';
    List<String> params = [];
    
    if (activeOnly) {
      params.add('active_only=true');
    }
    if (homepageOnly) {
      params.add('homepage_only=true');
    }
    
    if (params.isNotEmpty) {
      endpoint += '?${params.join('&')}';
    }
    
    final response = await get(endpoint);
    
    if (response['success'] == true) {
      final offersData = response['offers'] as List;
      return offersData.map((json) => SpecialOffer.fromJson(json)).toList();
    }
    
    return [];
  }

  Future<List<SpecialOffer>> getHomepageSpecialOffers() async {
    final response = await get('/api/special-offers/homepage');
    
    if (response['success'] == true) {
      final offersData = response['offers'] as List;
      return offersData.map((json) => SpecialOffer.fromJson(json)).toList();
    }
    
    return [];
  }

  // ============================================================================
  // ORDERS
  // ============================================================================

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    return await post('/api/orders', orderData);
  }

  Future<Map<String, dynamic>> getOrders() async {
    return await get('/api/orders');
  }

  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    return await get('/api/orders/$orderId');
  }

  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    return await put('/api/orders/$orderId/status', {'status': status});
  }

  // ============================================================================
  // CART
  // ============================================================================

  Future<Map<String, dynamic>> getCart() async {
    return await get('/api/cart');
  }

  Future<Map<String, dynamic>> addToCart(Map<String, dynamic> cartItem) async {
    return await post('/api/cart/add', cartItem);
  }

  Future<Map<String, dynamic>> updateCartItem(String itemId, int quantity) async {
    return await put('/api/cart/$itemId', {'quantity': quantity});
  }

  Future<Map<String, dynamic>> removeFromCart(String itemId) async {
    return await delete('/api/cart/$itemId');
  }

  Future<Map<String, dynamic>> clearCart() async {
    return await delete('/api/cart/clear');
  }

  // ============================================================================
  // NOTIFICATIONS
  // ============================================================================

  Future<Map<String, dynamic>> getNotifications() async {
    return await get('/api/notifications');
  }

  Future<Map<String, dynamic>> markNotificationAsRead(int notificationId) async {
    return await put('/api/notifications/$notificationId/read', {});
  }

  Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    return await put('/api/notifications/mark-all-read', {});
  }

  // ============================================================================
  // PROFILE
  // ============================================================================

  Future<Map<String, dynamic>> getProfile() async {
    return await get('/api/profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    return await put('/api/profile', profileData);
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return await put('/api/auth/change-password', {
      'current_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// Request OTP code for password change (Step 1)
  Future<Map<String, dynamic>> requestPasswordChangeCode(String oldPassword) async {
    return await post('/api/auth/request-password-change-code', {
      'old_password': oldPassword,
    });
  }

  /// Verify OTP and change password (Step 2)
  Future<Map<String, dynamic>> verifyAndChangePassword(String code, String newPassword) async {
    return await post('/api/auth/verify-and-change-password', {
      'verification_code': code,
      'new_password': newPassword,
    });
  }

  /// Request forgot password OTP (unauthenticated)
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await post('/api/auth/forgot-password', {
      'email': email,
    });
  }

  /// Verify forgot password OTP and reset password (unauthenticated)
  Future<Map<String, dynamic>> resetPassword(String email, String code, String password) async {
    return await post('/api/auth/forgot-password/verify', {
      'email': email,
      'code': code,
      'password': password,
    });
  }

  // ============================================================================
  // REVIEWS
  // ============================================================================

  Future<Map<String, dynamic>> getVendorReviews(String vendorId) async {
    return await get('/api/vendors/$vendorId/reviews');
  }

  Future<Map<String, dynamic>> submitReview(
    String vendorId,
    double rating,
    String comment,
    {String? orderId}
  ) async {
    return await post('/api/vendors/$vendorId/reviews', {
      'rating': rating,
      'comment': comment,
      if (orderId != null) 'order_id': orderId,
    });
  }

  Future<Map<String, dynamic>> markReviewHelpful(int reviewId) async {
    return await post('/api/reviews/$reviewId/helpful', {});
  }

  // ============================================================================
  // LOCATION & DELIVERY
  // ============================================================================

  Future<Map<String, dynamic>> calculateDeliveryFee({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    return await post('/api/delivery/calculate-fee', {
      'origin_lat': originLat,
      'origin_lng': originLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
    });
  }

  Future<Map<String, dynamic>> trackDelivery(String orderId) async {
    return await get('/api/deliveries/track/$orderId');
  }
}


