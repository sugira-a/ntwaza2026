// lib/screens/cart/cart_screen.dart
import 'package:flutter/material.dart';
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

  // ── Modern Card wrapper (matches checkout) ──
  Widget _buildModernCard({required Color cardColor, required bool isDarkMode, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  // ── Price row (matches checkout) ──
  Widget _buildPriceRowCompact(String label, double amount, Color textColor, Color subtextColor, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? textColor : subtextColor,
          ),
        ),
        Text(
          'RWF ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF8F9FA);
    final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          'My Cart',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.isEmpty) {
            return _buildEmptyCart(textColor, subtextColor, isDarkMode, cardColor);
          }

          final selectedSubtotal = _getSelectedSubtotal();
          final deliveryFee = _getTotalDeliveryFee();
          final total = selectedSubtotal + deliveryFee;
          final allSelected = _selectedItems.length == cart.itemCount;

          return Column(
            children: [
              // Cart items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  children: [
                    // Select All card
                    _buildModernCard(
                      cardColor: cardColor,
                      isDarkMode: isDarkMode,
                      child: InkWell(
                        onTap: _toggleSelectAll,
                        borderRadius: BorderRadius.circular(10),
                        child: Row(
                          children: [
                            _buildCheckbox(allSelected, isDarkMode, subtextColor),
                            const SizedBox(width: 12),
                            Text(
                              'Select All',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            if (_getSelectedItemCount() > 0)
                              Text(
                                '${_getSelectedItemCount()} selected',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: subtextColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Cart items grouped by vendor
                    ...cart.vendorIds.map((vendorId) {
                      final items = cart.getItemsForVendor(vendorId);
                      final vendor = _vendorCache[vendorId];
                      final vendorName = vendor?.name ?? 'Vendor';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildVendorSection(
                          vendorId,
                          items,
                          vendor,
                          vendorName,
                          textColor,
                          subtextColor,
                          isDarkMode,
                          cardColor,
                          cart,
                        ),
                      );
                    }),

                    // Spacer for bottom bar
                    const SizedBox(height: 100),
                  ],
                ),
              ),

              // Bottom checkout bar
              _buildCheckoutBar(
                selectedSubtotal,
                deliveryFee,
                total,
                textColor,
                subtextColor,
                isDarkMode,
                cardColor,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCheckbox(bool isChecked, bool isDarkMode, Color subtextColor) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isChecked
            ? const Color(0xFF2E7D32)
            : Colors.transparent,
        border: Border.all(
          color: isChecked
              ? const Color(0xFF2E7D32)
              : subtextColor.withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: isChecked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }

  Widget _buildEmptyCart(Color textColor, Color subtextColor, bool isDarkMode, Color cardColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey[900]!.withOpacity(0.5)
                    : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart,
                size: 64,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse restaurants and markets to\nadd items to your cart',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subtextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                child: const Text(
                  'Start Shopping',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
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
    Color cardColor,
    CartProvider cart,
  ) {
    final deliveryFee = vendor?.deliveryFee ?? 2000;

    return _buildModernCard(
      cardColor: cardColor,
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor header
          Row(
            children: [
              Expanded(
                child: Text(
                  vendorName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Delivery: RWF ${deliveryFee.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: subtextColor,
                ),
              ),
            ],
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            ),
          ),

          // Items from this vendor
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _isItemSelected(item.cartKey);
            final isLast = index == items.length - 1;

            return _buildCartItem(
              item,
              vendorId,
              isSelected,
              vendorName,
              textColor,
              subtextColor,
              isDarkMode,
              cart,
              isLast: isLast,
            );
          }),
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
    CartProvider cart, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () => _toggleItemSelection(item.cartKey),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkbox
                _buildCheckbox(isSelected, isDarkMode, subtextColor),
                const SizedBox(width: 10),

                // Product image
                GestureDetector(
                  onTap: () => _openProductDetail(item, vendorId),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.product.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.fastfood_rounded,
                          color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.selectedModifiers != null &&
                          item.selectedModifiers!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.selectedModifiers!.values.map((m) => m.name).join(', '),
                          style: TextStyle(
                            fontSize: 10,
                            color: subtextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'RWF ${item.totalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const Spacer(),
                          _buildQuantityControls(item, cart, isDarkMode, textColor, subtextColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: isDarkMode ? const Color(0xFF252525) : Colors.grey[100],
          ),
      ],
    );
  }

  Widget _buildQuantityControls(
    CartItem item,
    CartProvider cart,
    bool isDarkMode,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrease / delete
          InkWell(
            onTap: () {
              if (item.quantity > 1) {
                cart.updateCartItemQuantity(item, item.quantity - 1);
              } else {
                cart.removeCartItem(item);
                setState(() {
                  _selectedItems.remove(item.cartKey);
                });
              }
            },
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                item.quantity > 1 ? Icons.remove_rounded : Icons.delete_outline_rounded,
                size: 16,
                color: item.quantity > 1 ? textColor : Colors.red[400],
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            alignment: Alignment.center,
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          // Increase
          InkWell(
            onTap: () {
              cart.updateCartItemQuantity(item, item.quantity + 1);
            },
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.add_rounded, size: 16, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(
    double subtotal,
    double deliveryFees,
    double total,
    Color textColor,
    Color subtextColor,
    bool isDarkMode,
    Color cardColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPriceRowCompact('Subtotal', subtotal, textColor, subtextColor, false),
              const SizedBox(height: 8),
              _buildPriceRowCompact('Delivery', deliveryFees, textColor, subtextColor, false),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              ),
              const SizedBox(height: 10),
              _buildPriceRowCompact('Total', total, textColor, subtextColor, true),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _getSelectedItemCount() > 0 ? _proceedToCheckout : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Checkout (${_getSelectedItemCount()} item${_getSelectedItemCount() != 1 ? 's' : ''})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}