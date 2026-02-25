import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/api_service.dart';
import '../../core/theme/app_theme.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final apiService = authProvider.apiService;

      final hasToken = (apiService.authToken ?? apiService.token) != null;
      if (!authProvider.isAuthenticated || !hasToken) {
        setState(() {
          _error = 'Please log in to view your orders.';
          _isLoading = false;
        });
        return;
      }

      final response = await apiService.getOrders();
      
      if (response['success'] == true) {
        final ordersData = response['orders'] ?? response['data'] ?? response['results'] ?? [];
        if (ordersData is! List) {
          setState(() {
            _error = 'Unexpected response from server.';
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _orders = ordersData.map((json) => Order.fromJson(json)).toList();
          _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? response['error'] ?? 'Failed to load orders';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = _parseOrderError(e.toString());
        _isLoading = false;
      });
    }
  }

  String _parseOrderError(String error) {
    var cleaned = error
        .replaceAll('Exception: Failed to perform GET request: ', '')
        .replaceAll('Exception: API Error: ', '')
        .replaceAll('Exception: ', '');

    if (cleaned.contains('401') || cleaned.toLowerCase().contains('unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    if (cleaned.toLowerCase().contains('forbidden') || cleaned.contains('403')) {
      return 'Access denied. Please log in again.';
    }
    if (cleaned.toLowerCase().contains('failed to fetch') || cleaned.toLowerCase().contains('network')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (cleaned.toLowerCase().contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    return cleaned.isEmpty ? 'Failed to load orders. Please try again.' : cleaned;
  }

  List<Order> _getFilteredOrders(String filter) {
    switch (filter) {
      case 'active':
        return _orders.where((order) => 
          order.status == OrderStatus.pending ||
          order.status == OrderStatus.confirmed ||
          order.status == OrderStatus.preparing ||
          order.status == OrderStatus.ready ||
          order.status == OrderStatus.pickedUp
        ).toList();
      case 'completed':
        return _orders.where((order) => 
          order.status == OrderStatus.completed
        ).toList();
      case 'cancelled':
        return _orders.where((order) => 
          order.status == OrderStatus.cancelled
        ).toList();
      default:
        return _orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF1F2F4);
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    Widget content;
    if (_isLoading) {
      content = _buildLoadingState(textPrimary, textSecondary);
    } else if (_error != null) {
      content = _buildErrorState();
    } else {
      content = TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList('active'),
          _buildOrdersList('completed'),
          _buildOrdersList('cancelled'),
        ],
      );
    }

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        children: [
          _buildBackground(isDark),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 230,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.white,
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  title: const Text(
                    'My Orders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  background: _buildHeaderBackground(isDark),
                ),
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(12),
                  child: SizedBox(height: 12),
                ),
              ),
              SliverFillRemaining(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey<String>(_isLoading ? 'loading' : _error != null ? 'error' : 'content'),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF1F2F4),
            isDark ? const Color(0xFF121212) : const Color(0xFFF6F7F9),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen.withOpacity(isDark ? 0.10 : 0.12),
              ),
            ),
          ),
          Positioned(
            left: -80,
            top: 120,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(isDark ? 0.03 : 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(bool isDark) {
    final activeCount = _getFilteredOrders('active').length;
    final completedCount = _getFilteredOrders('completed').length;
    final cancelledCount = _getFilteredOrders('cancelled').length;
    final selectedIndex = _tabController.index;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF0A0A0A) : const Color(0xFF0B0F14),
            isDark ? const Color(0xFF151515) : const Color(0xFF1B2028),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: 20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen.withOpacity(0.18),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track progress, revisit receipts, and stay on top of every delivery.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatChip(
                        label: 'Active',
                        value: activeCount,
                        color: AppTheme.accentGreen,
                        isDark: isDark,
                        isSelected: selectedIndex == 0,
                        onTap: () => _tabController.animateTo(0),
                      ),
                      _buildStatChip(
                        label: 'Completed',
                        value: completedCount,
                        color: const Color(0xFF22C55E),
                        isDark: isDark,
                        isSelected: selectedIndex == 1,
                        onTap: () => _tabController.animateTo(1),
                      ),
                      _buildStatChip(
                        label: 'Cancelled',
                        value: cancelledCount,
                        color: const Color(0xFFF97316),
                        isDark: isDark,
                        isSelected: selectedIndex == 2,
                        onTap: () => _tabController.animateTo(2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required int value,
    required Color color,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final background = isSelected
        ? Colors.white
        : Colors.white.withOpacity(isDark ? 0.08 : 0.16);
    final textColor = isSelected ? const Color(0xFF0B0F14) : Colors.white;
    final borderColor = isSelected
        ? Colors.white.withOpacity(0.8)
        : Colors.white.withOpacity(0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$label $value',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your orders',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This usually takes just a moment',
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String filter) {
    final filteredOrders = _getFilteredOrders(filter);

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: filteredOrders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                const SizedBox(height: 80),
                _buildEmptyState(filter),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              itemCount: filteredOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 260 + (index * 30)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: _OrderCard(
                    order: order,
                    onTap: () {
                      context.push('/order/${order.id}', extra: order);
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(String filter) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String message;
    IconData icon;
    
    switch (filter) {
      case 'active':
        message = 'No active orders';
        icon = Icons.shopping_bag_outlined;
        break;
      case 'completed':
        message = 'No completed orders yet';
        icon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        message = 'No cancelled orders';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'No orders found';
        icon = Icons.inbox_outlined;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151A22) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen.withOpacity(0.12),
              ),
              child: Icon(icon, color: AppTheme.accentGreen, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'New orders will show up here as soon as they are placed.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151A22) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withOpacity(0.12),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 34,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Orders unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'We could not load your orders. Please try again.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlack,
                foregroundColor: AppTheme.primaryWhite,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modern Order Card Component
class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusInfo = _getStatusInfo(order.status);
    final imageUrl = _resolveImageUrl(
      order.items.isNotEmpty ? order.items.first.imageUrl : null,
    );
    final cardGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0C0C0C),
              Color(0xFF161616),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF3F4F6),
            ],
          );
    final primaryText = isDark ? Colors.white : const Color(0xFF111111);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF525252);
    final dividerColor = isDark ? Colors.white.withOpacity(0.14) : const Color(0xFFE4E6EB);
    final borderColor = isDark ? Colors.white.withOpacity(0.14) : const Color(0xFFD7DCE2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B0F14) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            gradient: cardGradient,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(order.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusInfo.color == AppTheme.primaryBlack
                            ? Colors.white
                            : statusInfo.color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusInfo.color == AppTheme.primaryBlack
                              ? Colors.black.withOpacity(0.4)
                              : statusInfo.color.withOpacity(0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusInfo.icon,
                            size: 12,
                            color: statusInfo.color == AppTheme.primaryBlack
                                ? AppTheme.primaryBlack
                                : statusInfo.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusInfo.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusInfo.color == AppTheme.primaryBlack
                                  ? AppTheme.primaryBlack
                                  : statusInfo.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: dividerColor,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.accentGreen.withOpacity(0.14)
                            : const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: borderColor,
                        ),
                      ),
                      child: imageUrl == null
                          ? const Icon(
                              Icons.storefront,
                              size: 22,
                              color: AppTheme.accentGreen,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  size: 20,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.vendorName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RWF ${_formatPrice(order.total)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.status == OrderStatus.pickedUp || order.status == OrderStatus.ready)
                      ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          foregroundColor: AppTheme.primaryWhite,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Track',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      )
                    else
                      OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryText,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.4)
                                : const Color(0xFFD1D5DB),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Details',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
  }

  _StatusInfo _getStatusInfo(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return _StatusInfo(
          label: 'Pending',
          icon: Icons.schedule,
          color: const Color(0xFFF59E0B),
        );
      case OrderStatus.confirmed:
        return _StatusInfo(
          label: 'Confirmed',
          icon: Icons.check_circle,
          color: AppTheme.primaryBlack,
        );
      case OrderStatus.preparing:
        return _StatusInfo(
          label: 'Preparing',
          icon: Icons.restaurant,
          color: AppTheme.primaryBlack,
        );
      case OrderStatus.ready:
        return _StatusInfo(
          label: 'Ready',
          icon: Icons.done_all,
          color: AppTheme.accentGreen,
        );
      case OrderStatus.pickedUp:
        return _StatusInfo(
          label: 'On The Way',
          icon: Icons.delivery_dining,
          color: AppTheme.primaryBlack,
        );
      case OrderStatus.completed:
        return _StatusInfo(
          label: 'Completed',
          icon: Icons.check_circle,
          color: const Color(0xFF10B981),
        );
      case OrderStatus.cancelled:
        return _StatusInfo(
          label: 'Cancelled',
          icon: Icons.cancel,
          color: const Color(0xFFEF4444),
        );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE, h:mm a').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String? _resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    final trimmed = imageUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) return trimmed;
    if (trimmed.startsWith('/')) {
      return '${ApiService.baseUrl}$trimmed';
    }
    return '${ApiService.baseUrl}/$trimmed';
  }
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color color;

  _StatusInfo({
    required this.label,
    required this.icon,
    required this.color,
  });
}
