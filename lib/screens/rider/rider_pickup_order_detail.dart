// lib/screens/rider/rider_pickup_order_detail.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pickup_order.dart';
import '../../providers/pickup_order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/external_maps_service.dart';
import '../../utils/helpers.dart';

class RiderPickupOrderDetailScreen extends StatefulWidget {
  final PickupOrder order;
  const RiderPickupOrderDetailScreen({super.key, required this.order});

  @override
  State<RiderPickupOrderDetailScreen> createState() =>
      _RiderPickupOrderDetailScreenState();
}

class _RiderPickupOrderDetailScreenState
    extends State<RiderPickupOrderDetailScreen> {
  static const Color _accent = Color(0xFF22C55E);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _dark = Color(0xFF0B0B0B);

  late PickupOrder _currentOrder;
  bool _isUpdating = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshOrder();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    final prov = context.read<PickupOrderProvider>();
    final auth = context.read<AuthProvider>();
    try {
      await prov.fetchRiderPickupOrders(auth.user!.id!);
      if (mounted) {
        final updated = prov.riderAssignedOrders
            .where((o) => o.id == _currentOrder.id)
            .toList();
        if (updated.isNotEmpty) setState(() => _currentOrder = updated.first);
      }
    } catch (_) {}
  }

  // â”€â”€ Colors â”€â”€
  Color _bg(bool d) => d ? const Color(0xFF1A1A1A) : Colors.white;
  Color _card(bool d) =>
      d ? const Color(0xFF252525) : const Color(0xFFF9FAFB);
  Color _border(bool d) =>
      d ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);
  Color _txt(bool d) => d ? Colors.white : _dark;
  Color _sub(bool d) => d ? Colors.white60 : _muted;

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: _bg(d),
      appBar: AppBar(
        title: Text(
          'Pickup ${shortenOrderNumber(_currentOrder.orderNumber)}',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: _txt(d)),
        ),
        elevation: 0,
        backgroundColor: _bg(d),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _txt(d)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusBar(d),
                  const SizedBox(height: 14),
                  _contactTile(d,
                      icon: Icons.person_rounded,
                      name: _currentOrder.customerName,
                      phone: _currentOrder.customerPhone,
                      onCall: () => _call(_currentOrder.customerPhone),
                      onWhatsApp: () => _whatsApp(
                          _currentOrder.customerPhone,
                          'Hello, I am your NTWAZA Delivery rider for pickup order #${_currentOrder.orderNumber}.')),
                  const SizedBox(height: 10),
                  _locationCard(
                    d,
                    label: 'Pickup Location',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFFF59E0B),
                    location: _currentOrder.pickupLocation,
                  ),
                  const SizedBox(height: 10),
                  _locationCard(
                    d,
                    label: 'Dropoff Location',
                    icon: Icons.location_on_rounded,
                    color: const Color(0xFF8B5CF6),
                    location: _currentOrder.dropoffLocation,
                  ),
                  if (_currentOrder.notes != null &&
                      _currentOrder.notes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _notesBlock(d),
                  ],
                  const SizedBox(height: 14),
                  _paymentRow(d),
                  const SizedBox(height: 14),
                  _sectionLabel(
                      'Items (${_currentOrder.items.length})', d),
                  const SizedBox(height: 8),
                  ..._currentOrder.items.map((item) => _itemTile(item, d)),
                  const SizedBox(height: 14),
                  _pricingSummary(d),
                ],
              ),
            ),
          ),
          _bottomAction(context, d),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // STATUS BAR
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _statusBar(bool d) {
    final scheduledChip = _scheduledChip(d);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accent.withOpacity(d ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(_currentOrder.status), color: _accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _currentOrder.statusDisplay,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _txt(d)),
            ),
          ),
          if (scheduledChip != null) scheduledChip,
        ],
      ),
    );
  }

  Widget? _scheduledChip(bool d) {
    final now = nowInRwanda();
    final scheduled = toRwandaTime(_currentOrder.scheduledPickupTime);
    final diff = scheduled.difference(now);
    if (diff.inHours.abs() > 24) return null;
    final isLate = diff.isNegative;
    final color = isLate ? const Color(0xFFEF4444) : _accent;
    final label = isLate
        ? '${diff.inMinutes.abs()}m overdue'
        : '${diff.inMinutes}m to pickup';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              isLate ? Icons.warning_amber_rounded : Icons.schedule,
              size: 14,
              color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // CONTACT TILE
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _contactTile(
    bool d, {
    required IconData icon,
    required String name,
    String? phone,
    VoidCallback? onCall,
    VoidCallback? onWhatsApp,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card(d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border(d)),
      ),
      child: Row(
        children: [
          _iconBox(d, icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _txt(d))),
                if (phone != null)
                  Text(phone,
                      style: TextStyle(fontSize: 12, color: _sub(d))),
              ],
            ),
          ),
          if (onWhatsApp != null) ...[
            _circleBtn(Icons.message_rounded, const Color(0xFF25D366), onWhatsApp),
            const SizedBox(width: 6),
          ],
          if (onCall != null)
            _circleBtn(Icons.phone_rounded, const Color(0xFF3B82F6), onCall),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // LOCATION CARD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _locationCard(
    bool d, {
    required String label,
    required IconData icon,
    required Color color,
    required Location location,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card(d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border(d)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _sub(d))),
              ),
              if (location.latitude != 0.0 && location.longitude != 0.0)
                _circleBtn(Icons.navigation_rounded, color, () {
                  ExternalMapsService.openLocationInMaps(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    label: label,
                  );
                }),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            location.address.isNotEmpty
                ? location.address
                : 'No address provided',
            style: TextStyle(fontSize: 13, color: _txt(d), height: 1.4),
          ),
          if (location.phoneNumber != null &&
              location.phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 13, color: _sub(d)),
                const SizedBox(width: 4),
                Text(location.phoneNumber!,
                    style: TextStyle(fontSize: 12, color: _sub(d))),
              ],
            ),
          ],
          if (location.notes != null && location.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(d ? 0.1 : 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(location.notes!,
                        style: TextStyle(
                            fontSize: 12,
                            color: _txt(d),
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // NOTES BLOCK
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _notesBlock(bool d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withOpacity(d ? 0.10 : 1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_rounded,
              size: 16,
              color: d
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: d
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _currentOrder.notes!,
                  style:
                      TextStyle(fontSize: 13, color: _txt(d), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // PAYMENT ROW
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _paymentRow(bool d) {
    final isPaid = _currentOrder.isPaid;
    final method = _currentOrder.paymentMethod.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _card(d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border(d)),
      ),
      child: Row(
        children: [
          Icon(
            isPaid ? Icons.check_circle_rounded : Icons.payments_rounded,
            size: 18,
            color: isPaid ? _accent : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPaid ? 'Paid via $method' : 'Cash on Delivery',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _txt(d)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isPaid ? _accent : const Color(0xFFF59E0B))
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isPaid ? 'PAID' : 'UNPAID',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isPaid ? _accent : const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // SECTION LABEL
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _sectionLabel(String text, bool d) {
    return Text(text,
        style:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _sub(d)));
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ITEM TILE
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _itemTile(PickupItem item, bool d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _card(d),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border(d)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: d
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Ã—${item.quantity}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _txt(d)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _txt(d))),
                const SizedBox(height: 2),
                Text(
                  '${item.category} Â· ${item.estimatedWeight.toStringAsFixed(1)} kg',
                  style: TextStyle(fontSize: 12, color: _sub(d)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // PRICING SUMMARY
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _pricingSummary(bool d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card(d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border(d)),
      ),
      child: Column(
        children: [
          _priceRow('Amount', _currentOrder.amount, d),
          const SizedBox(height: 6),
          _priceRow('Delivery Fee', _currentOrder.deliveryFee, d),
          Divider(height: 16, color: _border(d)),
          _priceRow('Total', _currentOrder.totalAmount, d, isTotal: true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double value, bool d,
      {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            fontSize: isTotal ? 15 : 13,
            color: isTotal ? _txt(d) : _sub(d),
          ),
        ),
        Text(
          'RWF ${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            fontSize: isTotal ? 16 : 13,
            color: _accent,
          ),
        ),
      ],
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // BOTTOM ACTION BUTTON
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _bottomAction(BuildContext context, bool d) {
    final prov = context.read<PickupOrderProvider>();
    final hasVendorCode = _currentOrder.vendorPickupCode != null &&
        _currentOrder.vendorPickupCode!.isNotEmpty;
    final hasCustomerCode = _currentOrder.customerDropoffCode != null &&
        _currentOrder.customerDropoffCode!.isNotEmpty;

    String? label;
    IconData? icon;
    PickupOrderStatus? targetStatus;
    bool needsVerify = false;
    String? verifyType;

    switch (_currentOrder.status) {
      case PickupOrderStatus.assignedToRider:
        label = 'Confirm Pickup';
        icon = Icons.inventory_rounded;
        targetStatus = PickupOrderStatus.pickedUp;
        needsVerify = hasVendorCode;
        verifyType = 'vendor_pickup';
        break;
      case PickupOrderStatus.pickedUp:
        label = 'Mark as In Transit';
        icon = Icons.two_wheeler_rounded;
        targetStatus = PickupOrderStatus.inTransit;
        break;
      case PickupOrderStatus.inTransit:
        label = 'Mark as Delivered';
        icon = Icons.check_circle_rounded;
        targetStatus = PickupOrderStatus.delivered;
        needsVerify = hasCustomerCode;
        verifyType = 'customer_dropoff';
        break;
      default:
        break;
    }

    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: _bg(d),
        border: Border(top: BorderSide(color: _border(d))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isUpdating
              ? null
              : () async {
                  if (needsVerify && verifyType != null) {
                    await _promptVerificationCode(
                        context, prov, targetStatus!, verifyType!);
                  } else {
                    await _updateStatus(context, prov, targetStatus!);
                  }
                },
          icon: _isUpdating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 20),
          label: Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isUpdating ? _muted : _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            disabledBackgroundColor: _muted,
            disabledForegroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // STATUS UPDATE
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Future<void> _updateStatus(
    BuildContext context,
    PickupOrderProvider prov,
    PickupOrderStatus newStatus,
  ) async {
    setState(() => _isUpdating = true);
    try {
      final ok = await prov.updateOrderStatus(_currentOrder.id, newStatus);
      if (ok && mounted) {
        await prov
            .fetchRiderPickupOrders(context.read<AuthProvider>().user!.id!);
        final updated = prov.riderAssignedOrders
            .where((o) => o.id == _currentOrder.id)
            .toList();
        if (updated.isNotEmpty && mounted) {
          setState(() => _currentOrder = updated.first);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.displayName}'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );

        if (newStatus == PickupOrderStatus.delivered) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context, true);
        }
      } else if (!ok && mounted) {
        final rawError = prov.error ?? 'Something went wrong';
        final cleanError =
            rawError.replaceAll(RegExp(r'^Exception:\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(cleanError,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final cleanError =
            e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(cleanError,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // VERIFICATION CODE DIALOG
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Future<void> _promptVerificationCode(
    BuildContext context,
    PickupOrderProvider prov,
    PickupOrderStatus targetStatus,
    String verificationType,
  ) async {
    final controller = TextEditingController();
    final isVendor = verificationType == 'vendor_pickup';
    final title =
        isVendor ? 'Enter Vendor Pickup Code' : 'Enter Customer Dropoff Code';
    final hint = isVendor
        ? 'Ask the sender for their 4-digit code'
        : 'Ask the customer for their 4-digit code';
    final accentColor = isVendor ? Colors.orange : Colors.blue;

    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                  isVendor
                      ? Icons.inventory_rounded
                      : Icons.account_circle_rounded,
                  color: accentColor,
                  size: 22),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hint,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                autofocus: true,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: accentColor,
                ),
                decoration: InputDecoration(
                  hintText: '0000',
                  hintStyle: TextStyle(
                      fontSize: 32,
                      color: Colors.grey.withOpacity(0.3)),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: accentColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: accentColor, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (code == null || code.isEmpty) return;

    if (code.length != 4 || !RegExp(r'^\d{4}$').hasMatch(code)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Code must be exactly 4 digits'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);
    try {
      bool success;
      if (isVendor) {
        success = await prov.verifyVendorPickupCode(_currentOrder.id, code);
      } else {
        success =
            await prov.verifyCustomerDropoffCode(_currentOrder.id, code);
      }

      if (!mounted) return;

      if (success) {
        await prov
            .fetchRiderPickupOrders(context.read<AuthProvider>().user!.id!);
        final updated = prov.riderAssignedOrders
            .where((o) => o.id == _currentOrder.id)
            .toList();
        if (updated.isNotEmpty && mounted) {
          setState(() => _currentOrder = updated.first);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVendor
                ? 'Pickup verified â€” order is now in transit!'
                : 'Delivery verified successfully!'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );

        if (!isVendor) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        final serverError = prov.error ?? 'Verification failed';
        final cleanError =
            serverError.replaceAll(RegExp(r'^Exception:\s*'), '');
        final hasAttempts =
            cleanError.toLowerCase().contains('attempt');

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              icon: Icon(
                hasAttempts
                    ? Icons.pin_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.red.shade400,
                size: 40,
              ),
              title: Text(
                hasAttempts ? 'Wrong Code' : 'Verification Failed',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 18),
              ),
              content: Text(
                cleanError,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Try Again',
                        style:
                            TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanError =
            e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(cleanError,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // HELPERS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _iconBox(bool d, IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: d
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: _sub(d)),
    );
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Future<void> _call(String phone) async {
    await ExternalMapsService.callCustomer(phone);
  }

  Future<void> _whatsApp(String phone, String message) async {
    await ExternalMapsService.sendWhatsAppMessage(phone, message);
  }

  IconData _statusIcon(PickupOrderStatus status) {
    switch (status) {
      case PickupOrderStatus.awaitingPayment:
        return Icons.payment;
      case PickupOrderStatus.pending:
        return Icons.schedule;
      case PickupOrderStatus.confirmed:
        return Icons.check_circle_outline;
      case PickupOrderStatus.assignedToRider:
        return Icons.person_pin_rounded;
      case PickupOrderStatus.pickedUp:
        return Icons.inventory_rounded;
      case PickupOrderStatus.inTransit:
        return Icons.two_wheeler_rounded;
      case PickupOrderStatus.delivered:
        return Icons.done_all;
      case PickupOrderStatus.cancelled:
        return Icons.cancel;
    }
  }
}
