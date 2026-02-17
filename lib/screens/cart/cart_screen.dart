// lib/screens/cart/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cart_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/vendor.dart';
import '../vendor/widgets/product_detail_modal.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Set<String> _selectedItems = {};
  final Map<String, Vendor?> _vendorCache = {};
  int _selectedNavIndex = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSelections();
      _loadVendorDetails();
    });
  }

  void _initializeSelections() {
    final cart = context.read<CartProvider>();
    
    setState(() {
      _selectedItems.clear();
      for (var vendorId in cart.vendorIds) {
        final items = cart.getItemsForVendor(vendorId);
        for (var item in items) {
          _selectedItems.add(item.cartKey);
        }
      }
    });
  }

  Future<void> _loadVendorDetails() async {
    final cart = context.read<CartProvider>();
    final vendorProvider = context.read<VendorProvider>();
    
    for (var vendorId in cart.vendorIds) {
      final vendor = vendorProvider.vendors.firstWhere(
        (v) => v.id == vendorId,
        orElse: () => Vendor(
          id: vendorId,
          name: 'Vendor',
          category: 'Food',
          logoUrl: '',
          rating: 0,
          totalRatings: 0,
          latitude: null,
          longitude: null,
          prepTimeMinutes: 30,
          deliveryFee: 2000,
        ),
      );
      
      _vendorCache[vendorId] = vendor;
    }
    
    if (mounted) setState(() {});
  }

  void _toggleSelectAll() {
    final cart = context.read<CartProvider>();
    final totalItems = cart.itemCount;
    
    setState(() {
      if (_selectedItems.length == totalItems) {
        _selectedItems.clear();
      } else {
        _selectedItems.clear();
        for (var vendorId in cart.vendorIds) {
          final items = cart.getItemsForVendor(vendorId);
          for (var item in items) {
            _selectedItems.add(item.cartKey);
          }
        }
      }
    });
  }

  void _toggleItemSelection(String itemKey) {
    setState(() {
      if (_selectedItems.contains(itemKey)) {
        _selectedItems.remove(itemKey);
      } else {
        _selectedItems.add(itemKey);
      }
    });
  }

  bool _isItemSelected(String itemKey) {
    return _selectedItems.contains(itemKey);
  }

  double _getSelectedSubtotal() {
    final cart = context.read<CartProvider>();
    double total = 0;
    
    for (var vendorId in cart.vendorIds) {
      final items = cart.getItemsForVendor(vendorId);
      for (var item in items) {
        if (_isItemSelected(item.cartKey)) {
          total += item.totalPrice;
        }
      }
    }
    
    return total;
  }

  int _getSelectedItemCount() {
    final cart = context.read<CartProvider>();
    int count = 0;
    
    for (var vendorId in cart.vendorIds) {
      final items = cart.getItemsForVendor(vendorId);
      for (var item in items) {
        if (_isItemSelected(item.cartKey)) {
          count += item.quantity;
        }
      }
    }
    
    return count;
  }

  Set<String> _getSelectedVendorIds() {
    final cart = context.read<CartProvider>();
    final Set<String> vendorIds = {};
    
    for (var vendorId in cart.vendorIds) {
      final items = cart.getItemsForVendor(vendorId);
      for (var item in items) {
        if (_isItemSelected(item.cartKey)) {
          vendorIds.add(vendorId);
          break;
        }
      }
    }
    
    return vendorIds;
  }

  double _getTotalDeliveryFee() {
    double total = 0;
    final selectedVendors = _getSelectedVendorIds();
    
    for (var vendorId in selectedVendors) {
      final vendor = _vendorCache[vendorId];
      total += vendor?.deliveryFee ?? 2000;
    }
    
    return total;
  }

  void _proceedToCheckout() {
    // Check if user is logged in
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Please log in to proceed with checkout'),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    final selectedItemCount = _getSelectedItemCount();
    
    if (selectedItemCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to checkout'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    final selectedData = <String, List<String>>{};
    
    for (var vendorId in cart.vendorIds) {
      final items = cart.getItemsForVendor(vendorId);
      final selectedKeys = items
          .where((item) => _selectedItems.contains(item.cartKey))
          .map((item) => item.cartKey)
          .toList();
      
      if (selectedKeys.isNotEmpty) {
        selectedData[vendorId] = selectedKeys;
      }
    }

    context.push('/checkout', extra: selectedData);
  }

  void _openProductDetail(CartItem item, String vendorId) {
    final vendor = _vendorCache[vendorId];
    if (vendor != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ProductDetailModal(
          product: item.product,
          vendor: vendor,
        ),
      );
    }
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedNavIndex = index);
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/');
        break;
      case 2:
        context.go('/');
        break;
      case 3:
        // Already on cart
        break;
      case 4:
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isAuthenticated) {
          context.push('/profile');
        }
        break;
    }
  }

  Widget _buildNavItem(IconData outlinedIcon, IconData filledIcon, String label, int index, Color textColor, Color subtextColor) {
    final isSelected = _selectedNavIndex == index;
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    
    return InkWell(
      onTap: () => _onNavItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected ? (isDarkMode ? Colors.black : Colors.black) : subtextColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? (isDarkMode ? Colors.black : Colors.black) : subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          'My Cart',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.isEmpty) {
            return _buildEmptyCart(textColor, subtextColor, isDarkMode);
          }

          final selectedSubtotal = _getSelectedSubtotal();
          final deliveryFee = _getTotalDeliveryFee();
          final total = selectedSubtotal + deliveryFee;
          final allSelected = _selectedItems.length == cart.itemCount;

          return Column(
            children: [
              // Select All header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                child: InkWell(
                  onTap: _toggleSelectAll,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: allSelected 
                              ? (isDarkMode ? Colors.white : Colors.black)
                              : Colors.transparent,
                          border: Border.all(
                            color: allSelected 
                                ? (isDarkMode ? Colors.white : Colors.black)
                                : subtextColor,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: allSelected
                            ? Icon(
                                Icons.check,
                                color: isDarkMode ? Colors.black : Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select All',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      if (_getSelectedItemCount() > 0)
                        Text(
                          '${_getSelectedItemCount()} selected',
                          style: TextStyle(
                            fontSize: 14,
                            color: subtextColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Cart items grouped by vendor
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cart.vendorIds.length,
                  itemBuilder: (context, index) {
                    final vendorId = cart.vendorIds.elementAt(index);
                    final items = cart.getItemsForVendor(vendorId);
                    final vendor = _vendorCache[vendorId];
                    final vendorName = vendor?.name ?? 'Vendor';

                    return _buildVendorSection(
                      vendorId,
                      items,
                      vendor,
                      vendorName,
                      textColor,
                      subtextColor,
                      isDarkMode,
                      cart,
                    );
                  },
                ),
              ),

              // Checkout section
              _buildCheckoutSection(
                selectedSubtotal,
                deliveryFee,
                total,
                textColor,
                subtextColor,
                isDarkMode,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final isDarkMode = themeProvider.isDarkMode;
          final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
          final textColor = isDarkMode ? Colors.white : Colors.black;
          final subtextColor = isDarkMode ? Colors.grey[500]! : Colors.grey[600]!;

          return Container(
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0, textColor, subtextColor),
                    _buildNavItem(Icons.restaurant_outlined, Icons.restaurant, 'Restaurants', 1, textColor, subtextColor),
                    _buildNavItem(Icons.shopping_bag_outlined, Icons.shopping_bag, 'Markets', 2, textColor, subtextColor),
                    _buildNavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Cart', 3, textColor, subtextColor),
                    _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 4, textColor, subtextColor),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(Color textColor, Color subtextColor, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 120,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add items to get started',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: subtextColor,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  context.go('/');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white, width: 1.5),
                ),
                elevation: 0,
              ),
              child: Text(
                'Continue Shopping',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorSection(
    String vendorId,
    List<CartItem> items,
    Vendor? vendor,
    String vendorName,
    Color textColor,
    Color subtextColor,
    bool isDarkMode,
    CartProvider cart,
  ) {
    final deliveryFee = vendor?.deliveryFee ?? 2000;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.store, size: 16, color: subtextColor),
                const SizedBox(width: 8),
                Text(
                  vendorName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Delivery: RWF ${deliveryFee.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ),

          // Items from this vendor
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = _isItemSelected(item.cartKey);

              return _buildCartItem(
                item,
                vendorId,
                isSelected,
                vendorName,
                textColor,
                subtextColor,
                isDarkMode,
                cart,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(
    CartItem item,
    String vendorId,
    bool isSelected,
    String vendorName,
    Color textColor,
    Color subtextColor,
    bool isDarkMode,
    CartProvider cart,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: InkWell(
        onTap: () => _toggleItemSelection(item.cartKey),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (isDarkMode ? Colors.white : Colors.black)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected 
                        ? (isDarkMode ? Colors.white : Colors.black)
                        : subtextColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: isDarkMode ? Colors.black : Colors.white,
                        size: 14,
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Product image
              GestureDetector(
                onTap: () => _openProductDetail(item, vendorId),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.product.imageUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 70,
                      height: 70,
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(
                        Icons.fastfood,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _openProductDetail(item, vendorId),
                      child: Text(
                        item.product.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.selectedModifiers != null &&
                        item.selectedModifiers!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.selectedModifiers!.values.map((m) => m.name).join(', '),
                        style: TextStyle(
                          fontSize: 11,
                          color: subtextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'RWF ${item.totalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        _buildQuantityControls(item, cart, isDarkMode, textColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControls(
      CartItem item, CartProvider cart, bool isDarkMode, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              item.quantity > 1 ? Icons.remove : Icons.delete_outline,
              size: 18,
              color: item.quantity > 1 ? textColor : Colors.red,
            ),
            onPressed: () {
              if (item.quantity > 1) {
                cart.updateCartItemQuantity(item, item.quantity - 1);
              } else {
                cart.removeCartItem(item);
                setState(() {
                  _selectedItems.remove(item.cartKey);
                });
              }
            },
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 18, color: textColor),
            onPressed: () {
              cart.updateCartItemQuantity(item, item.quantity + 1);
            },
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection(
    double subtotal,
    double deliveryFees,
    double total,
    Color textColor,
    Color subtextColor,
    bool isDarkMode,
  ) {
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'RWF ${subtotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delivery Fee',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'RWF ${deliveryFees.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'RWF ${total.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Checkout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _getSelectedItemCount() > 0 ? _proceedToCheckout : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Checkout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}