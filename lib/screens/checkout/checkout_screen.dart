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
import '../../services/payment_service.dart';
import '../../models/vendor.dart';
import '../../models/delivery_address.dart';
import '../../models/special_offer.dart';
import '../../utils/location_validator.dart';

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
  String _paymentMethod = 'momo';
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
                    const Icon(Icons.location_on_rounded, size: 24, color: Color(0xFF2E7D32)),
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
                      Icon(Icons.location_off, size: 72, color: Colors.grey[400]),
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
    // Prevent double-tap: if already processing, ignore
    if (_isProcessing) return;

    final addressProvider = context.read<AddressProvider>();
    if (addressProvider.selectedAddress == null) {
      _showError('Please select a delivery address');
      return;
    }

    // Validate address is within Kigali service area
    final selectedAddr = addressProvider.selectedAddress!;
    if (!LocationValidator.isWithinServiceArea(selectedAddr.latitude, selectedAddr.longitude)) {
      _showError('This delivery address is outside our service area (Kigali). Please choose a different address.');
      return;
    }

    // Validate address has real coordinates (not 0,0)
    if (selectedAddr.latitude == 0 && selectedAddr.longitude == 0) {
      _showError('Delivery address is invalid. Please select a proper location on the map.');
      return;
    }

    if (_paymentMethod == 'momo' && _phoneController.text.trim().isEmpty) {
      _showError('Please enter your phone number for Mobile Money');
      return;
    }

    // Confirm delivery location before placing order
    final confirmed = await _confirmDeliveryAddress(selectedAddr);
    if (confirmed != true) return;

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
      bool anyMomoPaymentSucceeded = false;
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
          final orderId = response['order']['id'].toString();
          orderIds.add(orderId);
          // Backend auto-initiates MoMo payment — check the result
          final paymentData = response['payment'];
          if (paymentData != null && paymentData['success'] == true) {
            anyMomoPaymentSucceeded = true;
          }
        } else {
          throw Exception(response['error'] ?? 'Failed to create order');
        }
      }

      // All orders created — clear cart
      final cart = context.read<CartProvider>();
      for (var item in selectedItems) {
        cart.removeCartItem(item);
      }

      // For momo: payment was already initiated by backend during order creation
      if (_paymentMethod == 'momo') {
        if (mounted) {
          setState(() => _isProcessing = false);
          final lastOrderId = orderIds.last;
          if (anyMomoPaymentSucceeded) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    const Icon(Icons.phone_android, color: Color(0xFF1565C0), size: 28),
                    const SizedBox(width: 10),
                    const Text('Approve Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Dial *182*7*1# when paying',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Follow the USSD prompts on your phone to confirm payment.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('OK, Got it'),
                    ),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment could not be initiated. You can retry from order details.'),
                backgroundColor: Color(0xFFE65100),
                duration: Duration(seconds: 5),
              ),
            );
          }
          if (mounted) {
            if (orderIds.length == 1) {
              context.go('/order/$lastOrderId');
            } else {
              context.go('/my-orders');
            }
          }
        }
        return;
      }

      // Non-momo payment — go to orders
      if (mounted) {
        setState(() => _isProcessing = false);
        final lastOrderId = orderIds.isNotEmpty ? orderIds.last : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${orderIds.length} order${orderIds.length > 1 ? 's' : ''} placed successfully!'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (lastOrderId != null) {
              context.go('/order/$lastOrderId');
            } else {
              context.go('/my-orders');
            }
          }
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

  /// Show a confirmation dialog with the delivery address before placing the order
  Future<bool?> _confirmDeliveryAddress(DeliveryAddress address) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF2E7D32);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.location_on_rounded, color: accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Confirm Delivery Location',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deliver to:',
              style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      address.fullAddress,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Is this the correct address?',
              style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              _navigateToLocationPicker();
            },
            child: Text('Change', style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm & Order'),
          ),
        ],
      ),
    );
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
    final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final accent = const Color(0xFF2E7D32);
    
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
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              children: [
                // ── Delivery Address ──
                _buildCard(
                  cardColor: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(Icons.location_on_rounded, 'Delivery Address', textColor),
                      const SizedBox(height: 10),
                      if (addressProvider.selectedAddress != null)
                        _buildSelectedAddressCompact(addressProvider.selectedAddress!, textColor, subtextColor, isDarkMode, accent)
                      else
                        _buildNoAddressCompact(textColor, subtextColor, isDarkMode, accent),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // ── Order Items ──
                _buildCard(
                  cardColor: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(Icons.receipt_long, 'Order Items', textColor),
                      const SizedBox(height: 10),
                      ...itemsByVendor.entries.map((entry) {
                        final vendor = _vendorCache[entry.key];
                        final vendorName = vendor?.name ?? 'Vendor';
                        final vendorFee = vendor?.deliveryFee ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(vendorName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                                ),
                                Text(
                                  vendorFee > 0 ? 'Delivery: RWF ${vendorFee.toStringAsFixed(0)}' : 'FREE delivery',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                            ),
                            ...entry.value.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item.product.imageUrl,
                                      width: 44, height: 44, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.fastfood_rounded, color: subtextColor, size: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.selectedModifiers != null && item.selectedModifiers!.isNotEmpty)
                                          Text(
                                            item.selectedModifiers!.values.map((m) => m.name).join(', '),
                                            style: TextStyle(fontSize: 10, color: subtextColor),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 2),
                                        Text('x${item.quantity}', style: TextStyle(fontSize: 11, color: subtextColor)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'RWF ${item.totalPrice.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                                  ),
                                ],
                              ),
                            )),
                            if (entry.key != itemsByVendor.keys.last)
                              const SizedBox(height: 8),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // ── Promo Code ──
                _buildCard(
                  cardColor: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(Icons.local_offer, 'Promo Code', textColor),
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
                                  fillColor: isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF0F0F0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                onPressed: _isValidatingPromo ? null : _applyPromoCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  disabledBackgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                                ),
                                child: _isValidatingPromo
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                    : const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                        if (_promoMessage != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _promoSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                size: 14, color: _promoSuccess ? accent : Colors.red[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _promoMessage!,
                                  style: TextStyle(fontSize: 12, color: _promoSuccess ? accent : Colors.red[600], fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: accent, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_appliedPromoCode!, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: accent, letterSpacing: 1)),
                                    Text('You save RWF ${_promoDiscount.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: subtextColor)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _removePromoCode,
                                child: Icon(Icons.close_rounded, color: Colors.red[400], size: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // ── Contact & Notes ──
                _buildCard(
                  cardColor: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(Icons.person_outline_rounded, 'Contact', textColor),
                      const SizedBox(height: 10),
                      _buildCleanTextField(
                        controller: _phoneController,
                        hint: 'Phone number',
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      _buildCleanTextField(
                        controller: _notesController,
                        hint: 'Delivery notes (optional)',
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // ── Driver Contact ──
                _buildCard(
                  cardColor: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(Icons.phone_in_talk, 'Driver Contact', textColor),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildOptionChip('Call', Icons.phone, _deliveryContactMethod == 'call', isDarkMode, textColor, subtextColor, accent, () => setState(() => _deliveryContactMethod = 'call')),
                          const SizedBox(width: 8),
                          _buildOptionChip('Ring Bell', Icons.notifications_none_rounded, _deliveryContactMethod == 'ring', isDarkMode, textColor, subtextColor, accent, () => setState(() => _deliveryContactMethod = 'ring')),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // ── Payment ──
                _buildCard(
                  cardColor: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(Icons.account_balance_wallet, 'Payment', textColor),
                      const SizedBox(height: 10),
                      _buildPaymentOption('momo', 'Mobile Money (MTN/Airtel)', Icons.phone_android_rounded, textColor, subtextColor, isDarkMode, accent),
                      if (_paymentMethod == 'momo') ...[
                        const SizedBox(height: 10),
                        _buildCleanTextField(
                          controller: _phoneController,
                          hint: '250783300000',
                          isDarkMode: isDarkMode,
                          textColor: textColor,
                          subtextColor: subtextColor,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
          
          // ── Bottom Bar ──
          Container(
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
                    _buildPriceRow('Subtotal', 'RWF ${subtotal.toStringAsFixed(0)}', subtextColor, textColor, false),
                    const SizedBox(height: 8),
                    _buildPriceRow('Delivery', deliveryFee > 0 ? 'RWF ${deliveryFee.toStringAsFixed(0)}' : 'FREE', subtextColor, textColor, false),
                    if (_promoDiscount > 0) ...[
                      const SizedBox(height: 8),
                      _buildPriceRow('Discount', '-RWF ${_promoDiscount.toStringAsFixed(0)}', accent, accent, false),
                    ],
                    const SizedBox(height: 10),
                    Divider(height: 1, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                    const SizedBox(height: 10),
                    _buildPriceRow('Total', 'RWF ${total.toStringAsFixed(0)}', textColor, textColor, true),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_isProcessing || _isRecalculatingFees) ? null : _placeOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _isRecalculatingFees
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                                  SizedBox(width: 10),
                                  Text('Updating...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                ],
                              )
                            : _isProcessing
                                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                : Text(
                                    'Pay & Place Order',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

  // ── Shared Widgets ──

  Widget _buildCard({required Color cardColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textColor.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
      ],
    );
  }

  Widget _buildCleanTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDarkMode,
    required Color textColor,
    required Color subtextColor,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 13),
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: subtextColor.withOpacity(0.4), fontSize: 13),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF0F0F0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  Widget _buildOptionChip(String label, IconData icon, bool isSelected, bool isDarkMode, Color textColor, Color subtextColor, Color accent, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withOpacity(0.08)
                : (isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: accent.withOpacity(0.4), width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? accent : subtextColor),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? accent : textColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedAddressCompact(DeliveryAddress address, Color textColor, Color subtextColor, bool isDarkMode, Color accent) {
    return GestureDetector(
      onTap: _showSavedAddresses,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              address.label == 'Home' ? Icons.home_rounded
                  : address.label == 'Work' ? Icons.work_outline_rounded
                  : Icons.location_on_rounded,
              color: accent, size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.label != null)
                    Text(address.label!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
                  Text(
                    address.shortAddress,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: subtextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAddressCompact(Color textColor, Color subtextColor, bool isDarkMode, Color accent) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _navigateToLocationPicker,
            icon: const Icon(Icons.add_location_alt, size: 18),
            label: const Text('Add Delivery Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showSavedAddresses,
          child: Text('or choose from saved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subtextColor)),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon, Color textColor, Color subtextColor, bool isDarkMode, Color accent) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withOpacity(0.06)
              : (isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF0F0F0)),
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: accent.withOpacity(0.4), width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? accent : subtextColor, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? accent : textColor))),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: accent, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color labelColor, Color valueColor, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 15 : 14, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: labelColor)),
        Text(value, style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, color: valueColor)),
      ],
    );
  }

  Widget _buildModernCard({required Color cardColor, required bool isDarkMode, required Widget child}) {
    return _buildCard(cardColor: cardColor, child: child);
  }

  Widget _buildPriceRowCompact(String label, double amount, Color textColor, Color subtextColor, bool isBold) {
    return _buildPriceRow(label, 'RWF ${amount.toStringAsFixed(0)}', isBold ? textColor : subtextColor, textColor, isBold);
  }
}
