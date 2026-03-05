// lib/screens/customer/wishlist_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../models/product.dart';
import '../../models/vendor.dart';
import '../vendor/widgets/product_detail_modal.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  static const _brand = Color(0xFF1B5E20);
  static const _brandLight = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F6F8);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isDark),
          Consumer<WishlistProvider>(
            builder: (context, wishlist, _) {
              if (wishlist.isEmpty) return SliverFillRemaining(child: _buildEmpty(isDark));
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildProductTile(ctx, wishlist.wishlistProducts[i], isDark),
                    childCount: wishlist.wishlistProducts.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFF0B0F14),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                  : [const Color(0xFF0B0F14), const Color(0xFF1B2028)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 26),
                      const SizedBox(width: 10),
                      const Text('My Wishlist', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Consumer<WishlistProvider>(
                    builder: (_, w, __) => Text(
                      '${w.count} ${w.count == 1 ? 'item' : 'items'} saved',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Consumer<WishlistProvider>(
          builder: (context, wishlist, _) {
            if (wishlist.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
              tooltip: 'Clear wishlist',
              onPressed: () => _confirmClear(context),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductTile(BuildContext context, Product product, bool isDark) {
    final card = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final pText = isDark ? Colors.white : const Color(0xFF111111);
    final sText = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () => _openProductDetail(context, product),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                product.imageUrl.isNotEmpty ? product.imageUrl : 'https://picsum.photos/seed/${product.id}/200/200',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: Icon(Icons.fastfood, color: Colors.grey[400], size: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pText), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (product.vendorName != null)
                    Text(product.vendorName!, style: TextStyle(fontSize: 12, color: sText), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('RWF ${product.price.toStringAsFixed(0)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _brandLight)),
                      if (product.originalPrice != null && product.originalPrice! > product.price) ...[
                        const SizedBox(width: 6),
                        Text('RWF ${product.originalPrice!.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: sText, decoration: TextDecoration.lineThrough)),
                      ],
                    ],
                  ),
                  if (!product.isAvailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Out of stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red[400])),
                    ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                // Remove from wishlist
                IconButton(
                  icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 22),
                  onPressed: () {
                    context.read<WishlistProvider>().removeFromWishlist(product.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${product.name} removed'), duration: const Duration(seconds: 1)),
                    );
                  },
                ),
                // Add to cart
                if (product.isAvailable)
                  IconButton(
                    icon: Icon(Icons.add_shopping_cart_rounded, color: _brandLight, size: 22),
                    onPressed: () {
                      context.read<CartProvider>().addToCart(product, vendorId: product.vendorId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${product.name} added to cart'), duration: const Duration(seconds: 1)),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _openProductDetail(BuildContext context, Product product) {
    // Build a minimal vendor from product data
    final vendorProvider = context.read<VendorProvider>();
    Vendor? vendor;
    try {
      vendor = vendorProvider.vendors.firstWhere((v) => v.id == product.vendorId);
    } catch (_) {
      vendor = Vendor(
        id: product.vendorId,
        name: product.vendorName ?? 'Store',
        category: 'Store',
        vendorType: VendorType.product,
        logoUrl: '',
        rating: 0, totalRatings: 0,
        latitude: 0, longitude: 0,
        prepTimeMinutes: 0, deliveryFee: 0,
        isOpen: true,
      );
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProductDetailModal(product: product, vendor: vendor!),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withOpacity(0.1)),
            child: const Icon(Icons.favorite_border_rounded, color: Colors.redAccent, size: 30),
          ),
          const SizedBox(height: 14),
          Text('No saved items yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF111111))),
          const SizedBox(height: 6),
          Text('Tap the heart on products you love.', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Wishlist'),
        content: const Text('Remove all items from your wishlist?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<WishlistProvider>().clearWishlist();
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
