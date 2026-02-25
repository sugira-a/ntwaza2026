import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pickup_order_provider.dart';
import '../../models/pickup_order.dart';
import '../../core/theme/app_theme.dart';

class PickupOrdersScreen extends StatefulWidget {
  const PickupOrdersScreen({super.key});

  @override
  State<PickupOrdersScreen> createState() => _PickupOrdersScreenState();
}

class _PickupOrdersScreenState extends State<PickupOrdersScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.user?.id == null) {
      setState(() {
        _error = 'Please log in to view your pickup orders.';
      });
      return;
    }

    final provider = context.read<PickupOrderProvider>();
    await provider.fetchCustomerPickupOrders(auth.user!.id!);

    if (!mounted) return;
    if (provider.error != null) {
      setState(() {
        _error = provider.error;
      });
    } else {
      setState(() {
        _error = null;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF1F2F4);
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final provider = context.watch<PickupOrderProvider>();
    final orders = [...provider.pickupOrders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text('Pickup Orders'),
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-pickup-order'),
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add),
        label: const Text('New Pickup'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Builder(
          builder: (context) {
            if (_error != null) {
              return _buildErrorState(textPrimary, textSecondary);
            }
            if (provider.isLoading) {
              return _buildLoadingState(textPrimary, textSecondary);
            }
            if (orders.isEmpty) {
              return _buildEmptyState(textPrimary, textSecondary);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _buildOrderCard(order, isDark, textPrimary, textSecondary);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState(Color textPrimary, Color textSecondary) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading pickup orders...', style: TextStyle(color: textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Color textPrimary, Color textSecondary) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 56, color: textSecondary),
              const SizedBox(height: 12),
              Text(_error ?? 'Something went wrong', style: TextStyle(color: textPrimary, fontSize: 16)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadOrders,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.local_shipping_outlined, size: 64, color: textSecondary),
              const SizedBox(height: 12),
              Text('No pickup orders yet', style: TextStyle(color: textPrimary, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Create your first pickup order to get started.', style: TextStyle(color: textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/create-pickup-order'),
                icon: const Icon(Icons.add),
                label: const Text('Create Pickup Order'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(
    PickupOrder order,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final cardColor = isDark ? const Color(0xFF111111) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.statusDisplay,
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scheduled: ${order.formattedScheduledTime}',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 18, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(order.pickupLocation.address, style: TextStyle(color: textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.flag, size: 18, color: Color(0xFFEF6C00)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(order.dropoffLocation.address, style: TextStyle(color: textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Total', style: TextStyle(color: textSecondary, fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                'RWF ${order.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(order.itemCountDisplay, style: TextStyle(color: textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
