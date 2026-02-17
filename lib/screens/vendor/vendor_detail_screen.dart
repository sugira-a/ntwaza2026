// lib/screens/vendor/vendor_detail_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/vendor.dart';
import '../../models/product.dart';
import '../../models/product_category.dart';
import '../../providers/product_detail_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/review_provider.dart';
import '../../utils/helpers.dart';
import 'widgets/product_detail_modal.dart';

class VendorDetailScreen extends StatefulWidget {
  final Vendor vendor;

  const VendorDetailScreen({super.key, required this.vendor});

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _selectedNavIndex = 0;
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProductDetailProvider>();
      provider.initialize(widget.vendor); // This will now show "All" by default

      context.read<ReviewProvider>().fetchVendorReviews(widget.vendor.id);
      
      // Show notification if vendor is closed
      if (!widget.vendor.isOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This vendor is currently closed',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 4),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getNextOpeningTime() {
    if (widget.vendor.workingHours == null || widget.vendor.workingHours!.isEmpty) {
      return 'Check working hours for details';
    }

    final now = nowInRwanda();
    // Dart weekday: 1=Monday, 7=Sunday
    final currentDayIndex = (now.weekday - 1) % 7;
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDay = days[currentDayIndex];

    // Check today's hours first
    final todayData = widget.vendor.workingHours![currentDay];
    if (todayData != null && todayData is Map && todayData['open'] == true) {
      final openTime = todayData['open_time'] ?? '09:00';
      return 'Opens today at $openTime';
    }

    // Check next 7 days
    for (int i = 1; i <= 7; i++) {
      final checkDayIndex = (currentDayIndex + i) % 7;
      final checkDay = days[checkDayIndex];
      final dayData = widget.vendor.workingHours![checkDay];
      
      if (dayData != null && dayData is Map && dayData['open'] == true) {
        final openTime = dayData['open_time'] ?? '09:00';
        final dayName = dayNames[checkDayIndex];
        return i == 1 ? 'Opens tomorrow at $openTime' : 'Opens on $dayName at $openTime';
      }
    }

    return 'Check working hours for details';
  }

