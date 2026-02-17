import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../providers/rider_order_provider.dart';
import '../../services/external_maps_service.dart';
import '../../utils/helpers.dart';

extension FirstWhereOrNull<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class RiderOrderDetailScreen extends StatefulWidget {
  final Order order;
  const RiderOrderDetailScreen({super.key, required this.order});

  @override
  State<RiderOrderDetailScreen> createState() => _RiderOrderDetailScreenState();
}

class _RiderOrderDetailScreenState extends State<RiderOrderDetailScreen> {
  // Neutral palette + green accent
  static const Color primaryColor = Color(0xFF111111);
  static const Color successColor = Color(0xFF1F1F1F);
  static const Color successLight = Color(0xFFDADDE2);
  static const Color warningColor = Color(0xFF2A2A2A);
  static const Color warningLight = Color(0xFFDADDE2);
  static const Color infoColor = Color(0xFF111111);
  static const Color infoLight = Color(0xFFDADDE2);
  static const Color errorColor = Color(0xFF3A3A3A);
  static const Color errorLight = Color(0xFFDADDE2);
  static const Color neutralGray = Color(0xFF6B7280);
  static const Color lightGray = Color(0xFFE5E7EB);
  static const Color darkGray = Color(0xFF0B0B0B);
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color accentGreen = Color(0xFF4CAF50);

