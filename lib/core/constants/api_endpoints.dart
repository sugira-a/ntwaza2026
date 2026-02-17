// lib/core/constants/api_endpoints.dart
class ApiEndpoints {
  // Base URL
  static const String baseUrl = 'http://localhost:5000';
  
  // Auth endpoints
  static const String login = '$baseUrl/api/auth/login';
  static const String register = '$baseUrl/api/auth/register';
  static const String logout = '$baseUrl/api/auth/logout';
  static const String verifyToken = '$baseUrl/api/auth/verify';
  
  // Vendor endpoints
  static const String vendors = '$baseUrl/api/vendors';
  static String vendorById(String id) => '$baseUrl/api/vendors/$id';
  static String vendorProducts(String id) => '$baseUrl/api/vendors/$id/products';
  static const String vendorsByCategory = '$baseUrl/api/vendors/category';
  
  // Product endpoints
  static const String products = '$baseUrl/api/products';
  static String productById(String id) => '$baseUrl/api/products/$id';
  static const String productsByVendor = '$baseUrl/api/products/vendor';
  static const String searchProducts = '$baseUrl/api/products/search';
  
  // Order endpoints
  static const String orders = '$baseUrl/api/orders';
  static String orderById(String id) => '$baseUrl/api/orders/$id';
  static const String myOrders = '$baseUrl/api/orders/my-orders';
  static String updateOrderStatus(String id) => '$baseUrl/api/orders/$id/status';
  
  // Pickup Order endpoints
  static const String pickupOrders = '$baseUrl/api/pickup-orders';
  static String pickupOrderById(String id) => '$baseUrl/api/pickup-orders/$id';
  static String customerPickupOrders(String customerId) => '$baseUrl/api/pickup-orders/customer/$customerId';
  static String riderPickupOrders(String riderId) => '$baseUrl/api/pickup-orders/rider/$riderId';
  
  // Cart endpoints
  static const String cart = '$baseUrl/api/cart';
  static const String addToCart = '$baseUrl/api/cart/add';
  static const String updateCart = '$baseUrl/api/cart/update';
  static const String removeFromCart = '$baseUrl/api/cart/remove';
  static const String clearCart = '$baseUrl/api/cart/clear';
  
  // Special offers endpoints
  static const String specialOffers = '$baseUrl/api/special-offers';
  static const String homepageOffers = '$baseUrl/api/special-offers/homepage';
  
  // Search endpoints
  static const String unifiedSearch = '$baseUrl/api/search';
  
  // Google Maps API Key - loaded from EnvConfig (build-time injection)
  // Use EnvConfig.googleMapsApiKey instead of this constant
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_ANDROID_KEY');
  
  // Location endpoints
  static const String calculateDistance = '$baseUrl/api/location/distance';
  
  // User profile endpoints
  static const String profile = '$baseUrl/api/users/profile';
  static const String updateProfile = '$baseUrl/api/users/profile/update';
  static const String addresses = '$baseUrl/api/users/addresses';
  
  // Static files
  static String offerImage(String filename) => '$baseUrl/static/uploads/offers/$filename';
  static String productImage(String filename) => '$baseUrl/static/uploads/products/$filename';
  static String vendorLogo(String filename) => '$baseUrl/static/uploads/vendors/$filename';
  
  // Helper method to log configuration
  static void logCurrentConfig() {
    print('🌐 API Configuration:');
    print('   Base URL: $baseUrl');
    print('   Auth: $login');
    print('   Vendors: $vendors');
  }
}