  void _showWorkingHoursDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final backgroundColor = isDarkMode ? Color(0xFF1A1A1A) : Colors.white;
    final cardBg = isDarkMode ? Color(0xFF2A2A2A) : Colors.white;
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.schedule, color: Colors.blue, size: 24),
            SizedBox(width: 12),
            Text(
              'Working Hours',
              style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.vendor.name,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              if (widget.vendor.workingHours != null && widget.vendor.workingHours!.isNotEmpty)
                ...List.generate(
                  days.length,
                  (index) {
                    final day = days[index];
                    final dayKey = dayKeys[index];
                    final dayData = widget.vendor.workingHours![dayKey];
                    final isOpen = dayData != null && dayData is Map && dayData['open'] == true;
                    final openTime = isOpen ? (dayData['open_time'] ?? 'N/A') : 'Closed';
                    final closeTime = isOpen ? (dayData['close_time'] ?? 'N/A') : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  day,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                if (isOpen)
                                  Text(
                                    '$openTime - $closeTime',
                                    style: TextStyle(
                                      color: Colors.green.shade400,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  Text(
                                    'Closed',
                                    style: TextStyle(
                                      color: Colors.red.shade400,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOpen 
                                  ? (isDarkMode ? Colors.green.shade900 : Colors.green.shade50)
                                  : (isDarkMode ? Colors.red.shade900 : Colors.red.shade50),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOpen ? 'Open' : 'Closed',
                                style: TextStyle(
                                  color: isOpen ? Colors.green.shade300 : Colors.red.shade300,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blue.shade900 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'No working hours information available',
                    style: TextStyle(
                      color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductDetail(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailModal(product: product, vendor: widget.vendor),
    );
  }

  void _onNavItemTapped(int index) {
  setState(() => _selectedNavIndex = index);
  switch (index) {
    case 0: Navigator.pop(context); break;
    case 1: Navigator.pop(context); break;
    case 2: Navigator.pop(context); break;
    case 3:
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isAuthenticated) {
        // ⭐ CHANGED: Use push instead of go
        context.push('/cart');
      } else {
        _showLoginPrompt(context, 'Please login to view your cart');
      }
      break;
    case 4:
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isAuthenticated) {
        context.push('/profile');
      } else {
        _showLoginPrompt(context, 'Please login to view your profile');
      }
      break;
  }
}
  void _showLoginPrompt(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); context.push('/login'); },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showCategoriesMenu(BuildContext context, ProductDetailProvider provider, bool isDarkMode, Color textColor, Color cardColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Categories', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                      SizedBox(height: 4),
                      Text('${provider.categories.length + 1} categories', style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.6))),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, color: textColor),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 24, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
            
            // Categories List
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  // All Products
                  _buildCategoryItem(
                    context,
                    'All Products',
                    Icons.apps_rounded,
                    provider.selectedCategoryId == null,
                    isDarkMode,
                    textColor,
                    () {
                      provider.clearCategorySelection();
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 8),
                  
                  // Individual Categories
                  ...provider.categories.map((category) => 
                    _buildCategoryItem(
                      context,
                      category.name,
                      Icons.category_rounded,
                      category.id == provider.selectedCategoryId,
                      isDarkMode,
                      textColor,
                      () {
                        provider.selectCategory(category.id);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    String name,
    IconData icon,
    bool isSelected,
    bool isDarkMode,
    Color textColor,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? (isDarkMode ? Colors.grey[800] : Colors.grey[100]) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!, width: 1.5) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: isSelected ? Colors.blue : textColor.withOpacity(0.6)),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: 22, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsMenu(BuildContext context, bool isDarkMode, ThemeProvider themeProvider, Color cardColor, Color textColor) {
    final authProvider = context.read<AuthProvider>();
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(MediaQuery.of(context).size.width - 250, kToolbarHeight + MediaQuery.of(context).padding.top, 16, 0),
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
              _buildSettingsItem(Icons.dark_mode, 'Dark Mode', () { themeProvider.toggleTheme(); Navigator.pop(context); }, isDarkMode ? Icons.toggle_on : Icons.toggle_off, textColor),
              Divider(height: 1, color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
              if (!authProvider.isAuthenticated) ...[
                _buildSettingsItem(Icons.login, 'Login', () { Navigator.pop(context); context.push('/login'); }, Icons.arrow_forward_ios, textColor),
                Divider(height: 1, color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
                _buildSettingsItem(Icons.person_add_outlined, 'Sign Up', () { Navigator.pop(context); context.push('/register'); }, Icons.arrow_forward_ios, textColor),
              ] else ...[
                _buildSettingsItem(Icons.person, 'Profile', () { Navigator.pop(context); context.push('/profile'); }, Icons.arrow_forward_ios, textColor),
                Divider(height: 1, color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
                _buildSettingsItem(Icons.receipt_long, 'My Orders', () => Navigator.pop(context), Icons.arrow_forward_ios, textColor),
                Divider(height: 1, color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
                _buildSettingsItem(Icons.logout, 'Logout', () { authProvider.logout(); Navigator.pop(context); }, null, Colors.red),
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
            Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14))),
            if (trailingIcon != null) Icon(trailingIcon, size: 12, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData outlinedIcon, IconData filledIcon, String label, int index, Color textColor, Color subtextColor) {
    final isSelected = _selectedNavIndex == index;
    return InkWell(
      onTap: () => _onNavItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isSelected ? filledIcon : outlinedIcon, color: isSelected ? Colors.black : subtextColor, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? Colors.black : subtextColor)),
        ]),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required Widget child, required Color cardColor, required Color textColor, required bool isDarkMode}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode ? Border.all(color: Color(0xFF2A2A2A), width: 0.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: textColor),
              SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textColor, Color subtextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: subtextColor, fontSize: 14)),
        Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildReviewsCard(
    ReviewProvider reviewProvider,
    Color textColor,
    Color subtextColor,
    Color cardColor,
    bool isDarkMode,
  ) {
    return _buildInfoCard(
      icon: Icons.star_rounded,
      title: 'Reviews',
      cardColor: cardColor,
      textColor: textColor,
      isDarkMode: isDarkMode,
      child: reviewProvider.isLoading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2))
          : reviewProvider.reviews.isEmpty
              ? Text('No reviews yet', style: TextStyle(color: subtextColor, fontSize: 14))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          reviewProvider.averageRating.toStringAsFixed(1),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(5, (index) {
                            final filled = index < reviewProvider.averageRating.round();
                            return Icon(
                              filled ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 18,
                              color: Colors.amber,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${reviewProvider.reviews.length})',
                          style: TextStyle(color: subtextColor, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...reviewProvider.reviews.take(3).map((review) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    review.userName,
                                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13),
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 14,
                                      color: Colors.amber,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            if (review.comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                review.comment,
                                style: TextStyle(color: subtextColor, fontSize: 12, height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
    );
  }

  Widget _buildProductCard(Product product, Color cardColor, Color textColor, Color subtextColor, bool isDarkMode) {
    print('🛒 Product Card: ${product.name}, imageUrl: "${product.imageUrl}"');
    
    return GestureDetector(
      onTap: () => _showProductDetail(product),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black12 : Colors.grey.withOpacity(0.08),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
              child: Stack(
                children: [
                  Image.network(
                    product.imageUrl.isNotEmpty ? product.imageUrl : 'https://picsum.photos/seed/${product.id}/200/200',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 100,
                        height: 100,
                        color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ Product image error: $error for ${product.imageUrl}');
                      return Container(
                        width: 100,
                        height: 100,
                        color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                        child: Icon(Icons.fastfood, color: isDarkMode ? Colors.grey[700] : Colors.grey[400], size: 32),
                      );
                    },
                  ),
                  // Watermark
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'NTWAZA',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      product.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'RWF ${product.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
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
    final backgroundColor = isDarkMode ? Color(0xFF121212) : Colors.grey[50]!;
    final cardColor = isDarkMode ? Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[500]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Consumer<ProductDetailProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.white : Colors.black));
          }
          
          if (provider.error != null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(provider.error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: textColor)),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => provider.initialize(widget.vendor),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.white : Colors.black,
                        foregroundColor: isDarkMode ? Colors.black : Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return Stack(
            children: [
              CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: cardColor,
                leading: Container(
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.more_vert, color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () => _showSettingsMenu(context, isDarkMode, themeProvider, cardColor, textColor),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.vendor.bannerUrl ?? widget.vendor.logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                          child: Center(child: Icon(Icons.restaurant, size: 80, color: isDarkMode ? Colors.grey[700] : Colors.grey[400])),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(widget.vendor.name, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _showInfo = !_showInfo),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(_showInfo ? Icons.close : Icons.info_outline, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 16, color: Colors.amber),
                                    SizedBox(width: 4),
                                    (widget.vendor.totalRatings == 0)
                                      ? Text('New', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600))
                                      : Text(widget.vendor.formattedRating, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                SizedBox(width: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.white70),
                                    SizedBox(width: 4),
                                    Text(widget.vendor.formattedDistance, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isDarkMode ? Border.all(color: Color(0xFF2A2A2A), width: 0.5) : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.vendor.isOpen ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.vendor.isOpen ? Colors.green : Colors.red, shape: BoxShape.circle)),
                            SizedBox(width: 6),
                            Text(widget.vendor.isOpen ? 'Open' : 'Closed', style: TextStyle(color: widget.vendor.isOpen ? Colors.green : Colors.red, fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                      ),
                      Spacer(),
                      if (widget.vendor.formattedDistance != 'D/U') ...[Text(widget.vendor.deliveryFeeDisplay, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      SizedBox(width: 4),
                      Text('delivery', style: TextStyle(color: subtextColor, fontSize: 12)),],
                    ],
                  ),
                ),
              ),
              
              if (!_showInfo) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        provider.searchProducts(value);
                        setState(() {});
                      },
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: TextStyle(color: subtextColor),
                        prefixIcon: Icon(Icons.search, color: subtextColor),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: subtextColor),
                                onPressed: () {
                                  _searchController.clear();
                                  provider.clearSearch();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isDarkMode ? BorderSide(color: Color(0xFF2A2A2A), width: 0.5) : BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isDarkMode ? BorderSide(color: Color(0xFF2A2A2A), width: 0.5) : BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!, width: 1)),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryTabsDelegate(
                    categories: provider.categories,
                    selectedId: provider.selectedCategoryId,
                    onCategoryTap: (id) {
                      if (id == 'all') {
                        // Clear selection to show all categories
                        provider.clearCategorySelection();
                      } else {
                        provider.selectCategory(id);
                      }
                      setState(() {});
                    },
                    isDarkMode: isDarkMode,
                    backgroundColor: backgroundColor,
                    textColor: textColor,
                    cardColor: cardColor,
                    onHamburgerTap: () => _showCategoriesMenu(context, provider, isDarkMode, textColor, cardColor),
                  ),
                ),
                
                if (provider.searchQuery.isEmpty) ...[
                  if (provider.selectedCategoryId == null) ...[
                    // Show ALL categories, always expanded
                    if (provider.products.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 64, color: subtextColor.withOpacity(0.5)),
                                SizedBox(height: 16),
                                Text('No Products Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                                SizedBox(height: 8),
                                Text('Check back later for updates', style: TextStyle(fontSize: 14, color: subtextColor)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final category = provider.categories[index];
                            final products = provider.getProductsForCategory(category.id);
                            if (products.isEmpty) return SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                                  child: Text(category.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                                ),
                                ...products.map((product) => _buildProductCard(product, backgroundColor, textColor, subtextColor, isDarkMode)),
                              ],
                            );
                          },
                          childCount: provider.products.isEmpty ? 0 : provider.categories.length,
                        ),
                      ),
                  ] else ...[
                    SliverPadding(
                      padding: EdgeInsets.only(top: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final products = provider.getProductsForCategory(provider.selectedCategoryId!);
                            if (index >= products.length) return SizedBox.shrink();
                            return _buildProductCard(products[index], backgroundColor, textColor, subtextColor, isDarkMode);
                          },
                          childCount: provider.getProductsForCategory(provider.selectedCategoryId!).length,
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  if (provider.products.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text('No results for "${provider.searchQuery}"', style: TextStyle(color: subtextColor, fontSize: 16)),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(top: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = provider.products[index];
                            return _buildProductCard(product, backgroundColor, textColor, subtextColor, isDarkMode);
                          },
                          childCount: provider.products.length,
                        ),
                      ),
                    ),
                ],
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(
                          icon: Icons.info_outline,
                          title: 'About',
                          child: Text(widget.vendor.description ?? 'Welcome to ${widget.vendor.name}!', style: TextStyle(color: subtextColor, height: 1.5, fontSize: 14)),
                          cardColor: cardColor,
                          textColor: textColor,
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.access_time,
                          title: 'Working Hours',
                          child: _buildWorkingHours(widget.vendor.workingHours, textColor, subtextColor, isDarkMode),
                          cardColor: cardColor,
                          textColor: textColor,
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.delivery_dining,
                          title: 'Delivery Information',
                          child: Column(
                            children: [
                              _buildInfoRow('Delivery Fee', widget.vendor.deliveryFeeDisplay, textColor, subtextColor),
                              SizedBox(height: 12),
                              _buildInfoRow('Estimated Time', widget.vendor.formattedDeliveryTime, textColor, subtextColor),
                              SizedBox(height: 12),
                              _buildInfoRow('Delivery Radius', '${widget.vendor.deliveryRadiusKm.toStringAsFixed(1)} km', textColor, subtextColor),
                              SizedBox(height: 12),
                              _buildInfoRow('Distance', widget.vendor.formattedDistance, textColor, subtextColor),
                            ],
                          ),
                          cardColor: cardColor,
                          textColor: textColor,
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: 16),
                        Consumer<ReviewProvider>(
                          builder: (context, reviewProvider, _) {
                            return _buildReviewsCard(reviewProvider, textColor, subtextColor, cardColor, isDarkMode);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ),
          
          // Blur overlay when vendor is closed
          if (!widget.vendor.isOpen)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 24),
                        constraints: BoxConstraints(maxWidth: 320),
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: (isDarkMode ? Colors.grey[900] : Colors.white)?.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.access_time_filled,
                                size: 32,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Currently Closed',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'This vendor is not accepting orders right now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: subtextColor,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.schedule, size: 16, color: Colors.green),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: GestureDetector(
                                      onTap: _showWorkingHoursDialog,
                                      child: Text(
                                        _getNextOpeningTime(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text('Go Back', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        },
      ),
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, _) {
    if (cart.itemCount == 0) return SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: () => context.push('/cart'), // Use push instead of go
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart, size: 24),
            SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cart.itemCount} items',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'RWF ${cart.totalPrice.toStringAsFixed(0)}', // Changed from cart.total to cart.totalPrice
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            SizedBox(width: 12),
            Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
    },
  ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1), blurRadius: 12, offset: const Offset(0, -4))],
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
      ),
    );
  }
  
  Widget _buildWorkingHours(Map<String, dynamic>? workingHours, Color textColor, Color subtextColor, bool isDarkMode) {
    if (workingHours == null || workingHours.isEmpty) {
      return Text(
        'Working hours not available',
        style: TextStyle(color: subtextColor, fontSize: 14),
      );
    }
    
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    List<Widget> hourWidgets = [];
    
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayName = dayNames[i];
      final dayData = workingHours[day];
      
      if (dayData != null && dayData is Map) {
        final isOpen = dayData['open'] == true;
        final openTime = dayData['open_time'] ?? '09:00';
        final closeTime = dayData['close_time'] ?? '22:00';
        
        if (hourWidgets.isNotEmpty) {
          hourWidgets.add(Divider(height: 20, color: isDarkMode ? Color(0xFF2A2A2A) : Colors.grey[300]));
        }
        
        hourWidgets.add(
          _buildInfoRow(
            dayName,
            isOpen ? '$openTime - $closeTime' : 'Closed',
            textColor,
            isOpen ? subtextColor : Colors.red,
          ),
        );
      }
    }
    
    if (hourWidgets.isEmpty) {
      return Text(
        'Working hours not configured',
        style: TextStyle(color: subtextColor, fontSize: 14),
      );
    }
    
    return Column(children: hourWidgets);
  }
}

