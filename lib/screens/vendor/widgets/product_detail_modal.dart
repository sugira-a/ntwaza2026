// lib/screens/vendor/widgets/product_detail_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product.dart';
import '../../../models/vendor.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class ProductDetailModal extends StatefulWidget {
  final Product product;
  final Vendor vendor;

  const ProductDetailModal({
    super.key,
    required this.product,
    required this.vendor,
  });

  @override
  State<ProductDetailModal> createState() => _ProductDetailModalState();
}

class _ProductDetailModalState extends State<ProductDetailModal> {
  int quantity = 1;
  Map<String, Set<String>> selectedModifiers = {};
  double additionalPrice = 0;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    print('🔍 ProductDetailModal initialized for: ${widget.product.name}');
    print('   Product has modifiers: ${widget.product.modifiers != null}');
    if (widget.product.modifiers != null) {
      print('   Modifier count: ${widget.product.modifiers!.length}');
      for (var mod in widget.product.modifiers!) {
        print('   - ${mod.name}: ${mod.options.length} options');
      }
    }
    _initializeDefaultModifiers();
  }

  void _initializeDefaultModifiers() {
    if (widget.product.modifiers == null) return;

    for (var modifier in widget.product.modifiers!) {
      selectedModifiers[modifier.id] = {};
      
      // Don't auto-select - let user choose required modifiers
      for (var option in modifier.options) {
        if (option.isDefault && option.isAvailable && !modifier.isRequired) {
          selectedModifiers[modifier.id]!.add(option.id);
          additionalPrice += option.priceAdjustment;
        }
      }
    }
  }

  void _toggleModifier(ProductModifier modifier, ModifierOption option) {
    setState(() {
      final isSelected = selectedModifiers[modifier.id]?.contains(option.id) ?? false;
      
      if (isSelected) {
        selectedModifiers[modifier.id]!.remove(option.id);
        additionalPrice -= option.priceAdjustment;
      } else {
        selectedModifiers[modifier.id]!.add(option.id);
        additionalPrice += option.priceAdjustment;
      }
    });
  }

  void _addToCart() {
    // Block ordering if vendor is closed
    if (!widget.vendor.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.access_time_filled, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('This vendor is currently closed', style: TextStyle(fontWeight: FontWeight.w500))),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    
    // Validate required modifiers
    for (var modifier in widget.product.modifiers ?? []) {
      if (modifier.isRequired && 
          (selectedModifiers[modifier.id]?.isEmpty ?? true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select ${modifier.name}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }

    // Convert Set<String> to Map<String, ModifierOption> for cart
    Map<String, ModifierOption> cartModifiers = {};
    for (var modifier in widget.product.modifiers ?? []) {
      final selectedIds = selectedModifiers[modifier.id] ?? {};
      if (selectedIds.isNotEmpty) {
        final firstSelectedId = selectedIds.first;
        final option = modifier.options.firstWhere((opt) => opt.id == firstSelectedId);
        cartModifiers[modifier.id] = option;
      }
    }

    // Add to cart with modifiers
    for (int i = 0; i < quantity; i++) {
      cart.addToCart(
        widget.product,
        vendor: widget.vendor,
        selectedModifiers: cartModifiers,
      );
    }

    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Added to cart', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String get estimatedDeliveryTimeDisplay {
    // For non-restaurants (supermarkets/shops): show a range like 30-45 mins
    if (!widget.vendor.isRestaurant) {
      return widget.vendor.formattedDeliveryTime;
    }
    
    // For restaurants: prep time + delivery time + buffer
    final prepTime = widget.product.preparationTime ?? 15;
    int deliveryTime = 25;
    try {
      final deliveryTimeStr = widget.vendor.formattedDeliveryTime;
      if (deliveryTimeStr.contains('-')) {
        final parts = deliveryTimeStr.split('-');
        final min = int.parse(parts[0].trim());
        final max = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), '').trim());
        deliveryTime = ((min + max) / 2).round();
      } else {
        deliveryTime = int.parse(deliveryTimeStr.replaceAll(RegExp(r'[^0-9]'), ''));
      }
    } catch (e) {
      deliveryTime = 25;
    }
    final total = prepTime + deliveryTime + 5;
    return '$total min';
  }

  double get totalPrice => (widget.product.price + additionalPrice) * quantity;

  void _showSettingsMenu(BuildContext context, bool isDarkMode, ThemeProvider themeProvider, Color cardColor, Color textColor) {
    final authProvider = context.read<AuthProvider>();
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 250,
        kToolbarHeight + MediaQuery.of(context).padding.top,
        16, 0,
      ),
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            width: 230,
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!))),
                child: Row(children: [
                  Icon(Icons.settings, color: textColor, size: 20),
                  const SizedBox(width: 12),
                  Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                ]),
              ),
              _buildSettingsItem(Icons.dark_mode, 'Dark Mode', () {
                themeProvider.toggleTheme();
                Navigator.pop(context);
              }, isDarkMode ? Icons.toggle_on : Icons.toggle_off, textColor),
              Divider(height: 1, color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
              if (!authProvider.isAuthenticated) ...[
                _buildSettingsItem(Icons.login, 'Login', () {
                  Navigator.pop(context);
                  context.go('/login');
                }, Icons.arrow_forward_ios, textColor),
                Divider(height: 1, color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
                _buildSettingsItem(Icons.person_add, 'Sign Up', () {
                  Navigator.pop(context);
                  context.go('/register');
                }, Icons.arrow_forward_ios, textColor),
              ] else ...[
                _buildSettingsItem(Icons.account_circle_rounded, 'Profile', () {
                  Navigator.pop(context);
                  context.go('/profile');
                }, Icons.arrow_forward_ios, textColor),
                Divider(height: 1, color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
                _buildSettingsItem(Icons.receipt_long, 'My Orders', () {
                  Navigator.pop(context);
                }, Icons.arrow_forward_ios, textColor),
                Divider(height: 1, color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
                _buildSettingsItem(Icons.logout, 'Logout', () {
                  authProvider.logout();
                  Navigator.pop(context);
                }, null, Colors.red),
              ],
              Divider(height: 1, color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
              _buildSettingsItem(Icons.help_outline, 'Help', () => Navigator.pop(context), Icons.arrow_forward_ios, textColor),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, VoidCallback onTap, IconData? trailingIcon, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            if (trailingIcon != null) Icon(trailingIcon, size: 12, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? Color(0xFF1A1A1A) : Colors.white;
    final cardColor = isDarkMode ? Color(0xFF1A1A1A) : Colors.grey[100]!;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // App Bar
            SizedBox(
              height: 300 + MediaQuery.of(context).padding.top,
              child: Stack(
                children: [
                  _buildStaticAppBar(isDarkMode, textColor, themeProvider, cardColor),
                ],
              ),
            ),
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductHeader(isDarkMode, textColor, subtextColor, backgroundColor),
                if (widget.product.modifiers != null && widget.product.modifiers!.isNotEmpty) ...[
                  Builder(builder: (context) {
                    print('🎨 Building modifiers section with ${widget.product.modifiers!.length} groups');
                    return _buildModifiersSection(isDarkMode, backgroundColor, cardColor, textColor, subtextColor);
                  }),
                ] else ...[
                  Builder(builder: (context) {
                    print('⚠️ NOT building modifiers section - modifiers null or empty');
                    return SizedBox.shrink();
                  }),
                ],
                SizedBox(height: 16),
                // Bottom bar inline with content
                _buildBottomBar(isDarkMode, backgroundColor, cardColor, textColor, subtextColor),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticAppBar(bool isDarkMode, Color textColor, ThemeProvider themeProvider, Color cardColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Hero Image with watermark
        Hero(
          // Use a distinct tag inside the modal to avoid duplicate Hero tags
          // when the source image may still exist in the original route's subtree.
          tag: 'product_detail_${widget.product.id}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 60,
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    ),
                  ),
                ),
              ),
              // Watermark overlay
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'NTWAZA',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDarkMode ? Colors.white : Colors.black, size: 18),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
            ),
          ),
        ),
        // Menu button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert_rounded, color: isDarkMode ? Colors.white : Colors.black, size: 20),
              onPressed: () => _showSettingsMenu(context, isDarkMode, themeProvider, cardColor, textColor),
              tooltip: 'Menu',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductHeader(bool isDarkMode, Color textColor, Color subtextColor, Color backgroundColor) {
    return Container(
      color: backgroundColor,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            widget.vendor.name,
            style: TextStyle(
              fontSize: 13,
              color: subtextColor,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'RWF ${widget.product.price.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.green),
              SizedBox(width: 6),
              Text(
                estimatedDeliveryTimeDisplay,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.product.calories != null) ...[
                SizedBox(width: 16),
                Text('🔥', style: TextStyle(fontSize: 14)),
                SizedBox(width: 4),
                Text(
                  '${widget.product.calories} cal',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              Spacer(),
              Text(
                'DF:',
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4),
              Text(
                widget.vendor.formattedDeliveryFee,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (widget.product.description.isNotEmpty) ...[
            SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          _isDescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: subtextColor,
                          size: 20,
                        ),
                      ],
                    ),
                    if (_isDescriptionExpanded) ...[
                      SizedBox(height: 8),
                      Text(
                        widget.product.description,
                        style: TextStyle(
                          color: subtextColor,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (widget.product.ingredients != null && widget.product.ingredients!.isNotEmpty) ...[
            SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.product.ingredients!.map((ingredient) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    ingredient,
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (widget.product.isPopular == true) ...[
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  'Popular choice',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModifiersSection(bool isDarkMode, Color backgroundColor, Color cardColor, Color textColor, Color subtextColor) {
    return Container(
      color: backgroundColor,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extra',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Select multiple choice',
            style: TextStyle(
              color: subtextColor,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 12),
          ...widget.product.modifiers!.map((modifier) => _buildModifierGroup(modifier, isDarkMode, cardColor, textColor, subtextColor)),
        ],
      ),
    );
  }

  Widget _buildModifierGroup(ProductModifier modifier, bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...modifier.options.map((option) => _buildModifierOption(modifier, option, isDarkMode, cardColor, textColor, subtextColor)),
        SizedBox(height: 6),
      ],
    );
  }

  Widget _buildModifierOption(ProductModifier modifier, ModifierOption option, bool isDarkMode, Color cardColor, Color textColor, Color subtextColor) {
    final isSelected = selectedModifiers[modifier.id]?.contains(option.id) ?? false;
    final isRequired = modifier.isRequired;

    return GestureDetector(
      onTap: option.isAvailable ? () => _toggleModifier(modifier, option) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cardColor,
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(3),
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: option.isAvailable ? textColor : subtextColor,
                      ),
                    ),
                  ),
                  if (isRequired) ...[
                    SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Required',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (option.priceAdjustment > 0)
              Text(
                '+ RWF ${option.priceAdjustment.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDarkMode, Color backgroundColor, Color cardColor, Color textColor, Color subtextColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: const [],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: RWF ${totalPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.remove,
                          color: quantity > 1 ? textColor : subtextColor,
                          size: 18,
                        ),
                        onPressed: quantity > 1
                            ? () => setState(() => quantity--)
                            : null,
                      ),
                    ),
                    Container(
                      width: 36,
                      alignment: Alignment.center,
                      child: Text(
                        quantity.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.add, color: textColor, size: 18),
                        onPressed: () => setState(() => quantity++),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            if (!widget.vendor.isOpen)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(isDarkMode ? 0.3 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time_filled, size: 16, color: Colors.red.shade400),
                    SizedBox(width: 8),
                    Text(
                      'Vendor is closed — ordering unavailable',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade400),
                    ),
                  ],
                ),
              )
            else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.product.isAvailable ? _addToCart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.product.isAvailable ? 'Add to cart' : 'Unavailable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}