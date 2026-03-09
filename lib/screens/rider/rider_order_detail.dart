import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/rider_order_provider.dart';
import '../../services/api/api_service.dart';
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
  static const Color _accent = Color(0xFF22C55E);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _dark = Color(0xFF0B0B0B);

  late Order _currentOrder;
  bool _isUpdating = false;
  Timer? _updateTimer;

  bool get _isCompleted {
    final s = _currentOrder.status.value;
    return s == 'completed' || s == 'delivered';
  }

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshOrderDetails();
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
        final updated = prov.orders.firstWhereOrNull((o) => o.id == _currentOrder.id);
        if (updated != null) setState(() => _currentOrder = updated);
      }
    } catch (_) {}
  }

  // â”€â”€ Colors (matching customer order detail) â”€â”€
  Color _bg(bool d) => d ? const Color(0xFF0A0A0A) : const Color(0xFFF1F2F4);
  Color _txt(bool d) => d ? Colors.white : _dark;
  Color _sub(bool d) => d ? Colors.white60 : _muted;

  // Card decoration matching customer order detail _CardShell
  BoxDecoration _cardDeco(bool d) => BoxDecoration(
    color: d ? const Color(0xFF0F0F0F) : Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: d ? const Color(0xFF1F1F1F) : const Color(0xFFE3E5E8)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(d ? 0.25 : 0.08),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
    gradient: d
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F0F), Color(0xFF1A1A1A)],
          )
        : null,
  );

  String? _resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    final trimmed = imageUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) return trimmed;
    if (trimmed.startsWith('/')) return '${ApiService.baseUrl}$trimmed';
    return '${ApiService.baseUrl}/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.read<RiderOrderProvider>();
    final d = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _bg(d),
      appBar: AppBar(
        title: Text(
          'Order ${shortenOrderNumber(_currentOrder.orderNumber)}',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _txt(d)),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
                  // â”€â”€ Status + ETA row â”€â”€
                  _statusBar(d),
                  const SizedBox(height: 14),

                  // â”€â”€ Customer & Vendor â”€â”€
                  // Hide customer details for completed/delivered orders
                  if (!_isCompleted) ...[
                    _contactTile(
                      d,
                      icon: Icons.person_rounded,
                      name: _currentOrder.customerName ?? 'Customer',
                      phone: _currentOrder.customerPhone,
                      onCall: _currentOrder.customerPhone != null
                          ? () => _callCustomer(_currentOrder.customerPhone!)
                          : null,
                      onNavigate: (_currentOrder.deliveryInfo?.latitude != null &&
                              _currentOrder.deliveryInfo?.longitude != null)
                          ? () => _openCustomerLocation(context)
                          : null,
                      subtitle: _currentOrder.deliveryInfo?.address,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _contactTile(
                    d,
                    icon: Icons.storefront_rounded,
                    name: _currentOrder.vendorName,
                    phone: _currentOrder.vendorPhone,
                    logoUrl: _currentOrder.vendorLogo,
                    onCall: _currentOrder.vendorPhone != null
                        ? () => _callVendor(_currentOrder.vendorPhone!)
                        : null,
                    onNavigate: (_currentOrder.vendorLatitude != null &&
                            _currentOrder.vendorLongitude != null)
                        ? () => _openVendorLocation(context)
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // â”€â”€ Delivery address + notes (hidden for completed) â”€â”€
                  if (_currentOrder.deliveryInfo != null && !_isCompleted) ...[
                    _deliveryBlock(d),
                    const SizedBox(height: 14),
                  ],

                  // â”€â”€ Special instructions (hidden for completed) â”€â”€
                  if (!_isCompleted &&
                      _currentOrder.specialInstructions != null &&
                      _currentOrder.specialInstructions!.isNotEmpty) ...[
                    _instructionsBlock(d),
                    const SizedBox(height: 14),
                  ],

                  // â”€â”€ Payment row â”€â”€
                  _paymentRow(d),
                  const SizedBox(height: 14),

                  // â”€â”€ Items â”€â”€
                  _sectionLabel('Items (${_currentOrder.itemCount})', d),
                  const SizedBox(height: 8),
                  ..._currentOrder.items.map((item) => _itemTile(item, d)),
                  const SizedBox(height: 14),

                  // â”€â”€ Pricing â”€â”€
                  _pricingSummary(d),
                ],
              ),
            ),
          ),
          // â”€â”€ Bottom action â”€â”€
          _bottomAction(context, prov, d),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // STATUS BAR
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _statusBar(bool d) {
    final etaWidget = _etaChip(d);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accent.withOpacity(d ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(_currentOrder.status), color: _accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _currentOrder.statusDisplay,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _txt(d)),
            ),
          ),
          if (etaWidget != null) etaWidget,
        ],
      ),
    );
  }

  Widget? _etaChip(bool d) {
    if (_currentOrder.estimatedArrivalTime == null) return null;
    final now = nowInRwanda();
    final eta = toRwandaTime(_currentOrder.estimatedArrivalTime!);
    final diff = eta.difference(now);
    final isLate = diff.isNegative;
    final color = isLate ? const Color(0xFFEF4444) : _accent;
    final label = isLate
        ? '${diff.inMinutes.abs()}m late'
        : '${diff.inMinutes}m left';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLate ? Icons.warning_amber_rounded : Icons.schedule, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // CONTACT TILE (customer / vendor)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _contactTile(
    bool d, {
    required IconData icon,
    required String name,
    String? phone,
    String? logoUrl,
    String? subtitle,
    VoidCallback? onCall,
    VoidCallback? onNavigate,
  }) {
    final resolvedLogo = _resolveImageUrl(logoUrl);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(d),
      child: Row(
        children: [
          // avatar / icon
          if (resolvedLogo != null)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: d ? const Color(0xFF141414) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: d ? Colors.white12 : Colors.black12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.network(
                  resolvedLogo,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _sub(d),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => _iconBox(d, icon),
                ),
              ),
            )
          else
            _iconBox(d, icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _txt(d))),
                if (phone != null)
                  Text(phone, style: TextStyle(fontSize: 12, color: _sub(d))),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: _sub(d)),
                    ),
                  ),
              ],
            ),
          ),
          if (onNavigate != null)
            _circleBtn(Icons.navigation_rounded, _accent, onNavigate),
          if (onCall != null) ...[
            const SizedBox(width: 6),
            _circleBtn(Icons.phone_rounded, const Color(0xFF3B82F6), onCall),
          ],
        ],
      ),
    );
  }

  Widget _iconBox(bool d, IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: d ? const Color(0xFF141414) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: d ? Colors.white12 : Colors.black12),
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // DELIVERY BLOCK
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _deliveryBlock(bool d) {
    final info = _currentOrder.deliveryInfo!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(d),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 16, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              Text('Delivery Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _sub(d))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            info.address.isNotEmpty ? info.address : 'No address provided',
            style: TextStyle(fontSize: 13, color: _txt(d), height: 1.4),
          ),
          if (info.notes != null && info.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(d ? 0.1 : 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: const Color(0xFF8B5CF6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      info.notes!,
                      style: TextStyle(fontSize: 12, color: _txt(d), height: 1.4),
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // SPECIAL INSTRUCTIONS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _instructionsBlock(bool d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withOpacity(d ? 0.10 : 1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_rounded, size: 16, color: d ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Note',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: d ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _currentOrder.specialInstructions!,
                  style: TextStyle(fontSize: 13, color: _txt(d), height: 1.4),
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
    final isPaid = _currentOrder.paymentStatus == 'paid';
    final method = _currentOrder.paymentMethod.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _cardDeco(d),
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
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _txt(d)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isPaid ? _accent : const Color(0xFFF59E0B)).withOpacity(0.12),
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
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _sub(d)),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ITEM TILE
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _itemTile(OrderItem item, bool d) {
    final imageUrl = _resolveImageUrl(item.imageUrl);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: _cardDeco(d),
      child: Column(
        children: [
          Row(
            children: [
              // Product image
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: d ? const Color(0xFF141414) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: d ? Colors.white12 : Colors.black12),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          imageUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _sub(d),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.image_rounded, size: 22, color: _sub(d)),
                        ),
                      )
                    : Icon(Icons.image_rounded, size: 22, color: _sub(d)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _txt(d)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.quantity}Ã— RWF ${item.price.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: _sub(d)),
                    ),
                  ],
                ),
              ),
              Text(
                'RWF ${item.total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _accent),
              ),
            ],
          ),
          // Item notes / modifiers
          if (item.notes != null && item.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 62),
              child: Row(
                children: [
                  Icon(Icons.notes_rounded, size: 13, color: _sub(d)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.notes!,
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: _sub(d)),
                    ),
                  ),
                ],
              ),
            ),
          if (item.modifiers != null && item.modifiers!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 62),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.modifiers!.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${m.name}: ${m.value}',
                      style: TextStyle(fontSize: 11, color: _txt(d)),
                    ),
                  );
                }).toList(),
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
      decoration: _cardDeco(d),
      child: Column(
        children: [
          _priceRow('Subtotal', _currentOrder.subtotal, d),
          const SizedBox(height: 6),
          _priceRow('Delivery Fee', _currentOrder.deliveryFee, d),
          Divider(height: 16, color: d ? const Color(0xFF1F1F1F) : const Color(0xFFE3E5E8)),
          _priceRow('Total', _currentOrder.total, d, isTotal: true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double value, bool d, {bool isTotal = false}) {
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
  Widget _bottomAction(BuildContext context, RiderOrderProvider prov, bool d) {
    final statusValue = _currentOrder.status.value;
    final hasVendorCode = _currentOrder.vendorPickupCode != null && _currentOrder.vendorPickupCode!.isNotEmpty;
    final hasCustomerCode = _currentOrder.customerDeliveryCode != null && _currentOrder.customerDeliveryCode!.isNotEmpty;

    String? label;
    IconData? icon;
    String? targetStatus;
    bool needsVerify = false;
    String? verifyType;

    if (statusValue == 'confirmed' || statusValue == 'ready') {
      label = 'Mark as In Transit';
      icon = Icons.directions_rounded;
      targetStatus = 'in_transit';
      needsVerify = hasVendorCode;
      verifyType = 'vendor_pickup';
    } else if (statusValue == 'picked_up' || statusValue == 'in_transit') {
      label = 'Mark as Delivered';
      icon = Icons.check_circle_rounded;
      targetStatus = 'delivered';
      needsVerify = hasCustomerCode;
      verifyType = 'customer_delivery';
    }

    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: _bg(d),
        border: Border(top: BorderSide(color: d ? const Color(0xFF1F1F1F) : const Color(0xFFE3E5E8))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isUpdating
              ? null
              : () async {
                  if (needsVerify && verifyType != null) {
                    await _promptVerificationCode(context, prov, targetStatus!, verifyType!);
                  } else {
                    await _updateStatus(context, prov, targetStatus!);
                  }
                },
          icon: _isUpdating
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isUpdating ? _muted : _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            disabledBackgroundColor: _muted,
            disabledForegroundColor: Colors.white,
          ),
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
              backgroundColor: _accent,
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
        final rawError = prov.error ?? 'Something went wrong';
        final cleanError = rawError.replaceAll(RegExp(r'^Exception:\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(cleanError, style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final cleanError = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(cleanError, style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: Colors.red.shade700,
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

  Future<void> _promptVerificationCode(
    BuildContext context,
    RiderOrderProvider prov,
    String targetStatus,
    String verificationType,
  ) async {
    final controller = TextEditingController();
    final isVendor = verificationType == 'vendor_pickup';
    final title = isVendor ? 'Enter Vendor Pickup Code' : 'Enter Customer Delivery Code';
    final hint = isVendor
        ? 'Ask the vendor for their 4-digit code'
        : 'Ask the customer for their 4-digit code';
    final accentColor = isVendor ? Colors.orange : Colors.blue;

    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isVendor ? Icons.storefront_rounded : Icons.account_circle_rounded, color: accentColor, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hint, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
                  hintStyle: TextStyle(fontSize: 32, color: Colors.grey.withOpacity(0.3)),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);
    try {
      Map<String, dynamic>? resp;
      if (isVendor) {
        resp = await prov.verifyVendorPickupCode(_currentOrder.id, code);
      } else {
        resp = await prov.verifyCustomerDeliveryCode(_currentOrder.id, code);
      }

      if (!mounted) return;

      if (resp != null && resp['success'] == true) {
        await prov.fetchAssignedOrders();
        final updatedOrder = prov.orders.firstWhereOrNull((o) => o.id == _currentOrder.id);
        if (updatedOrder != null && mounted) {
          setState(() => _currentOrder = updatedOrder);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVendor ? 'Pickup verified - order is now in transit!' : 'Delivery verified successfully!'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );

        if (!isVendor) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        // Show friendly error message from provider
        final serverError = resp?['error']?.toString() ?? prov.error ?? 'Verification failed';
        final cleanError = serverError.replaceAll(RegExp(r'^Exception:\s*'), '');
        
        // Determine if it's an attempts-remaining situation
        final hasAttempts = cleanError.toLowerCase().contains('attempt');
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: Icon(
                hasAttempts ? Icons.pin_rounded : Icons.warning_amber_rounded,
                color: Colors.red.shade400,
                size: 40,
              ),
              title: Text(
                hasAttempts ? 'Wrong Code' : 'Verification Failed',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanError = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(cleanError, style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment:
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant_menu;
      case OrderStatus.ready:
        return Icons.shopping_bag_rounded;
      case OrderStatus.pickedUp:
        return Icons.two_wheeler_rounded;
      case OrderStatus.completed:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
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
          backgroundColor: Colors.red.shade700,
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
          backgroundColor: Colors.red.shade700,
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
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _callVendor(String phoneNumber) async {
    final success = await ExternalMapsService.callCustomer(phoneNumber);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not initiate call'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
