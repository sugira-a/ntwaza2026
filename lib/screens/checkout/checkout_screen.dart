// lib/screens/checkout/checkout_screen_v2.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cart_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/special_offer_provider.dart';
import '../../services/api/api_service.dart';
import '../../models/vendor.dart';
import '../../models/delivery_address.dart';
import '../../models/special_offer.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, List<String>>? selectedItems;
  const CheckoutScreen({super.key, this.selectedItems});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _paymentMethod = 'cash';
  final Map<String, Vendor?> _vendorCache = {};
  bool _isProcessing = false;
  bool _isRecalculatingFees = false;
  
  // Promo code state
  bool _isValidatingPromo = false;
  String? _appliedPromoCode;
  int? _appliedOfferId;
  double _promoDiscount = 0.0;
  String? _promoMessage;
  bool _promoSuccess = false;
  
  List<SpecialOffer> _availablePromoCodes = [];
  
  // Delivery contact preference
  String _deliveryContactMethod = 'call'; // 'call' or 'message'

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadVendorDetails();
    _loadAvailablePromoCodes();
    _autoFillDeliveryAddress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addressProvider = context.read<AddressProvider>();
      addressProvider.addListener(_onAddressChanged);
    });
  }

  /// Auto-fill delivery address with default or most recent address
  void _autoFillDeliveryAddress() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final addressProvider = context.read<AddressProvider>();
      
      // If no address is selected, auto-select one
      if (addressProvider.selectedAddress == null) {
        // First, try to use the default address
        if (addressProvider.defaultAddress != null) {
          addressProvider.selectAddress(addressProvider.defaultAddress!);
          _updateVendorsForAddress(addressProvider.defaultAddress!);
        } 
        // Otherwise, use the most recent address
        else if (addressProvider.recentAddresses.isNotEmpty) {
          final recentAddress = addressProvider.recentAddresses.first;
          addressProvider.selectAddress(recentAddress);
          _updateVendorsForAddress(recentAddress);
        }
      } else {
        // Ensure delivery fees are calculated for selected address
        _updateVendorsForAddress(addressProvider.selectedAddress!);
      }
    });
  }

  /// Update vendors based on selected address
  Future<void> _updateVendorsForAddress(DeliveryAddress address) async {
    if (!mounted) return;
    setState(() => _isRecalculatingFees = true);
    try {
      final vendorProvider = context.read<VendorProvider>();
      vendorProvider.setDeliveryAddress(address);
      await vendorProvider.fetchVendors();
      await _loadVendorDetails();
    } catch (e) {
      print('Error updating vendors: $e');
    } finally {
      if (mounted) setState(() => _isRecalculatingFees = false);
    }
  }

  @override
  void dispose() {
    final addressProvider = context.read<AddressProvider>();
    addressProvider.removeListener(_onAddressChanged);
    _phoneController.dispose();
    _notesController.dispose();
    _promoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    if (mounted) setState(() {});
  }

  void _loadUserData() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated && auth.user != null) {
      _phoneController.text = auth.user!.phone ?? '';
    }
  }

  Future<void> _loadAvailablePromoCodes() async {
    try {
      final offerProvider = context.read<SpecialOfferProvider>();
      await offerProvider.fetchSpecialOffers(activeOnly: true);
      setState(() {
        _availablePromoCodes = offerProvider.activeOffers
            .where((offer) => 
                offer.promoCode != null && 
                offer.promoCode!.isNotEmpty &&
                offer.isCurrentlyValid)
            .toList();
      });
    } catch (e) {
      print('Error loading promo codes: $e');
    }
  }

  Future<void> _loadVendorDetails() async {
    final cart = context.read<CartProvider>();
    final vendorProvider = context.read<VendorProvider>();
    _vendorCache.clear();
    for (var vendorId in cart.vendorIds) {
      try {
        final vendor = vendorProvider.vendors.firstWhere((v) => v.id == vendorId);
        _vendorCache[vendorId] = vendor;
      } catch (e) {
        continue;
      }
    }
    if (mounted) setState(() {});
  }

  List<CartItem> _getSelectedItems() {
    final cart = context.read<CartProvider>();
    if (widget.selectedItems == null) return cart.items;
    List<CartItem> selected = [];
    for (var entry in widget.selectedItems!.entries) {
      final vendorId = entry.key;
      final cartKeys = entry.value;
      final vendorItems = cart.getItemsForVendor(vendorId);
      for (var item in vendorItems) {
        if (cartKeys.contains(item.cartKey)) selected.add(item);
      }
    }
    return selected;
  }

  double _calculateSubtotal() => _getSelectedItems().fold(0.0, (sum, item) => sum + item.totalPrice);

  double _calculateDeliveryFee() {
    double total = 0;
    final selectedVendors = <String>{};
    for (var item in _getSelectedItems()) {
      selectedVendors.add(item.vendorId);
    }
    for (var vendorId in selectedVendors) {
      final vendor = _vendorCache[vendorId];
      if (vendor != null) total += vendor.deliveryFee;
    }
    return total;
  }

  double _getVendorDeliveryFee(String vendorId) {
    final vendor = _vendorCache[vendorId];
    return vendor?.deliveryFee ?? 0;
  }

  double _calculateTotal() => _calculateSubtotal() + _calculateDeliveryFee() - _promoDiscount;

  /// Validate and apply a promo code
  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _promoMessage = 'Please enter a promo code';
        _promoSuccess = false;
      });
      return;
    }

    setState(() => _isValidatingPromo = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final apiService = ApiService();
      if (authProvider.token != null) {
        apiService.setToken(authProvider.token);
      }

      final subtotal = _calculateSubtotal();
      final selectedItems = _getSelectedItems();
      String? vendorId;
      if (selectedItems.isNotEmpty) {
        vendorId = selectedItems.first.vendorId;
      }

      final response = await apiService.post('/api/promo/validate', {
        'promo_code': code,
        'subtotal': subtotal,
        'vendor_id': vendorId,
      });

      if (response['success'] == true) {
        setState(() {
          _appliedPromoCode = response['promo_code'];
          _appliedOfferId = response['offer']?['id'];
          _promoDiscount = (response['discount_amount'] as num).toDouble();
          _promoMessage = response['message'];
          _promoSuccess = true;
        });
      } else {
        setState(() {
          _promoMessage = response['message'] ?? 'Invalid promo code';
          _promoSuccess = false;
          _promoDiscount = 0.0;
          _appliedPromoCode = null;
          _appliedOfferId = null;
        });
      }
    } catch (e) {
      setState(() {
        _promoMessage = 'Failed to validate promo code';
        _promoSuccess = false;
        _promoDiscount = 0.0;
        _appliedPromoCode = null;
        _appliedOfferId = null;
      });
    } finally {
      setState(() => _isValidatingPromo = false);
    }
  }

  void _removePromoCode() {
    setState(() {
      _promoController.clear();
      _appliedPromoCode = null;
      _appliedOfferId = null;
      _promoDiscount = 0.0;
      _promoMessage = null;
      _promoSuccess = false;
    });
  }

  void _navigateToLocationPicker() async {
    final result = await context.push('/location-picker');
    if (result != null && result is DeliveryAddress) {
      final addressProvider = context.read<AddressProvider>();
      final vendorProvider = context.read<VendorProvider>();
      try {
        if (mounted) setState(() => _isRecalculatingFees = true);
        await addressProvider.addAddress(result);
        addressProvider.selectAddress(result);
        vendorProvider.setDeliveryAddress(result);
        await vendorProvider.fetchVendors();
        await Future.delayed(const Duration(milliseconds: 200));
        await _loadVendorDetails();
        if (mounted) setState(() => _isRecalculatingFees = false);
        final deliveryFee = _calculateDeliveryFee();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Address saved • Delivery: RWF ${deliveryFee.toStringAsFixed(0)}'),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) setState(() => _isRecalculatingFees = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✗ $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
          );
        }
      }
    }
  }

  void _showSavedAddresses() {
    final addressProvider = context.read<AddressProvider>();
    
    // Sort addresses: most recently used first
    final sortedAddresses = List<DeliveryAddress>.from(addressProvider.savedAddresses)
      ..sort((a, b) {
        if (a.lastUsedAt == null && b.lastUsedAt == null) return 0;
        if (a.lastUsedAt == null) return 1;
        if (b.lastUsedAt == null) return -1;
        return b.lastUsedAt!.compareTo(a.lastUsedAt!);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 24, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 12),
                    const Text('Saved Addresses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToLocationPicker();
                      },
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2E7D32)),
                      tooltip: 'Add New',
                    ),
                  ],
                ),
              ),
              if (sortedAddresses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Icon(Icons.location_off_outlined, size: 72, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No saved addresses',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first delivery address',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: sortedAddresses.length,
                    itemBuilder: (context, index) {
                      final address = sortedAddresses[index];
                      final isSelected = addressProvider.selectedAddress?.id == address.id;
                      return Dismissible(
                        key: Key(address.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Address'),
                              content: Text('Are you sure you want to delete "${address.label ?? address.shortAddress}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        onDismissed: (direction) {
                          addressProvider.deleteAddress(address.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deleted ${address.label ?? address.shortAddress}'),
                              backgroundColor: Colors.red[700],
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF0A0A0A) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                address.label == 'Home'
                                    ? Icons.home_rounded
                                    : address.label == 'Work'
                                        ? Icons.work_rounded
                                        : Icons.location_on_rounded,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                            ),
                            title: Text(
                              address.label ?? address.shortAddress,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  address.shortAddress,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (address.lastUsedAt != null && index < 3) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.history, size: 12, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Recently used',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24)
                                else
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Address'),
                                          content: Text('Are you sure you want to delete "${address.label ?? address.shortAddress}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      ) ?? false;
                                      if (confirm) {
                                        addressProvider.deleteAddress(address.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Deleted ${address.label ?? address.shortAddress}'),
                                            backgroundColor: Colors.red[700],
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              if (mounted) setState(() => _isRecalculatingFees = true);
                              addressProvider.selectAddress(address);
                              final vendorProvider = context.read<VendorProvider>();
                              vendorProvider.setDeliveryAddress(address);
                              await vendorProvider.fetchVendors();
                              await _loadVendorDetails();
                              if (mounted) setState(() => _isRecalculatingFees = false);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _placeOrder() async {
    final addressProvider = context.read<AddressProvider>();
    if (addressProvider.selectedAddress == null) {
      _showError('Please select a delivery address');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    setState(() => _isProcessing = true);
    try {
      await addressProvider.markAddressAsUsed(addressProvider.selectedAddress!.id);
      final selectedItems = _getSelectedItems();
      final itemsByVendor = <String, List<CartItem>>{};
      for (var item in selectedItems) {
        itemsByVendor.putIfAbsent(item.vendorId, () => []).add(item);
      }
      final authProvider = context.read<AuthProvider>();
      final apiService = ApiService();
      if (authProvider.token != null) {
        apiService.setToken(authProvider.token);
      } else {
        throw Exception('No authentication token available');
      }
      final List<String> orderIds = [];
      for (var entry in itemsByVendor.entries) {
        final vendorId = entry.key;
        final items = entry.value;
        final orderItems = items.map((item) => {
          'product_id': item.product.id,
          'quantity': item.quantity,
          'price': item.product.price,
          'modifiers': item.selectedModifiers?.values.map((m) => {
            'id': m.id,
            'name': m.name,
            'price': m.priceAdjustment,
          }).toList() ?? [],
        }).toList();
        final subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
        final deliveryFee = _getVendorDeliveryFee(vendorId);
        final totalSubtotal = _calculateSubtotal();
        final vendorDiscountShare = totalSubtotal > 0 ? (subtotal / totalSubtotal) * _promoDiscount : 0.0;
        final total = subtotal + deliveryFee - vendorDiscountShare;
        final orderData = {
          'vendor_id': vendorId,
          'items': orderItems,
          'delivery_address': {
            'latitude': addressProvider.selectedAddress!.latitude,
            'longitude': addressProvider.selectedAddress!.longitude,
            'address': addressProvider.selectedAddress!.fullAddress,
            'label': addressProvider.selectedAddress!.label,
            'additional_info': addressProvider.selectedAddress!.additionalInfo,
          },
          'phone': _phoneController.text.trim(),
          'notes': _notesController.text.trim(),
          'payment_method': _paymentMethod,
          'delivery_contact_method': _deliveryContactMethod,
          'subtotal': subtotal,
          'delivery_fee': deliveryFee,
          'discount': vendorDiscountShare,
          'total': total,
          if (_appliedPromoCode != null) 'promo_code': _appliedPromoCode,
          if (_appliedOfferId != null) 'special_offer_id': _appliedOfferId,
        };
        final response = await apiService.post('/api/orders/direct', orderData);
        if (response['success'] == true) {
          orderIds.add(response['order']['id'].toString());
        } else {
          throw Exception(response['error'] ?? 'Failed to create order');
        }
      }
      final cart = context.read<CartProvider>();
      for (var item in selectedItems) {
        cart.removeCartItem(item);
      }
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${orderIds.length} order${orderIds.length > 1 ? 's' : ''} placed successfully!'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/');
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to place order: ${e.toString().replaceAll('Exception:', '').trim()}');
      }
    } finally {
      if (mounted && _isProcessing) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700], duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final addressProvider = context.watch<AddressProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF8F9FA);
    final cardColor = isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFFAFAFA);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    
    final selectedItems = _getSelectedItems();
    final subtotal = _calculateSubtotal();
    final deliveryFee = _calculateDeliveryFee();
    final total = _calculateTotal();
    
    final itemsByVendor = <String, List<CartItem>>{};
    for (var item in selectedItems) {
      itemsByVendor.putIfAbsent(item.vendorId, () => []).add(item);
    }
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : context.go('/cart'),
        ),
        title: Text('Checkout', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: false,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                children: [
                // Delivery Address Section
                _buildModernCard(
                  cardColor: cardColor,
                  isDarkMode: isDarkMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.location_on_rounded, color: Color(0xFF2E7D32), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text('Delivery Address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (addressProvider.selectedAddress != null)
                        _buildSelectedAddressCompact(addressProvider.selectedAddress!, textColor, subtextColor, isDarkMode)
                      else
                        _buildNoAddressCompact(textColor, subtextColor, isDarkMode),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Order Summary
                _buildModernCard(
                  cardColor: cardColor,
                  isDarkMode: isDarkMode,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFF6366F1), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order Summary', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                            const SizedBox(height: 2),
                            Text('${selectedItems.length} item${selectedItems.length > 1 ? 's' : ''}', 
                              style: TextStyle(fontSize: 10, color: subtextColor)),
                          ],
                        ),
                      ),
                      Text('RWF ${subtotal.toStringAsFixed(0)}', 
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Promo Code Input (always show for manual entry)
                _buildModernCard(
                  cardColor: cardColor,
                  isDarkMode: isDarkMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC4899).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.discount_rounded, color: Color(0xFFEC4899), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text('Promo Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_appliedPromoCode == null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _promoController,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12),
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'Enter code',
                                  hintStyle: TextStyle(color: subtextColor.withOpacity(0.4), fontWeight: FontWeight.normal, letterSpacing: 0, fontSize: 12),
                                  filled: true,
                                  fillColor: backgroundColor,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: const Color(0xFF2E7D32), width: 1.5),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 38,
                              child: ElevatedButton(
                                onPressed: _isValidatingPromo ? null : _applyPromoCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  disabledBackgroundColor: Colors.grey[400],
                                ),
                                child: _isValidatingPromo
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                        if (_promoMessage != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                _promoSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                size: 16,
                                color: _promoSuccess ? const Color(0xFF2E7D32) : Colors.red[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _promoMessage!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _promoSuccess ? const Color(0xFF2E7D32) : Colors.red[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.5), width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _appliedPromoCode!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Color(0xFF2E7D32),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'You save RWF ${_promoDiscount.toStringAsFixed(0)}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _removePromoCode,
                                icon: Icon(Icons.close_rounded, color: Colors.red[700], size: 22),
                                tooltip: 'Remove',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Contact Information
                _buildModernCard(
                  cardColor: cardColor,
                  isDarkMode: isDarkMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.phone_rounded, color: Color(0xFF3B82F6), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text('Contact Information', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 12),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Phone Number',
                          hintStyle: TextStyle(color: subtextColor.withOpacity(0.5), fontSize: 12),
                          filled: true,
                          fillColor: backgroundColor,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: const Color(0xFF2E7D32), width: 1.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        style: TextStyle(color: textColor, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Delivery Notes (Optional)',
                          hintStyle: TextStyle(color: subtextColor.withOpacity(0.5), fontSize: 12),
                          filled: true,
                          fillColor: backgroundColor,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: const Color(0xFF2E7D32), width: 1.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Delivery Contact Preference
                _buildModernCard(
                  cardColor: cardColor,
                  isDarkMode: isDarkMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF10B981), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text('Driver Contact', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _deliveryContactMethod = 'call'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone_rounded,
                                          size: 16,
                                          color: subtextColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Call',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_deliveryContactMethod == 'call')
                                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _deliveryContactMethod = 'ring'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.notifications_outlined,
                                          size: 16,
                                          color: subtextColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Ring Bell',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_deliveryContactMethod == 'ring')
                                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Payment Method
                _buildModernCard(
                  cardColor: cardColor,
                  isDarkMode: isDarkMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.payment_rounded, color: Color(0xFF8B5CF6), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text('Payment Method', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentOptionModern('cash', 'Cash on Delivery', Icons.money_rounded, textColor, subtextColor, isDarkMode),
                      const SizedBox(height: 8),
                      _buildPaymentOptionModern('mobile', 'Mobile Money', Icons.phone_android_rounded, textColor, subtextColor, isDarkMode),
                    ],
                  ),
                ),
                
                const SizedBox(height: 120),
              ],
            ),
            ),
          ),
          
          // Bottom Bar with Price Summary
          Container(
            decoration: BoxDecoration(
              color: cardColor,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_promoDiscount == 0) ...[
                      _buildPriceRowCompact('Subtotal', subtotal, textColor, subtextColor, false),
                      const SizedBox(height: 10),
                      _buildPriceRowCompact('Delivery', deliveryFee, textColor, subtextColor, false),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal', style: TextStyle(fontSize: 14, color: subtextColor, fontWeight: FontWeight.w500)),
                          Text('RWF ${subtotal.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Delivery', style: TextStyle(fontSize: 14, color: subtextColor, fontWeight: FontWeight.w500)),
                          Text('RWF ${deliveryFee.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_offer, size: 16, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 6),
                              Text('Discount', style: const TextStyle(fontSize: 14, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Text('-RWF ${_promoDiscount.toStringAsFixed(0)}', 
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                        Text('RWF ${total.toStringAsFixed(0)}', 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_isProcessing || _isRecalculatingFees) ? null : _placeOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[400],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _isRecalculatingFees
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Updating...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                ],
                              )
                            : _isProcessing
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.check_circle_rounded, size: 22),
                                      SizedBox(width: 10),
                                      Text('Place Order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildSelectedAddressCompact(DeliveryAddress address, Color textColor, Color subtextColor, bool isDarkMode) {
    return InkWell(
      onTap: _showSavedAddresses,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.5), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                address.label == 'Home'
                    ? Icons.home_rounded
                    : address.label == 'Work'
                        ? Icons.work_rounded
                        : Icons.location_on_rounded,
                color: const Color(0xFF2E7D32),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.label != null)
                    Text(
                      address.label!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
                    ),
                  Text(
                    address.shortAddress,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF2E7D32)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAddressCompact(Color textColor, Color subtextColor, bool isDarkMode) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _navigateToLocationPicker,
            icon: const Icon(Icons.add_location_rounded, size: 20),
            label: const Text('Add Delivery Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? Colors.white : Colors.black,
              foregroundColor: isDarkMode ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _showSavedAddresses,
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('Choose from saved addresses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          style: TextButton.styleFrom(
            foregroundColor: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOptionModern(String value, String label, IconData icon, Color textColor, Color subtextColor, bool isDarkMode) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: subtextColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF8B5CF6), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRowCompact(String label, double amount, Color textColor, Color subtextColor, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? textColor : subtextColor,
          ),
        ),
        Text(
          'RWF ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
