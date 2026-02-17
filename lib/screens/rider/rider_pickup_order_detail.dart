// lib/screens/rider/rider_pickup_order_detail.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/pickup_order.dart';
import '../../providers/pickup_order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/external_maps_service.dart';
import '../../utils/helpers.dart';

class RiderPickupOrderDetailScreen extends StatefulWidget {
  final PickupOrder order;
  const RiderPickupOrderDetailScreen({super.key, required this.order});

  @override
  State<RiderPickupOrderDetailScreen> createState() => _RiderPickupOrderDetailScreenState();
}

class _RiderPickupOrderDetailScreenState extends State<RiderPickupOrderDetailScreen> {
  // Neutral palette + green accent
  static const Color pureBlack = Color(0xFF0B0B0B);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color softBlack = Colors.black;
  static const Color borderGray = Color(0xFFE5E7EB);
  static const Color mutedGray = Color(0xFF6B7280);
  static const Color accentGreen = Color(0xFF4CAF50);

  late PickupOrder _currentOrder;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? pureWhite : pureBlack;
    final subtextColor = isDark ? Colors.white70 : mutedGray;
    final backgroundColor = isDark ? pureBlack : const Color(0xFFDADDE2);
    final cardColor = isDark ? softBlack : const Color(0xFFDADDE2);
    final borderColor = isDark ? const Color(0xFF1F1F1F) : borderGray;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (mounted) Navigator.pop(context);
          },
        ),
        title: Text(
          'Pickup Order #${_currentOrder.orderNumber}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(textColor, subtextColor, cardColor, borderColor),
            const SizedBox(height: 16),
            _buildCustomerCard(textColor, subtextColor, cardColor, borderColor, context),
            const SizedBox(height: 16),
            _buildItemsCard(textColor, subtextColor, cardColor, borderColor),
            const SizedBox(height: 16),
            _buildPricingCard(textColor, subtextColor, cardColor, borderColor),
            const SizedBox(height: 24),
            _buildActionButtons(context, textColor, cardColor),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : const Color(0xFFDADDE2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                'Order Status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(_currentOrder.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getStatusColor(_currentOrder.status).withOpacity(0.3),
              ),
            ),
            child: Text(
              _currentOrder.statusDisplay,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _getStatusColor(_currentOrder.status),
              ),
            ),
          ),
          if (_currentOrder.scheduledPickupTime != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: subtextColor),
                const SizedBox(width: 6),
                Text(
                  'Scheduled: ${formatRwandaTime(_currentOrder.scheduledPickupTime, 'MMM dd, yyyy HH:mm')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Color textColor, Color subtextColor, Color cardColor, Color borderColor, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : const Color(0xFFDADDE2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                'Customer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentOrder.customerName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentOrder.customerPhone,
            style: TextStyle(
              fontSize: 12,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ExternalMapsService.callCustomer(_currentOrder.customerPhone);
                  },
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ExternalMapsService.sendWhatsAppMessage(
                      _currentOrder.customerPhone,
                      'Hello, I am your Ntwaza delivery rider for order #${_currentOrder.orderNumber}.',
                    );
                  },
                  icon: const Icon(Icons.message, size: 16),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : const Color(0xFFDADDE2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                'Items (${_currentOrder.items.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._currentOrder.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textColor,
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
                            item.description,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.category} • ${item.estimatedWeight.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 10,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPricingCard(Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : const Color(0xFFDADDE2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildPriceRow('Amount', _currentOrder.amount, textColor, subtextColor),
          const SizedBox(height: 8),
          _buildPriceRow('Delivery Fee', _currentOrder.deliveryFee, textColor, subtextColor),
          const SizedBox(height: 12),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                'RWF ${_currentOrder.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double value, Color textColor, Color subtextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: subtextColor,
          ),
        ),
        Text(
          'RWF ${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Color textColor, Color cardColor) {
    final provider = context.read<PickupOrderProvider>();
    final pickupCode = _extractPickupCode(_currentOrder.notes);
    
    // Determine which button to show based on status
    if (_currentOrder.status == PickupOrderStatus.assignedToRider) {
      return _buildGreenButton(
        context,
        'Confirm Pickup',
        Icons.check_circle_outline,
        () => _confirmPickupCode(context, provider, pickupCode),
      );
    } else if (_currentOrder.status == PickupOrderStatus.pickedUp) {
      return _buildGreenButton(
        context,
        'Mark as In Transit',
        Icons.local_shipping_outlined,
        () => _updateStatus(context, provider, PickupOrderStatus.inTransit),
      );
    } else if (_currentOrder.status == PickupOrderStatus.inTransit) {
      return _buildGreenButton(
        context,
        'Mark as Delivered',
        Icons.check_circle,
        () => _updateStatus(context, provider, PickupOrderStatus.delivered),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildGreenButton(BuildContext context, String label, IconData icon, VoidCallback onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isUpdating ? null : onPressed,
        icon: _isUpdating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: pureWhite,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isUpdating ? mutedGray : accentGreen,
          foregroundColor: pureWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: mutedGray,
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    PickupOrderProvider provider,
    PickupOrderStatus newStatus, {
    String? pickupCode,
  }) async {
    setState(() => _isUpdating = true);
    try {
      final success = await provider.updateOrderStatus(
        _currentOrder.id,
        newStatus,
        pickupCode: pickupCode,
      );
      if (success && mounted) {
        await provider.fetchRiderPickupOrders(context.read<AuthProvider>().user!.id!);
        setState(() {
          _currentOrder = _currentOrder.copyWith(status: newStatus);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to ${newStatus.displayName}'),
              backgroundColor: accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          if (newStatus == PickupOrderStatus.delivered) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) Navigator.pop(context);
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update status'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  String? _extractPickupCode(String? notes) {
    if (notes == null || notes.trim().isEmpty) return null;
    final match = RegExp(r'Pickup code\s*:\s*(\d{4,6})', caseSensitive: false).firstMatch(notes);
    return match?.group(1);
  }

  Future<void> _confirmPickupCode(
    BuildContext context,
    PickupOrderProvider provider,
    String? pickupCode,
  ) async {
    if (pickupCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pickup code is missing. Contact support.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Pickup Code'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '4-digit code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim() == pickupCode);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateStatus(context, provider, PickupOrderStatus.pickedUp, pickupCode: pickupCode);
    } else if (result == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid pickup code'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Color _getStatusColor(PickupOrderStatus status) {
    switch (status) {
      case PickupOrderStatus.pending:
        return const Color(0xFF6B7280);
      case PickupOrderStatus.confirmed:
        return const Color(0xFF2563EB);
      case PickupOrderStatus.assignedToRider:
        return const Color(0xFFF59E0B);
      case PickupOrderStatus.pickedUp:
      case PickupOrderStatus.inTransit:
        return const Color(0xFF8B5CF6);
      case PickupOrderStatus.delivered:
        return accentGreen;
      case PickupOrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }
}
