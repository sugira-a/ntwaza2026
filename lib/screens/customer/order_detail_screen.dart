import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/api_service.dart';
import '../../services/payment_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/order_rating_dialog.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Order? initialOrder;
  const OrderDetailScreen({super.key, required this.orderId, this.initialOrder});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _isLoading = true;
  String? _error;
  bool _ratingShown = false;
  bool _isRetryingPayment = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      _isLoading = false;
      _loadOrder(showLoader: false);
    } else {
      _loadOrder();
    }
  }

  Future<void> _loadOrder({bool showLoader = true}) async {
    if (mounted && showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() {
        _error = null;
      });
    }
    try {
      final authProvider = context.read<AuthProvider>();
      final apiService = authProvider.apiService;
      final hasToken = (apiService.authToken ?? apiService.token) != null;

      if (!authProvider.isAuthenticated || !hasToken) {
        if (mounted) {
          setState(() {
            _error = 'Please log in to view order details.';
            _isLoading = false;
          });
        }
        return;
      }

      final response = await apiService.getOrderById(widget.orderId);
      if (response['success'] == true && response['order'] != null) {
        final order = Order.fromJson(response['order']);
        if (mounted) {
          setState(() {
            _order = order;
            _isLoading = false;
          });
          _maybeShowRating();
        }
      } else {
        if (mounted) {
          setState(() {
            _error = response['message'] ?? response['error'] ?? 'Failed to load order details.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _retryPayment() async {
    if (_order == null || _isRetryingPayment) return;
    setState(() => _isRetryingPayment = true);
    try {
      final paymentService = PaymentService();
      final result = await paymentService.initiatePayment(
        orderId: _order!.id,
        paymentMethod: 'momo',
        phoneNumber: _order!.customerPhone ?? '',
      );
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📲 Dial *182# on your phone to approve the payment.'),
              backgroundColor: Color(0xFF1565C0),
              duration: Duration(seconds: 8),
            ),
          );
          // Refresh order to reflect new payment status
          await _loadOrder(showLoader: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to initiate payment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRetryingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allowRefresh = true;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF1F2F4),
      appBar: AppBar(
        title: Text(
          _order == null ? 'Order Details' : 'Order #${_shortOrderId(_order!.orderNumber)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF1F2F4),
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (allowRefresh)
            IconButton(
              onPressed: _loadOrder,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.grey : Colors.grey[400])))
          : _order == null
              ? _buildErrorState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _buildSummaryCard(isDark),
                    const SizedBox(height: 16),
                    if (_order!.status == OrderStatus.cancelled && _order!.cancellationReason != null)
                      _buildCancellationCard(isDark),
                    if (_order!.status == OrderStatus.cancelled && _order!.cancellationReason != null)
                      const SizedBox(height: 16),
                    _buildItemsCard(isDark),
                    const SizedBox(height: 16),
                    _buildDeliveryCard(isDark),
                    const SizedBox(height: 16),
                    _buildPaymentCard(isDark),
                    const SizedBox(height: 16),
                    if (_order!.status == OrderStatus.completed && _order!.vendorRating == null)
                      _buildRateOrderButton(isDark),
                    if (_order!.status == OrderStatus.completed && _order!.vendorRating == null)
                      const SizedBox(height: 16),
                    _buildSupportCard(isDark),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Failed to load order details.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadOrder,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlack,
              foregroundColor: AppTheme.primaryWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final order = _order!;
    final statusInfo = _statusInfo(order.status);
    final vendorName = order.vendorName.trim().isEmpty ? 'Vendor unavailable' : order.vendorName;
    return _CardShell(
      isDark: isDark,
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
                      'Order #${_shortOrderId(order.orderNumber)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEE, MMM d • h:mm a').format(order.createdAt),
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black87,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusInfo.color == AppTheme.primaryBlack
                      ? Colors.white
                      : statusInfo.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: statusInfo.color == AppTheme.primaryBlack
                        ? Colors.black.withOpacity(0.4)
                        : statusInfo.color.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusInfo.icon,
                      size: 14,
                      color: statusInfo.color == AppTheme.primaryBlack
                          ? AppTheme.primaryBlack
                          : statusInfo.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusInfo.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoTile(
                label: 'Vendor',
                value: vendorName,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _InfoTile(
                label: 'Items',
                value: order.itemCount.toString(),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _InfoTile(
                label: 'Total',
                value: 'RWF ${_formatPrice(order.total)}',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(bool isDark) {
    final order = _order!;
    return _CardShell(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Items', subtitle: '${order.itemCount} items', isDark: isDark),
          const SizedBox(height: 12),
          ...order.items.map((item) => _buildItemRow(item, isDark)),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item, bool isDark) {
    final imageUrl = _resolveImageUrl(item.imageUrl);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: imageUrl == null
                ? const Icon(Icons.image, color: Color(0xFF9CA3AF))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Color(0xFF9CA3AF)),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} x RWF ${_formatPrice(item.price)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'RWF ${_formatPrice(item.total)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(bool isDark) {
    final order = _order!;
    final deliveryInfo = order.deliveryInfo;
    final riderName = order.riderName ?? deliveryInfo?.driverName;
    final riderPhone = order.riderPhone ?? deliveryInfo?.driverPhone;

    return _CardShell(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Delivery', subtitle: 'Order progress', isDark: isDark),
          const SizedBox(height: 12),
          _buildTrackingLine(order.status, isDark),
          const SizedBox(height: 12),
          _InfoRow(label: 'Address', value: deliveryInfo?.address ?? 'Not available', isDark: isDark),
          _InfoRow(label: 'Notes', value: deliveryInfo?.notes ?? order.specialInstructions ?? 'None', isDark: isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoTile(label: 'Rider', value: riderName ?? 'Assigning', isDark: isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(label: 'Phone', value: riderPhone ?? '—', isDark: isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(bool isDark) {
    final order = _order!;
    return _CardShell(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Payment', subtitle: order.paymentMethod == 'pay_on_pickup' ? 'PAY ON DELIVERY' : order.paymentMethod.toUpperCase(), isDark: isDark),
          const SizedBox(height: 12),
          _InfoRow(label: 'Subtotal', value: 'RWF ${_formatPrice(order.subtotal)}', isDark: isDark),
          _InfoRow(label: 'Delivery fee', value: 'RWF ${_formatPrice(order.deliveryFee)}', isDark: isDark),
          _InfoRow(label: 'Total', value: 'RWF ${_formatPrice(order.total)}', isDark: isDark),
          _InfoRow(label: 'Payment status', value: order.paymentStatus ?? 'Pending', isDark: isDark),
          if (order.status == OrderStatus.awaitingPayment && order.paymentMethod == 'momo') ...[            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRetryingPayment ? null : _retryPayment,
                icon: _isRetryingPayment
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.payment_rounded, size: 18),
                label: Text(_isRetryingPayment ? 'Processing...' : 'Retry Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCancellationCard(bool isDark) {
    final order = _order!;
    final cancelledBy = order.cancelledBy ?? 'Unknown';
    final cancelledByDisplay = _getCancelledByDisplay(cancelledBy);
    
    return _CardShell(
      isDark: isDark,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A0000) : const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.red.withOpacity(0.3) : Colors.red.withOpacity(0.2),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.cancel,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Cancelled',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cancelled by $cancelledByDisplay',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.red.shade400 : Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A0000) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.cancellationReason ?? 'No reason provided',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (order.cancelledAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Cancelled ${timeAgoFrom(order.cancelledAt!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If you paid for this order, a refund will be processed.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCancelledByDisplay(String cancelledBy) {
    switch (cancelledBy.toLowerCase()) {
      case 'customer':
        return 'you';
      case 'vendor':
        return 'the vendor';
      case 'rider':
        return 'the rider';
      case 'admin':
        return 'admin';
      default:
        return cancelledBy;
    }
  }

  /// Automatically show the rating dialog once for delivered orders that haven't been rated.
  void _maybeShowRating() {
    if (_ratingShown) return;
    if (_order == null) return;
    if (_order!.status != OrderStatus.completed) return;
    if (_order!.vendorRating != null) return; // already rated

    _ratingShown = true;
    // Delay so the screen renders first
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _showRatingDialog();
    });
  }

  Future<void> _showRatingDialog() async {
    final authProvider = context.read<AuthProvider>();
    final apiService = authProvider.apiService;

    final submitted = await OrderRatingDialog.show(
      context,
      orderId: widget.orderId,
      vendorName: _order!.vendorName.trim().isEmpty ? 'Vendor' : _order!.vendorName,
      riderName: _order!.riderName,
      hasRider: _order!.riderId != null,
      apiService: apiService,
    );

    if (submitted && mounted) {
      _loadOrder(showLoader: false); // Refresh to get updated rating
    }
  }

  Widget _buildRateOrderButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _showRatingDialog,
        icon: const Icon(Icons.star_rounded, size: 22),
        label: const Text(
          'Rate Your Experience',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB800),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportCard(bool isDark) {
    final order = _order!;
    final vendorName = order.vendorName.trim().isEmpty ? 'Vendor unavailable' : order.vendorName;
    return _CardShell(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Vendor', subtitle: vendorName, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildTrackingLine(OrderStatus status, bool isDark) {
    final activeColor = const Color(0xFF22C55E);
    final inactiveColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final currentIndex = _trackingStepIndex(status);
    const totalSteps = 4;

    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentIndex;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? activeColor : inactiveColor,
                ),
                child: isActive
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
              if (index < totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: isActive ? activeColor : inactiveColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  int _trackingStepIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        return 0;
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return 1;
      case OrderStatus.pickedUp:
        return 2;
      case OrderStatus.completed:
        return 3;
      case OrderStatus.cancelled:
        return 0;
    }
  }

  String _shortOrderId(String orderNumber) {
    if (orderNumber.isEmpty) return orderNumber;
    const keep = 6;
    return orderNumber.length <= keep
        ? orderNumber
        : orderNumber.substring(orderNumber.length - keep);
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

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  _StatusView _statusInfo(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
        return _StatusView('Awaiting Payment', Icons.payment, const Color(0xFFF97316));
      case OrderStatus.pending:
        return _StatusView('Pending', Icons.schedule, const Color(0xFFF59E0B));
      case OrderStatus.confirmed:
        return _StatusView('Confirmed', Icons.check_circle, AppTheme.primaryBlack);
      case OrderStatus.preparing:
        return _StatusView('Preparing', Icons.restaurant_rounded, AppTheme.primaryBlack);
      case OrderStatus.ready:
        return _StatusView('Ready', Icons.done_all, AppTheme.accentGreen);
      case OrderStatus.pickedUp:
        return _StatusView('On The Way', Icons.two_wheeler_rounded, AppTheme.primaryBlack);
      case OrderStatus.completed:
        return _StatusView('Completed', Icons.check_circle, const Color(0xFF10B981));
      case OrderStatus.cancelled:
        return _StatusView('Cancelled', Icons.cancel, const Color(0xFFEF4444));
    }
  }
}

class _CardShell extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _CardShell({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE3E5E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0F0F),
                  Color(0xFF1A1A1A),
                ],
              )
            : null,
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;
  const _SectionHeader({required this.title, required this.subtitle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _InfoRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black87,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _InfoTile({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE3E5E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusView {
  final String label;
  final IconData icon;
  final Color color;
  _StatusView(this.label, this.icon, this.color);
}