  late Order _currentOrder;
  bool _isUpdating = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _refreshOrderDetails();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrderDetails() async {
    final prov = context.read<RiderOrderProvider>();
    try {
      await prov.fetchAssignedOrders();
      if (mounted) {
        final updatedOrder = prov.orders.firstWhereOrNull((o) => o.id == _currentOrder.id);
        if (updatedOrder != null) {
          setState(() {
            _currentOrder = updatedOrder;
          });
        }
      }
    } catch (e) {
      print('Error refreshing order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.read<RiderOrderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : darkGray;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFDADDE2),
      appBar: AppBar(
        title: Text(
          'Order ${shortenOrderNumber(_currentOrder.orderNumber)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(isDark),
            const SizedBox(height: 16),

            if (_currentOrder.estimatedArrivalTime != null) ...[
              _buildEstimatedTimeCard(isDark),
              const SizedBox(height: 16),
            ],

            _buildCustomerSection(isDark),
            const SizedBox(height: 16),

            _buildVendorSection(isDark),
            const SizedBox(height: 16),

            _buildPaymentSection(isDark),
            const SizedBox(height: 16),

            _buildDeliverySection(isDark),
            const SizedBox(height: 16),

            _buildOrderItemsSection(isDark),
            const SizedBox(height: 16),

            _buildPricingSection(isDark),
            const SizedBox(height: 24),

            _buildStatusButtons(context, prov, isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimatedTimeCard(bool isDark) {
    final now = nowInRwanda();
    final estimatedTime = toRwandaTime(_currentOrder.estimatedArrivalTime!);
    final difference = estimatedTime.difference(now);
    final isLate = difference.isNegative;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLate 
              ? [errorColor, const Color(0xFF2F2F2F)]
              : [successColor, const Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isLate ? errorColor : successColor).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLate ? Icons.warning_amber_rounded : Icons.schedule_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isLate ? 'Delivery Overdue' : 'Estimated Arrival',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatRwandaTime(estimatedTime, 'hh:mm a'),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatRwandaTime(estimatedTime, 'EEEE, MMMM dd'),
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isLate
                  ? '${difference.inMinutes.abs()} min overdue'
                  : '${difference.inMinutes} min remaining',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    final statusColor = _getStatusColor(_currentOrder.status);
    final accent = accentGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Status',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.5) : neutralGray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(_currentOrder.status),
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentOrder.statusDisplay,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : darkGray,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: accent.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  _currentOrder.statusDisplay,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (_currentOrder.acceptedAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.05) 
                    : lightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: isDark ? Colors.white.withOpacity(0.6) : neutralGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Accepted: ${formatRwandaTime(_currentOrder.acceptedAt!, 'MMM dd, HH:mm')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white.withOpacity(0.6) : neutralGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerSection(bool isDark) {
    return _buildSection(
      icon: Icons.person_outline,
      title: 'Customer Information',
      iconColor: infoColor,
      bgColor: isDark ? infoColor.withOpacity(0.1) : infoLight,
      isDark: isDark,
      child: Column(
        children: [
          _buildInfoRow('Name', _currentOrder.customerName ?? 'N/A', isDark: isDark),
          const SizedBox(height: 8),
          _buildInfoRow('Phone', _currentOrder.customerPhone ?? 'N/A', isDark: isDark),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_currentOrder.deliveryInfo?.latitude != null &&
                  _currentOrder.deliveryInfo?.longitude != null)
                Expanded(
                  child: _buildActionButton(
                    onPressed: () => _openCustomerLocation(context),
                    icon: Icons.directions_outlined,
                    label: 'Navigate',
                    color: infoColor,
                    isDark: isDark,
                  ),
                ),
              if (_currentOrder.customerPhone != null &&
                  _currentOrder.deliveryInfo?.latitude != null &&
                  _currentOrder.deliveryInfo?.longitude != null)
                const SizedBox(width: 12),
              if (_currentOrder.customerPhone != null)
                Expanded(
                  child: _buildActionButton(
                    onPressed: () => _callCustomer(_currentOrder.customerPhone!),
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    color: successColor,
                    isDark: isDark,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVendorSection(bool isDark) {
    return _buildSection(
      icon: Icons.store_outlined,
      title: 'Vendor Information',
      iconColor: warningColor,
      bgColor: isDark ? warningColor.withOpacity(0.1) : warningLight,
      isDark: isDark,
      child: Column(
        children: [
          _buildInfoRow('Name', _currentOrder.vendorName, isDark: isDark),
          if (_currentOrder.vendorLatitude != null && _currentOrder.vendorLongitude != null) ...[
            const SizedBox(height: 16),
            _buildActionButton(
              onPressed: () => _openVendorLocation(context),
              icon: Icons.directions_outlined,
              label: 'Navigate to Vendor',
              color: warningColor,
              isDark: isDark,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSection(bool isDark) {
    final isPaid = _currentOrder.paymentStatus == 'paid';
    final paymentMethod = _currentOrder.paymentMethod;
    final accent = accentGreen;
    
    return _buildSection(
      icon: Icons.payment_outlined,
      title: 'Payment Information',
      iconColor: isPaid ? successColor : warningColor,
      bgColor: isDark 
          ? (isPaid ? successColor.withOpacity(0.1) : warningColor.withOpacity(0.1))
          : (isPaid ? successLight : warningLight),
      isDark: isDark,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle : Icons.info,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Status',
                        style: TextStyle(
                          color: isDark ? Colors.white.withOpacity(0.6) : neutralGray,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPaid ? 'Already Paid' : 'Pay on Delivery',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isPaid ? accent : warningColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Method',
            paymentMethod?.toUpperCase() ?? 'N/A',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection(bool isDark) {
    return _buildSection(
      icon: Icons.location_on_outlined,
      title: 'Delivery Address',
      iconColor: const Color(0xFF8B5CF6), // Purple
      bgColor: isDark 
          ? const Color(0xFF8B5CF6).withOpacity(0.1) 
          : const Color(0xFFFAF5FF),
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentOrder.deliveryInfo?.address != null)
            Text(
              _currentOrder.deliveryInfo!.address!,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : darkGray,
                height: 1.5,
              ),
            )
          else
            Text(
              'No address provided',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.5) : neutralGray,
                fontSize: 14,
              ),
            ),
          if (_currentOrder.specialInstructions != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.05) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Special Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isDark ? Colors.white.withOpacity(0.7) : neutralGray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentOrder.specialInstructions!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : darkGray,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection(bool isDark) {
    return _buildSection(
      icon: Icons.shopping_bag_outlined,
      title: 'Order Items (${_currentOrder.itemCount})',
      iconColor: primaryColor,
      bgColor: isDark ? primaryColor.withOpacity(0.1) : const Color(0xFFEEF2FF),
      isDark: isDark,
      child: Column(
        children: _currentOrder.items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == _currentOrder.items.length - 1;
          return Container(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
            decoration: BoxDecoration(
              border: isLast 
                  ? null 
                  : Border(
                      bottom: BorderSide(
                        color: isDark 
                            ? Colors.white.withOpacity(0.08) 
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.quantity}×',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : darkGray,
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
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : darkGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'RWF ${item.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: accentGreen,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPricingSection(bool isDark) {
    return _buildSection(
      icon: Icons.receipt_outlined,
      title: 'Pricing Summary',
      iconColor: successColor,
      bgColor: isDark ? successColor.withOpacity(0.1) : successLight,
      isDark: isDark,
      child: Column(
        children: [
          _buildPricingRow('Subtotal', _currentOrder.subtotal, isDark: isDark),
          const SizedBox(height: 8),
          _buildPricingRow('Delivery Fee', _currentOrder.deliveryFee, isDark: isDark),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark 
                  ? successColor.withOpacity(0.15) 
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _buildPricingRow(
              'Total',
              _currentOrder.total,
              isBold: true,
              isTotal: true,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : darkGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, {bool isDark = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.6) : neutralGray,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value ?? 'N/A',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDark ? Colors.white : darkGray,
          ),
        ),
      ],
    );
  }

  Widget _buildPricingRow(
    String label,
    double value, {
    bool isBold = false,
    bool isTotal = false,
    bool isDark = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            fontSize: isTotal ? 16 : 13,
            color: isDark 
                ? (isTotal ? Colors.white : Colors.white.withOpacity(0.7))
                : (isTotal ? darkGray : neutralGray),
          ),
        ),
        Text(
          'RWF ${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: isTotal ? accentGreen : accentGreen.withOpacity(0.85),
            fontSize: isTotal ? 18 : 13,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButtons(BuildContext context, RiderOrderProvider prov, bool isDark) {
    final statusValue = _currentOrder.status.value;
    
    Widget? button;
    
    if (statusValue == 'confirmed') {
      button = _buildStatusActionButton(
        context: context,
        prov: prov,
        icon: Icons.shopping_bag_outlined,
        label: 'Mark as Picked Up',
        targetStatus: 'picked_up',
        color: accentGreen,
        isDark: isDark,
      );
    } else if (statusValue == 'picked_up') {
      button = _buildStatusActionButton(
        context: context,
        prov: prov,
        icon: Icons.directions_outlined,
        label: 'Mark as In Transit',
        targetStatus: 'in_transit',
        color: accentGreen,
        isDark: isDark,
      );
    } else if (statusValue == 'in_transit') {
      button = _buildStatusActionButton(
        context: context,
        prov: prov,
        icon: Icons.check_circle_outline,
        label: 'Mark as Delivered',
        targetStatus: 'delivered',
        color: accentGreen,
        isDark: isDark,
      );
    }
    
    return button ?? const SizedBox.shrink();
  }

  Widget _buildStatusActionButton({
    required BuildContext context,
    required RiderOrderProvider prov,
    required IconData icon,
    required String label,
    required String targetStatus,
    required Color color,
    required bool isDark,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isUpdating
            ? null
            : () async {
                await _updateStatus(context, prov, targetStatus);
              },
        icon: _isUpdating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isUpdating ? neutralGray : color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: neutralGray,
          disabledForegroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    RiderOrderProvider prov,
    String status,
  ) async {
    setState(() => _isUpdating = true);
    try {
      final ok = await prov.updateOrderStatus(_currentOrder.id, status);
      if (ok && mounted) {
        await prov.fetchAssignedOrders();
        final updatedOrder = prov.orders.firstWhereOrNull((o) => o.id == _currentOrder.id);
        
        if (updatedOrder != null && mounted) {
          setState(() {
            _currentOrder = updatedOrder;
          });
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to ${_currentOrder.statusDisplay}'),
              backgroundColor: successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          
          if (status == 'delivered') {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) Navigator.pop(context, true);
          }
        }
      } else if (!ok && mounted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${prov.error ?? 'Unknown error'}'),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return neutralGray;
      case OrderStatus.confirmed:
        return infoColor;
      case OrderStatus.preparing:
        return warningColor;
      case OrderStatus.ready:
        return const Color(0xFF8B5CF6); // Purple
      case OrderStatus.pickedUp:
        return primaryColor;
      case OrderStatus.completed:
        return successColor;
      case OrderStatus.cancelled:
        return errorColor;
      default:
        return neutralGray;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule_outlined;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant_menu_outlined;
      case OrderStatus.ready:
        return Icons.shopping_bag_outlined;
      case OrderStatus.pickedUp:
        return Icons.local_shipping_outlined;
      case OrderStatus.completed:
        return Icons.done_all_outlined;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Future<void> _openCustomerLocation(BuildContext context) async {
    if (_currentOrder.deliveryInfo?.latitude == null ||
        _currentOrder.deliveryInfo?.longitude == null) {
      return;
    }

    final success = await ExternalMapsService.openCustomerLocationInMaps(
      latitude: _currentOrder.deliveryInfo!.latitude!,
      longitude: _currentOrder.deliveryInfo!.longitude!,
      customerName: _currentOrder.customerName ?? 'Customer',
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open Google Maps'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _openVendorLocation(BuildContext context) async {
    if (_currentOrder.vendorLatitude == null || _currentOrder.vendorLongitude == null) {
      return;
    }

    final success = await ExternalMapsService.openVendorLocationInMaps(
      latitude: _currentOrder.vendorLatitude!,
      longitude: _currentOrder.vendorLongitude!,
      vendorName: _currentOrder.vendorName,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open Google Maps'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _callCustomer(String phoneNumber) async {
    final success = await ExternalMapsService.callCustomer(phoneNumber);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not initiate call'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
