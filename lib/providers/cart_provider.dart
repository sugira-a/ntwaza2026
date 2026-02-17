// lib/providers/cart_provider.dart
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/vendor.dart';
import '../services/api/api_service.dart';

class CartItem {
  final Product product;
  final int quantity;
  final Map<String, ModifierOption>? selectedModifiers;
  final String vendorId;

  CartItem({
    required this.product,
    required this.quantity,
    required this.vendorId,
    this.selectedModifiers,
  });

  // Calculate total price including modifiers
  double get totalPrice {
    double modifierPrice = 0;
    if (selectedModifiers != null) {
      modifierPrice = selectedModifiers!.values.fold(
        0.0,
        (sum, modifier) => sum + modifier.priceAdjustment,
      );
    }
    return (product.price + modifierPrice) * quantity;
  }

  // Generate a unique key for cart items with different modifiers
  String get cartKey {
    if (selectedModifiers == null || selectedModifiers!.isEmpty) {
      return '${vendorId}_${product.id}';
    }
    
    final modifierKeys = selectedModifiers!.entries
        .map((e) => '${e.key}:${e.value.id}')
        .toList()
      ..sort();
    
    return '${vendorId}_${product.id}_${modifierKeys.join('_')}';
  }

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? vendorId,
    Map<String, ModifierOption>? selectedModifiers,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      vendorId: vendorId ?? this.vendorId,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  final ApiService _apiService;

  CartProvider(this._apiService);

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  
  double get totalPrice => _items.fold(
    0.0,
    (sum, item) => sum + item.totalPrice,
  );
  
  double get subtotal => totalPrice;
  
  bool get isEmpty => _items.isEmpty;
  
  // Get unique vendor IDs in cart
  Set<String> get vendorIds => _items.map((item) => item.vendorId).toSet();
  
  // Get items for a specific vendor
  List<CartItem> getItemsForVendor(String vendorId) {
    return _items.where((item) => item.vendorId == vendorId).toList();
  }

  void addToCart(
    Product product, {
    String? vendorId,
    Vendor? vendor,
    Map<String, ModifierOption>? selectedModifiers,
  }) {
    print('   🔹 CartProvider.addToCart() called');
    print('      - Product: ${product.name}');
    print('      - Vendor: ${vendor?.name ?? vendorId ?? "none"}');
    print('      - Modifiers: ${selectedModifiers?.length ?? 0}');
    
    final actualVendorId = vendor?.id ?? vendorId ?? product.vendorId;
    print('      - Actual vendor ID: $actualVendorId');
    
    addItem(
      product,
      quantity: 1,
      vendorId: actualVendorId,
      selectedModifiers: selectedModifiers,
    );
    
    print('      ✓ CartProvider.addToCart() completed');
  }

  void addItem(
    Product product, {
    int quantity = 1,
    required String vendorId,
    Map<String, ModifierOption>? selectedModifiers,
  }) {
    print('      🔸 CartProvider.addItem() called');
    print('         - Product: ${product.name}');
    print('         - Quantity: $quantity');
    print('         - Vendor ID: $vendorId');
    print('         - Modifiers: ${selectedModifiers?.length ?? 0}');

    // Create a temporary cart item to get the unique key
    final tempItem = CartItem(
      product: product,
      quantity: 0,
      vendorId: vendorId,
      selectedModifiers: selectedModifiers,
    );
    
    final cartKey = tempItem.cartKey;
    print('         - Cart key: $cartKey');

    // Find existing item with same product, vendor, and modifiers
    final existingIndex = _items.indexWhere(
      (item) => item.cartKey == cartKey,
    );
    
    print('         - Existing item index: $existingIndex');

    if (existingIndex >= 0) {
      print('         ♻️ Updating existing item');
      print('            Old quantity: ${_items[existingIndex].quantity}');
      print('            New quantity: ${_items[existingIndex].quantity + quantity}');
      
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + quantity,
      );
    } else {
      print('         ➕ Adding new item to cart');
      
      _items.add(CartItem(
        product: product,
        quantity: quantity,
        vendorId: vendorId,
        selectedModifiers: selectedModifiers,
      ));
      
      print('         ✓ New item added');
    }

    print('         📊 Cart now has ${_items.length} unique items');
    print('         📊 Total quantity: $itemCount');
    print('         📊 Vendors in cart: ${vendorIds.length}');
    print('         🔔 Calling notifyListeners()...');
    
    notifyListeners();
    
    print('         ✓ CartProvider.addItem() completed');
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void removeCartItem(CartItem cartItem) {
    _items.removeWhere((item) => item.cartKey == cartItem.cartKey);
    notifyListeners();
  }

  void removeFromCart(String productId) {
    final existingIndex = _items.indexWhere((item) => item.product.id == productId);
    
    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: _items[existingIndex].quantity - 1,
        );
      } else {
        _items.removeAt(existingIndex);
      }
      
      notifyListeners();
    }
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: quantity);
      notifyListeners();
    }
  }

  void updateCartItemQuantity(CartItem cartItem, int quantity) {
    if (quantity <= 0) {
      removeCartItem(cartItem);
      return;
    }

    final index = _items.indexWhere((item) => item.cartKey == cartItem.cartKey);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: quantity);
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void clearCart() {
    clear();
  }
  
  // Clear items for specific vendor
  void clearVendorItems(String vendorId) {
    _items.removeWhere((item) => item.vendorId == vendorId);
    notifyListeners();
  }

  // FIXED: Removed dummy Product creation with undefined 'vendor'
  int getItemQuantity(String productId) {
    final item = _items.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => CartItem(
        product: Product(
          id: '',
          name: '',
          description: '',
          price: 0,
          imageUrl: '',
          category: '',
          isAvailable: true,
          vendorId: '0', // FIXED: Use '0' instead of undefined vendor.id
        ),
        quantity: 0,
        vendorId: '0', // FIXED: Use '0' as default vendorId
      ),
    );
    return item.quantity;
  }
}