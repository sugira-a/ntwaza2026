// lib/screens/vendor/vendor_products_screen.dart
// ULTRA-MODERN VENDOR PRODUCTS MANAGEMENT - HORIZONTAL LAYOUT

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/product.dart';
import '../../utils/helpers.dart';
import '../../services/api/api_service.dart';

class VendorProductsScreen extends StatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  State<VendorProductsScreen> createState() => _VendorProductsScreenState();
}

class _VendorProductsScreenState extends State<VendorProductsScreen> {
  late String _vendorId;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  late TextEditingController _searchController;
  String _sortBy = 'name'; // name, price, stock
  final Map<String, Future<Uint8List?>> _imageFutureCache = {};
  bool _hasLoadedVendor = false;
  bool _hideOutOfStock = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _vendorId = context.read<AuthProvider>().user?.id ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_vendorId.isNotEmpty) {
        _loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final user = context.read<AuthProvider>().user;
    final isRestaurant = _isRestaurant(user);
    
    print('🛍️ Loading products for vendor: $_vendorId (Restaurant: $isRestaurant)');
    await context.read<ProductProvider>().fetchVendorProducts(
      _vendorId,
      isRestaurant: isRestaurant,
    );
  }

  bool _isRestaurant(user) {
    if (user == null) return false;
    final businessType = user.businessType?.toLowerCase() ?? '';
    final vendorType = user.vendorType?.toLowerCase() ?? '';
    return businessType.contains('restaurant') || 
           vendorType.contains('restaurant') ||
           user.usesMenuSystem == true;
  }

  List<String> _getCategories(List<Product> products) {
    final categories = <String>{};
    for (var product in products) {
      if (product.category != null && product.category!.isNotEmpty) {
        categories.add(product.category!);
      }
    }
    return ['All', ...categories.toList()..sort()];
  }

  List<Product> _sortProducts(List<Product> products) {
    final sorted = List<Product>.from(products);
    switch (_sortBy) {
      case 'price':
        sorted.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
        break;
      case 'stock':
        sorted.sort((a, b) => (b.stockQuantity ?? 0).compareTo(a.stockQuantity ?? 0));
        break;
      case 'name':
      default:
        sorted.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    }
    return sorted;
  }

  bool _isProductAvailable(Product product) {
    final stock = product.stockQuantity;
    if (stock != null) return stock > 0;
    return product.isAvailable;
  }
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isRestaurant = _isRestaurant(user);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final productProvider = context.watch<ProductProvider>();
    
    final config = isRestaurant
        ? VendorProductConfig(
            title: 'Menu',
            subtitle: 'Manage your menu items',
            icon: Icons.restaurant_menu_rounded,
            addLabel: 'Add Menu Item',
            emptyTitle: 'No menu items yet',
            emptyMessage: 'Add your first dish to get started',
          )
        : VendorProductConfig(
            title: 'Products',
            subtitle: 'Manage your product inventory',
            icon: Icons.inventory_2_rounded,
            addLabel: 'Add Product',
            emptyTitle: 'No products yet',
            emptyMessage: 'Add your first product to get started',
          );

    if (!_hasLoadedVendor && user?.id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _vendorId = user!.id!;
          _hasLoadedVendor = true;
        });
        _loadProducts();
      });
    }

    final allProducts = productProvider.getProductsByVendor(_vendorId);
    final categories = _getCategories(allProducts);
    
    var filteredProducts = allProducts;
    if (_selectedCategory != 'All') {
      filteredProducts = filteredProducts
          .where((p) => p.category == _selectedCategory)
          .toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      filteredProducts = filteredProducts
          .where((p) => 
              p.name!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (p.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
          .toList();
    }

    filteredProducts = _sortProducts(filteredProducts);

    if (_hideOutOfStock) {
      filteredProducts = filteredProducts
          .where(_isProductAvailable)
          .toList();
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF202124) : Colors.white,
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        color: isDark ? Colors.white : Colors.black,
        child: CustomScrollView(
          slivers: [
            // MODERN HEADER
            SliverAppBar(
              expandedHeight: 70,
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF202124) : Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF202124) : Colors.white,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.title,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    color: isDark ? Colors.white : Colors.black,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${filteredProducts.length} ${filteredProducts.length == 1 ? 'item' : 'items'} • ${_selectedCategory}',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildActionButton(
                            icon: Icons.tune_rounded,
                            onTap: () => _showSortSheet(isDark),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            icon: Icons.refresh_rounded,
                            onTap: _loadProducts,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // SEARCH BAR
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2D2F) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: isDark ? Colors.white : Colors.black,
                    decoration: InputDecoration(
                      hintText: 'Search ${config.title.toLowerCase()}...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // CATEGORY CHIPS
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = category),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: isDark
                                        ? [Colors.white, Colors.grey[200]!]
                                        : [Colors.black, Colors.grey[800]!],
                                  )
                                : null,
                            color: !isSelected
                              ? (isDark ? const Color(0xFF2A2D2F) : Colors.white)
                              : null,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!),
                              width: isSelected ? 0 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // CONTENT
            if (productProvider.isLoading)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 400,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            color: isDark ? Colors.white : Colors.black,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading ${config.title.toLowerCase()}...',
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filteredProducts.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState(config, isDark),
              )
            else
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final useGrid = constraints.crossAxisExtent >= 520;
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: useGrid
                        ? SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildProductCard(
                                filteredProducts[index],
                                isDark,
                                isGrid: true,
                              ),
                              childCount: filteredProducts.length,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              mainAxisExtent: 180,
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildProductCard(
                                  filteredProducts[index],
                                  isDark,
                                ),
                              ),
                              childCount: filteredProducts.length,
                            ),
                          ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1A1A)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isDark, {bool isGrid = false}) {
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    final isInStock = _isProductAvailable(product);
    final cardColor = isDark ? const Color(0xFF202124) : Colors.white;
    final cardBorder = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    
    return GestureDetector(
      onTap: () => _showProductDetailsSheet(product, isDark),
      child: Container(
        height: isGrid ? 160 : 96,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isGrid
            ? Column(
                children: [
                  Container(
                    height: 84,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B1F) : Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (hasImage)
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            child: _buildNetworkImageWithFallback(
                              product.imageUrl!,
                              isDark,
                              width: double.infinity,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          _buildImagePlaceholder(isDark),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isInStock ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                              child: Text(
                                isInStock ? 'In Stock' : 'Out',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name ?? 'Unknown Product',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (product.category != null && product.category!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              product.category!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[600] : Colors.grey[500],
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rwf ${(product.price ?? 0).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  if (product.unit != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'per ${product.unit}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              _buildStockPill(product, isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  // Product Image
                  Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B1F) : Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (hasImage)
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            child: _buildNetworkImageWithFallback(
                              product.imageUrl!,
                              isDark,
                              width: 100,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          _buildImagePlaceholder(isDark),
                        
                        // Stock Badge
                        Positioned(
                          top: 10,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isInStock ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              isInStock ? 'In Stock' : 'Out',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Product Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            product.name ?? 'Unknown Product',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (product.category != null && product.category!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              product.category!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[600] : Colors.grey[500],
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rwf ${(product.price ?? 0).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (product.unit != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'per ${product.unit}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              _buildStockPill(product, isDark, isCompact: true),
                            ],
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

  Widget _buildStockPill(Product product, bool isDark, {bool isCompact = false}) {
    final stock = product.stockQuantity;
    final isAvailable = _isProductAvailable(product);
    final label = stock == null
        ? (isAvailable ? 'Available' : 'Out')
        : (stock > 0 ? '$stock' : 'Out');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 7,
        vertical: isCompact ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_rounded,
            size: isCompact ? 12 : 11,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 12 : 11,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1B1B1F) : Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_rounded,
              size: 36,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 6),
            Text(
              'No Image',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _imageCandidates(String imageUrl) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return [];

    final candidates = <String>{trimmed};
    final uri = Uri.tryParse(trimmed);
    final path = uri?.path ?? trimmed;
    final filename = path.split('/').last;

    if (filename.isNotEmpty) {
      candidates.add('${ApiService.baseUrl}/static/uploads/products/$filename');
      candidates.add('${ApiService.baseUrl}/static/uploads/catalog/$filename');
      candidates.add('${ApiService.baseUrl}/static/uploads/$filename');
    }

    return candidates.toList();
  }

  Widget _buildNetworkImageWithFallback(
    String imageUrl,
    bool isDark, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    final candidates = _imageCandidates(imageUrl);
    if (candidates.isEmpty) return _buildImagePlaceholder(isDark);
    final token = context.read<AuthProvider>().token;
    final headers = (token != null && token.isNotEmpty)
        ? {'Authorization': 'Bearer $token'}
        : null;

    if (kIsWeb) {
      final cacheKey = candidates.join('|');
      final cachedFuture = _imageFutureCache.putIfAbsent(
        cacheKey,
        () => _fetchFirstAvailableImageBytes(candidates, headers),
      );
      return FutureBuilder<Uint8List?>(
        future: cachedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: width,
              height: height,
              color: isDark ? const Color(0xFF1B1B1F) : Colors.grey[100],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final bytes = snapshot.data;
          if (bytes == null) return _buildImagePlaceholder(isDark);

          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
          );
        },
      );
    }

    Widget buildAt(int index) {
      final url = candidates[index];
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        headers: headers,
        errorBuilder: (_, __, ___) {
          print('❌ Image load failed: $url');
          if (index + 1 < candidates.length) {
            return buildAt(index + 1);
          }
          return _buildImagePlaceholder(isDark);
        },
      );
    }

    return buildAt(0);
  }

  Future<Uint8List?> _fetchFirstAvailableImageBytes(
    List<String> candidates,
    Map<String, String>? headers,
  ) async {
    for (final url in candidates) {
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final contentType = response.headers['content-type'] ?? '';
          if (!contentType.startsWith('image/')) {
            print('❌ Non-image response ($contentType): $url');
            continue;
          }
          return response.bodyBytes;
        }
        print('❌ Image load failed (${response.statusCode}): $url');
      } catch (e) {
        print('❌ Image load error: $url ($e)');
      }
    }
    return null;
  }

  Widget _buildEmptyState(VendorProductConfig config, bool isDark) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1A1A), const Color(0xFF2A2A2A)]
                      : [Colors.grey[100]!, Colors.grey[200]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                config.icon,
                size: 48,
                color: isDark ? Colors.grey[700] : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _searchQuery.isNotEmpty ? 'No items found' : config.emptyTitle,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search'
                  : config.emptyMessage,
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Sort By',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildSortOption('Name', 'name', Icons.sort_by_alpha_rounded, isDark),
            _buildSortOption('Price', 'price', Icons.attach_money_rounded, isDark),
            _buildSortOption('Stock', 'stock', Icons.inventory_2_rounded, isDark),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon, bool isDark) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sortBy = value);
        if (context.canPop()) {
          context.pop();
        } else {
          Navigator.pop(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey[600] : Colors.grey[500]),
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: isDark ? Colors.white : Colors.black,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  void _showProductDetailsSheet(Product product, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final imageHeight = screenHeight * 0.24;
        final stockLabel = product.stockQuantity == null
            ? (_isProductAvailable(product) ? 'Available' : 'Out')
            : (product.stockQuantity! > 0 ? '${product.stockQuantity}' : 'Out');
        return SizedBox(
          height: screenHeight,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: true,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      
                      // Product Image
                      if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                        Container(
                          height: imageHeight,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _buildNetworkImageWithFallback(
                              product.imageUrl!,
                              isDark,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                  
                  Text(
                    product.name ?? 'Product',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  if (product.description != null && product.description!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.description!,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[800],
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Price',
                          'Rwf ${(product.price ?? 0).toStringAsFixed(0)}',
                          Icons.payments_rounded,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Stock',
                          stockLabel,
                          Icons.inventory_2_rounded,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  
                  if (product.unit != null || product.category != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (product.unit != null)
                          Expanded(
                            child: _buildStatCard(
                              'Unit',
                              product.unit!,
                              Icons.scale_rounded,
                              isDark,
                            ),
                          ),
                        if (product.unit != null && product.category != null)
                          const SizedBox(width: 12),
                        if (product.category != null)
                          Expanded(
                            child: _buildStatCard(
                              'Category',
                              product.category!,
                              Icons.category_rounded,
                              isDark,
                            ),
                          ),
                      ],
                    ),
                  ],
                  
                  _buildModifiersSection(product, isDark),
                  const SizedBox(height: 24),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showComingSoonDialog(context),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(isDark ? 0.18 : 0.08),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.red.withOpacity(0.4)),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModifiersSection(Product product, bool isDark) {
    final modifiers = product.modifiers ?? [];
    if (modifiers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Modifiers',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        ...modifiers.map((modifier) {
          final requirement = modifier.isRequired ? 'Required' : 'Optional';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        modifier.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      requirement,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (modifier.description != null && modifier.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    modifier.description!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[700],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: modifier.options.map((option) {
                    final priceTag = option.priceAdjustment > 0
                        ? ' +RWF ${option.priceAdjustment.toStringAsFixed(0)}'
                        : '';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111111) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        '${option.name}$priceTag',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[200] : Colors.grey[800],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showEditProductSheet(Product product, bool isDark) {
    final nameController = TextEditingController(text: product.name);
    final descriptionController = TextEditingController(text: product.description);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Edit Product',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final description = descriptionController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Name is required.')),
                                );
                                return;
                              }
                              if (description.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Description is required.')),
                                );
                                return;
                              }

                              try {
                                await ApiService().put(
                                  '/api/products/${product.id}',
                                  {
                                    'name': name,
                                    'description': description,
                                  },
                                );
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                await _loadProducts();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Product updated.')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Update failed: $e')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : Colors.black,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.grey[600] : Colors.grey[700],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[700],
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              textBaseline: TextBaseline.alphabetic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Coming Soon',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        content: Text(
          'Product management features are coming soon! You will be able to add, edit, and delete products directly from your mobile app.',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontSize: 14,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              elevation: 0,
            ),
            child: const Text(
              'Got it',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================

class VendorProductConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final String addLabel;
  final String emptyTitle;
  final String emptyMessage;

  VendorProductConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.addLabel,
    required this.emptyTitle,
    required this.emptyMessage,
  });
}