class _CategoryTabsDelegate extends SliverPersistentHeaderDelegate {
  final List<ProductCategory> categories;
  final String? selectedId;
  final Function(String) onCategoryTap;
  final bool isDarkMode;
  final Color backgroundColor;
  final Color textColor;
  final Color cardColor;
  final VoidCallback? onHamburgerTap;

  _CategoryTabsDelegate({
    required this.categories,
    required this.selectedId,
    required this.onCategoryTap,
    required this.isDarkMode,
    required this.backgroundColor,
    required this.textColor,
    required this.cardColor,
    this.onHamburgerTap,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = selectedId == null || selectedId == 'all';
                  return GestureDetector(
                    onTap: () => onCategoryTap('all'),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? (isDarkMode ? Colors.white : Colors.black) : cardColor,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)] : null,
                  border: Border.all(color: isDarkMode ? Color(0xFF2A2A2A) : Colors.grey[300]!, width: isSelected ? 0 : 0.5),
                ),
                child: Text('All', style: TextStyle(color: isSelected ? (isDarkMode ? Colors.black : Colors.white) : textColor, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            );
          }
          
          final category = categories[index - 1];
          final isSelected = category.id == selectedId;
          return GestureDetector(
            onTap: () => onCategoryTap(category.id),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? (isDarkMode ? Colors.white : Colors.black) : cardColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)] : null,
                border: Border.all(color: isDarkMode ? Color(0xFF2A2A2A) : Colors.grey[300]!, width: isSelected ? 0 : 0.5),
              ),
              child: Text(category.name, style: TextStyle(color: isSelected ? (isDarkMode ? Colors.black : Colors.white) : textColor, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          );
        },
        ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(Icons.menu, color: textColor, size: 24),
              onPressed: onHamburgerTap,
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 60;

  @override
  double get minExtent => 60;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}