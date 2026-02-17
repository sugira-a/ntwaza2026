// lib/screens/checkout/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/cart_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/address_provider.dart';
import '../../services/api/api_service.dart';
import '../../models/vendor.dart';
import '../../models/delivery_address.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, List<String>>? selectedItems;
  const CheckoutScreen({super.key, this.selectedItems});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  final Map<String, Vendor?> _vendorCache = {};
  bool _isProcessing = false;
  bool _isRecalculatingFees = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadVendorDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addressProvider = context.read<AddressProvider>();
      addressProvider.addListener(_onAddressChanged);
    });
  }

  @override
  void dispose() {
    final addressProvider = context.read<AddressProvider>();
    addressProvider.removeListener(_onAddressChanged);
    _phoneController.dispose();
    _notesController.dispose();
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

  double _calculateTotal() => _calculateSubtotal() + _calculateDeliveryFee();

  // ✅ FIXED: Add location picker navigation
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
              content: Text('✅ Address saved • Delivery: RWF ${deliveryFee.toStringAsFixed(0)}'),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) setState(() => _isRecalculatingFees = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
          );
        }
      }
    }
  }

  // ✅ FIXED: Add saved addresses sheet
  void _showSavedAddresses() {
    final addressProvider = context.read<AddressProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text('Saved Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToLocationPicker();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add New'),
                    ),
                  ],
                ),
              ),
              if (addressProvider.savedAddresses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No saved addresses yet', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: addressProvider.savedAddresses.length,
                  itemBuilder: (context, index) {
                    final address = addressProvider.savedAddresses[index];
                    return ListTile(
                      leading: Icon(address.label == 'Home' ? Icons.home : address.label == 'Work' ? Icons.work : Icons.location_on),
                      title: Text(address.label ?? address.shortAddress),
                      subtitle: Text(address.shortAddress, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    );
                  },
                ),
            ],
          ),
        ),
      ),
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
        print('🔑 Token set for order creation');
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
        final total = subtotal + deliveryFee;
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
          'subtotal': subtotal,
          'delivery_fee': deliveryFee,
          'total': total,
        };
        print('📦 Creating order for vendor $vendorId');
        final response = await apiService.post('/api/orders/direct', orderData);
        if (response['success'] == true) {
          orderIds.add(response['order']['id'].toString());
          print('✅ Order created: ${response['order']['id']}');
        } else {
          throw Exception(response['error'] ?? 'Failed to create order');
        }
      }
      final cart = context.read<CartProvider>();
      for (var item in selectedItems) {
        cart.removeCartItem(item);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${orderIds.length} order${orderIds.length > 1 ? 's' : ''} placed successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        context.go('/');
      }
    } catch (e) {
      print('❌ Order placement failed: $e');
      if (mounted) {
        _showError('Failed to place order: ${e.toString().replaceAll('Exception:', '').trim()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final addressProvider = context.watch<AddressProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[50]!;
    final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
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
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : context.go('/cart')),
        title: Text('Checkout', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('Delivery Address', Icons.location_on, cardColor, textColor, isDarkMode,
                  child: addressProvider.selectedAddress != null
                      ? _buildSelectedAddress(addressProvider.selectedAddress!, textColor, subtextColor, isDarkMode)
                      : _buildNoAddress(textColor, subtextColor, isDarkMode),
                ),
                const SizedBox(height: 16),
                _buildSection('Order Summary', Icons.receipt_long, cardColor, textColor, isDarkMode,
                  child: Column(
                    children: [
                      for (var entry in itemsByVendor.entries) ...[
                        _buildVendorGroup(entry.key, entry.value, textColor, subtextColor, isDarkMode),
                        if (entry.key != itemsByVendor.keys.last) Divider(height: 24, color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[200]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSection('Contact Information', Icons.phone, cardColor, textColor, isDarkMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _phoneController,
                        style: TextStyle(color: textColor),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number *',
                          labelStyle: TextStyle(color: subtextColor),
                          hintText: 'Enter your phone number',
                          hintStyle: TextStyle(color: subtextColor.withOpacity(0.5)),
                          filled: true,
                          fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.phone, color: subtextColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Delivery Notes (Optional)',
                          labelStyle: TextStyle(color: subtextColor),
                          hintText: 'Any special instructions?',
                          hintStyle: TextStyle(color: subtextColor.withOpacity(0.5)),
                          filled: true,
                          fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.note, color: subtextColor),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSection('Payment Method', Icons.payment, cardColor, textColor, isDarkMode,
                  child: Column(
                    children: [
                      _buildPaymentOption('cash', 'Cash on Delivery', Icons.money, textColor, subtextColor, isDarkMode),
                      const SizedBox(height: 8),
                      _buildPaymentOption('mobile', 'Mobile Money', Icons.phone_android, textColor, subtextColor, isDarkMode),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1), blurRadius: 12, offset: const Offset(0, -4))]),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPriceRow('Subtotal', subtotal, textColor, subtextColor),
                    const SizedBox(height: 8),
                    _buildPriceRow(itemsByVendor.length > 1 ? 'Delivery (${itemsByVendor.length} vendors)' : 'Delivery Fee', deliveryFee, textColor, subtextColor),
                    Divider(height: 24, color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[300]),
                    _buildPriceRow('Total', total, textColor, textColor, isBold: true),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isProcessing || _isRecalculatingFees) ? null : _placeOrder,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey[400], padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: _isRecalculatingFees
                            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))), SizedBox(width: 12), Text('Updating prices...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])
                            : _isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : Text('Place Order (RWF ${total.toStringAsFixed(0)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildSection(String title, IconData icon, Color cardColor, Color textColor, bool isDarkMode, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: isDarkMode ? Border.all(color: const Color(0xFF2A2A2A), width: 0.5) : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 20, color: textColor), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor))]), const SizedBox(height: 16), child]),
    );
  }

  Widget _buildSelectedAddress(DeliveryAddress address, Color textColor, Color subtextColor, bool isDarkMode) {
    return InkWell(
      onTap: _showSavedAddresses, // ✅ FIXED
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isDarkMode ? Colors.grey[900] : Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2E7D32), width: 1.5)),
        child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(address.label == 'Home' ? Icons.home : address.label == 'Work' ? Icons.work : Icons.location_on, color: const Color(0xFF2E7D32), size: 24)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (address.label != null) Text(address.label!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))), Text(address.shortAddress, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis)]))]),
      ),
    );
  }

  Widget _buildNoAddress(Color textColor, Color subtextColor, bool isDarkMode) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _navigateToLocationPicker, // ✅ FIXED
          icon: const Icon(Icons.add_location),
          label: const Text('Add Delivery Address'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _showSavedAddresses, // ✅ FIXED
          icon: const Icon(Icons.history),
          label: const Text('Choose from saved addresses'),
          style: TextButton.styleFrom(foregroundColor: isDarkMode ? Colors.white70 : Colors.black87),
        ),
      ],
    );
  }

  Widget _buildVendorGroup(String vendorId, List<CartItem> items, Color textColor, Color subtextColor, bool isDarkMode) {
    final vendor = _vendorCache[vendorId];
    final vendorName = vendor?.name ?? items.first.product.vendorName ?? 'Vendor';
    final deliveryFee = _getVendorDeliveryFee(vendorId);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.store, size: 16, color: subtextColor), const SizedBox(width: 8), Expanded(child: Text(vendorName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor))), Text('Delivery: RWF ${deliveryFee.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: subtextColor))]), const SizedBox(height: 12), ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 24), child: Row(children: [Expanded(child: Text('${item.quantity}x ${item.product.name}', style: TextStyle(fontSize: 14, color: textColor))), Text('RWF ${item.totalPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor))])))]);
  }

  Widget _buildPaymentOption(String value, String label, IconData icon, Color textColor, Color subtextColor, bool isDarkMode) {
    final isSelected = _paymentMethod == value;
    return InkWell(onTap: () => setState(() => _paymentMethod = value), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? (isDarkMode ? Colors.grey[900] : Colors.grey[100]) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF2E7D32) : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[300]!), width: isSelected ? 2 : 1)), child: Row(children: [Icon(icon, color: isSelected ? const Color(0xFF2E7D32) : subtextColor, size: 24), const SizedBox(width: 12), Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: textColor))), if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20)])));
  }

  Widget _buildPriceRow(String label, double amount, Color labelColor, Color amountColor, {bool isBold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: isBold ? 18 : 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: labelColor)), Text('RWF ${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: isBold ? 20 : 16, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: amountColor))]);
  }
}