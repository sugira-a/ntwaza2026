// lib/screens/admin/admin_order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_order_provider.dart';
import '../../services/admin_dashboard_service.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final Order order;

  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen>
    with SingleTickerProviderStateMixin {
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color gold = Color(0xFFFFB800);
  static const Color red = Color(0xFFEF4444);
  static const Color blue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF06B6D4);

  late TabController _tabController;
  late Order _order;
  bool _assigningRider = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _order = widget.order;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Stale detection ─────────────────────────────────────────────
  bool get _isStale {
    if (_order.status == OrderStatus.completed || _order.status == OrderStatus.cancelled) return false;
    final now = nowInRwanda();
    final created = toRwandaTime(_order.createdAt);
    final minutes = now.difference(created).inMinutes;
    if (_order.status == OrderStatus.pending) return minutes > 5;
    if (_order.status == OrderStatus.confirmed) return minutes > 15;
    if (_order.status == OrderStatus.preparing) return minutes > 30;
    if (_order.status == OrderStatus.ready) return minutes > 10;
    if (_order.status == OrderStatus.pickedUp) return minutes > 45;
    return false;
  }

  String get _staleMessage {
    final now = nowInRwanda();
    final created = toRwandaTime(_order.createdAt);
    final minutes = now.difference(created).inMinutes;
    if (_order.status == OrderStatus.pending) return 'Pending for $minutes min — No vendor response!';
    if (_order.status == OrderStatus.confirmed) return 'Confirmed $minutes min ago — Not being prepared yet';
    if (_order.status == OrderStatus.preparing) return 'Preparing for $minutes min — Taking too long';
    if (_order.status == OrderStatus.ready) return 'Ready for $minutes min — No rider picked up';
    if (_order.status == OrderStatus.pickedUp) return 'In transit for $minutes min — Delivery delayed';
    return 'Order delayed';
  }

  // ─── Time tracking ───────────────────────────────────────────────
  Map<String, dynamic> get _timeBreakdown {
    final created = toRwandaTime(_order.createdAt);
    final now = nowInRwanda();
    final accepted = _order.acceptedAt != null ? toRwandaTime(_order.acceptedAt!) : null;
    final ready = _order.readyAt != null ? toRwandaTime(_order.readyAt!) : null;
    final completed = _order.completedAt != null ? toRwandaTime(_order.completedAt!) : null;

    return {
      'waitForAccept': accepted != null ? accepted.difference(created).inMinutes : null,
      'prepTime': ready != null && accepted != null ? ready.difference(accepted).inMinutes : null,
      'deliveryTime': completed != null && ready != null ? completed.difference(ready).inMinutes : null,
      'totalTime': completed != null ? completed.difference(created).inMinutes : now.difference(created).inMinutes,
      'isComplete': completed != null,
      'elapsedMinutes': now.difference(created).inMinutes,
    };
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment: return const Color(0xFFEF6C00);
      case OrderStatus.completed: return accentGreen;
      case OrderStatus.cancelled: return red;
      case OrderStatus.pending: return const Color(0xFFF59E0B);
      case OrderStatus.confirmed: return blue;
      case OrderStatus.preparing: return const Color(0xFF6366F1);
      case OrderStatus.ready: return cyan;
      case OrderStatus.pickedUp: return purple;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.awaitingPayment: return Icons.payment_rounded;
      case OrderStatus.pending: return Icons.hourglass_empty_rounded;
      case OrderStatus.confirmed: return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing: return Icons.restaurant_rounded;
      case OrderStatus.ready: return Icons.inventory_2_rounded;
      case OrderStatus.pickedUp: return Icons.two_wheeler_rounded;
      case OrderStatus.completed: return Icons.check_circle_rounded;
      case OrderStatus.cancelled: return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0B) : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : const Color(0xFF0B0B0B);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final statusColor = _getStatusColor(_order.status);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ─── Header with status gradient ───────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, statusColor.withOpacity(0.3), Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.only(top: statusBarHeight),
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'Order #${_order.orderNumber}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getStatusIcon(_order.status), size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(_order.status.displayName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Time + stale warning
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 13, color: Colors.white54),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM d, yyyy  HH:mm').format(toRwandaTime(_order.createdAt)),
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      const Spacer(),
                      Text(
                        '${_timeBreakdown['elapsedMinutes']} min ago',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: accentGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentGreen.withOpacity(0.3)),
                    ),
                    labelColor: accentGreen,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    dividerHeight: 0,
                    tabs: const [
                      Tab(text: 'Details'),
                      Tab(text: 'Timeline'),
                      Tab(text: 'Actions'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ─── Tab content ───────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(isDark, textColor, subtextColor, cardColor, borderColor),
                _buildTimelineTab(isDark, textColor, subtextColor, cardColor, borderColor),
                _buildActionsTab(isDark, textColor, subtextColor, cardColor, borderColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 1 — Details
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDetailsTab(bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final needsRefund = _order.status == OrderStatus.cancelled && 
                       (_order.paymentStatus == 'paid' || _order.paymentStatus == 'completed');
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ─── Refund Alert ────────────────────────────────────────
        if (needsRefund) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: red.withOpacity(0.5), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.currency_exchange_rounded, color: red, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ REFUND REQUIRED',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: red,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This cancelled order was paid. Process refund of ${_formatPrice(_order.total)} RWF to customer.',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                      if (_order.cancellationReason != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Reason: ${_order.cancellationReason}',
                          style: TextStyle(
                            fontSize: 11,
                            color: subtextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        // ─── People cards ────────────────────────────────────────
        _personCard(
          icon: Icons.store_rounded,
          role: 'VENDOR',
          name: _order.vendorName.isEmpty ? 'Unknown Vendor' : _order.vendorName,
          phone: _order.vendorPhone ?? 'No phone on file',
          color: const Color(0xFF6366F1),
          isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor, cardColor: cardColor,
        ),
        const SizedBox(height: 10),
        _personCard(
          icon: Icons.person_rounded,
          role: 'CUSTOMER',
          name: _order.customerName,
          phone: _order.customerPhone ?? 'No phone on file',
          color: blue,
          isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor, cardColor: cardColor,
        ),
        const SizedBox(height: 10),
        _riderCard(isDark, textColor, subtextColor, cardColor, borderColor),
        const SizedBox(height: 18),

        // ─── Delivery address ────────────────────────────────────
        _sectionHeader('Delivery Address', Icons.location_on_rounded, textColor),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pin_drop_rounded, size: 18, color: red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _order.deliveryInfo?.address ?? 'No address provided',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor, height: 1.4),
                    ),
                    if (_order.deliveryDistanceKm > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_order.deliveryDistanceKm.toStringAsFixed(1)} km away',
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ─── Special instructions ────────────────────────────────
        if (_order.specialInstructions != null && _order.specialInstructions!.isNotEmpty) ...[
          _sectionHeader('Special Instructions', Icons.note_alt_rounded, textColor),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: gold.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withOpacity(0.2), width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _order.specialInstructions!,
                    style: TextStyle(fontSize: 13, color: textColor, fontStyle: FontStyle.italic, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // ─── Items ───────────────────────────────────────────────
        _sectionHeader('Items (${_order.items.length})', Icons.shopping_bag_rounded, textColor),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: _order.items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text('No items recorded', style: TextStyle(fontSize: 13, color: subtextColor)),
                  ),
                )
              : Column(
                  children: _order.items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: i < _order.items.length - 1
                            ? Border(bottom: BorderSide(color: borderColor, width: 0.5))
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Product image or quantity badge
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: accentGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item.imageUrl!,
                                      width: 48, height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          '${item.quantity}x',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4CAF50)),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      '${item.quantity}x',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4CAF50)),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '${item.quantity} × ${item.price.toStringAsFixed(0)} RWF',
                                      style: TextStyle(fontSize: 12, color: subtextColor),
                                    ),
                                  ],
                                ),
                                if (item.notes != null && item.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(item.notes!, style: TextStyle(fontSize: 11, color: subtextColor, fontStyle: FontStyle.italic)),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${item.total.toStringAsFixed(0)} RWF',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accentGreen),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 18),

        // ─── Payment ─────────────────────────────────────────────
        _sectionHeader('Payment Summary', Icons.payments_rounded, textColor),
        const SizedBox(height: 8),
        Builder(builder: (context) {
          // Smart fallback: compute subtotal from items if backend sent 0
          double subtotal = _order.subtotal;
          if (subtotal == 0 && _order.items.isNotEmpty) {
            subtotal = _order.items.fold(0.0, (sum, item) => sum + item.total);
          }
          double deliveryFee = _order.deliveryFee;
          if (deliveryFee == 0 && _order.total > 0 && subtotal > 0) {
            deliveryFee = _order.total - subtotal;
            if (deliveryFee < 0) deliveryFee = 0;
          }
          final paymentLabel = _order.paymentMethod[0].toUpperCase() + _order.paymentMethod.substring(1).toLowerCase();
          final statusRaw = _order.paymentStatus ?? 'pending';
          final statusLabel = statusRaw[0].toUpperCase() + statusRaw.substring(1).toLowerCase();

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Column(
              children: [
                _payRow('Subtotal', '${subtotal.toStringAsFixed(0)} RWF', textColor, subtextColor),
                const SizedBox(height: 8),
                _payRow('Delivery Fee', '${deliveryFee.toStringAsFixed(0)} RWF', textColor, subtextColor),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: borderColor, height: 1),
                ),
                _payRow('Total', '${_order.total.toStringAsFixed(0)} RWF', textColor, subtextColor, bold: true, valueColor: accentGreen),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _payChip(Icons.credit_card_rounded, paymentLabel, blue, isDark),
                    const SizedBox(width: 8),
                    _payChip(
                      _order.paymentStatus == 'paid' ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      statusLabel,
                      _order.paymentStatus == 'paid' ? accentGreen : gold,
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 18),

        // ─── Verification codes ──────────────────────────────────
        if (_order.vendorPickupCode != null || _order.customerDeliveryCode != null) ...[
          _sectionHeader('Verification Codes', Icons.verified_rounded, textColor),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_order.vendorPickupCode != null)
                Expanded(child: _codeCard('Pickup Code', _order.vendorPickupCode!, _order.vendorPickupCodeVerifiedAt != null, isDark, cardColor, textColor, subtextColor, borderColor)),
              if (_order.vendorPickupCode != null && _order.customerDeliveryCode != null) const SizedBox(width: 10),
              if (_order.customerDeliveryCode != null)
                Expanded(child: _codeCard('Delivery Code', _order.customerDeliveryCode!, _order.customerDeliveryCodeVerifiedAt != null, isDark, cardColor, textColor, subtextColor, borderColor)),
            ],
          ),
          const SizedBox(height: 18),
        ],

        // ─── Ratings ─────────────────────────────────────────────
        if (_order.vendorRating != null || _order.riderRating != null) ...[
          _sectionHeader('Customer Ratings', Icons.star_rounded, textColor),
          const SizedBox(height: 8),
          if (_order.vendorRating != null)
            _ratingCard('Vendor', _order.vendorRating!, _order.vendorReview, isDark, cardColor, textColor, subtextColor, borderColor),
          if (_order.riderRating != null) ...[
            const SizedBox(height: 8),
            _ratingCard('Rider', _order.riderRating!, _order.riderReview, isDark, cardColor, textColor, subtextColor, borderColor),
          ],
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 2 — Timeline & Time Tracking
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTimelineTab(bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final tb = _timeBreakdown;
    final totalMin = tb['totalTime'] as int;
    final isComplete = tb['isComplete'] as bool;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ─── Total time card ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDark ? const Color(0xFF141414) : Colors.white,
                isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Text(
                isComplete ? 'TOTAL ORDER TIME' : 'TIME ELAPSED',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: subtextColor, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                _formatMinutes(totalMin),
                style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w900,
                  color: isComplete ? accentGreen : textColor,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isComplete ? 'Order completed' : 'Order in progress...',
                style: TextStyle(fontSize: 12, color: subtextColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ─── Phase breakdown ──────────────────────────────────────
        _sectionHeader('Phase Breakdown', Icons.timeline_rounded, textColor),
        const SizedBox(height: 12),

        _timelineStep(
          label: 'Order Placed',
          time: DateFormat('HH:mm').format(toRwandaTime(_order.createdAt)),
          duration: null,
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFFF59E0B),
          isCompleted: true,
          isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor, cardColor: cardColor,
        ),
        _timelineStep(
          label: 'Vendor Accepted',
          time: _order.acceptedAt != null ? DateFormat('HH:mm').format(toRwandaTime(_order.acceptedAt!)) : '--:--',
          duration: tb['waitForAccept'] != null ? '${tb['waitForAccept']} min wait' : null,
          icon: Icons.check_circle_outline_rounded,
          color: blue,
          isCompleted: _order.acceptedAt != null,
          isLate: (tb['waitForAccept'] ?? 0) > 5,
          isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor, cardColor: cardColor,
        ),
        _timelineStep(
          label: 'Order Ready',
          time: _order.readyAt != null ? DateFormat('HH:mm').format(toRwandaTime(_order.readyAt!)) : '--:--',
          duration: tb['prepTime'] != null ? '${tb['prepTime']} min prep' : null,
          icon: Icons.inventory_2_rounded,
          color: cyan,
          isCompleted: _order.readyAt != null,
          isLate: (tb['prepTime'] ?? 0) > 30,
          isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor, cardColor: cardColor,
        ),
        _timelineStep(
          label: 'Delivered',
          time: _order.completedAt != null ? DateFormat('HH:mm').format(toRwandaTime(_order.completedAt!)) : '--:--',
          duration: tb['deliveryTime'] != null ? '${tb['deliveryTime']} min delivery' : null,
          icon: Icons.check_circle_rounded,
          color: accentGreen,
          isCompleted: _order.completedAt != null,
          isLate: (tb['deliveryTime'] ?? 0) > 45,
          isLast: true,
          isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor, cardColor: cardColor,
        ),

        const SizedBox(height: 18),

        // ─── Rider time performance ──────────────────────────────
        if (_order.riderName != null && _order.riderName!.isNotEmpty) ...[
          _sectionHeader('Rider Performance', Icons.speed_rounded, textColor),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, size: 20, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_order.riderName!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                          Text(_order.riderPhone ?? 'No phone', style: TextStyle(fontSize: 11, color: subtextColor)),
                        ],
                      ),
                    ),
                    if (_order.isRunningLate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: red.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Text('LATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _riderMetric(
                      label: 'Pickup Time',
                      value: tb['prepTime'] != null ? '${tb['prepTime']}m' : '--',
                      color: cyan, isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _riderMetric(
                      label: 'Delivery Time',
                      value: tb['deliveryTime'] != null ? '${tb['deliveryTime']}m' : '--',
                      color: accentGreen, isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _riderMetric(
                      label: 'Distance',
                      value: _order.deliveryDistanceKm > 0 ? '${_order.deliveryDistanceKm.toStringAsFixed(1)}km' : '--',
                      color: blue, isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _riderMetric(
                      label: 'ETA',
                      value: _order.minutesRemaining != null ? '${_order.minutesRemaining}m' : '--',
                      color: _order.isRunningLate ? red : gold, isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 3 — Actions
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildActionsTab(bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final hasRider = _order.riderId != null && _order.riderId!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ─── Assign rider ────────────────────────────────────────
        _sectionHeader('Rider Assignment', Icons.person_add_alt_1_rounded, textColor),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            children: [
              if (hasRider) ...[
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFF4CAF50)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Currently Assigned', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subtextColor)),
                          Text(_order.riderName!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _assigningRider ? null : () => _showAssignRiderSheet(context, isDark, textColor, subtextColor, cardColor, borderColor),
                  icon: _assigningRider
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(hasRider ? Icons.swap_horiz_rounded : Icons.person_add_rounded, size: 18),
                  label: Text(hasRider ? 'Reassign Rider' : 'Assign Rider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ─── Send notification ───────────────────────────────────
        _sectionHeader('Notifications', Icons.notifications_active_rounded, textColor),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            children: [
              _actionTile(
                icon: Icons.store_rounded,
                label: 'Notify Vendor',
                subtitle: 'Push alert to vendor about this order',
                color: const Color(0xFF6366F1),
                onTap: () => _sendNotification(context, 'vendor', textColor, subtextColor, cardColor, borderColor, isDark),
                isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor,
              ),
              Divider(color: borderColor, height: 1),
              _actionTile(
                icon: Icons.person_rounded,
                label: 'Notify Customer',
                subtitle: 'Send update to customer',
                color: blue,
                onTap: () => _sendNotification(context, 'customer', textColor, subtextColor, cardColor, borderColor, isDark),
                isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor,
              ),
              if (hasRider) ...[
                Divider(color: borderColor, height: 1),
                _actionTile(
                  icon: Icons.two_wheeler_rounded,
                  label: 'Notify Rider',
                  subtitle: 'Send alert to assigned rider',
                  color: purple,
                  onTap: () => _sendNotification(context, 'rider', textColor, subtextColor, cardColor, borderColor, isDark),
                  isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor,
                ),
              ],
              Divider(color: borderColor, height: 1),
              _actionTile(
                icon: Icons.campaign_rounded,
                label: 'Notify All',
                subtitle: 'Send push to vendor, customer & rider',
                color: gold,
                onTap: () => _sendNotification(context, 'all', textColor, subtextColor, cardColor, borderColor, isDark),
                isDark: isDark, textColor: textColor, subtextColor: subtextColor, borderColor: borderColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ─── Order info ──────────────────────────────────────────
        _sectionHeader('Order Info', Icons.info_outline_rounded, textColor),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            children: [
              _infoRow('Order ID', _order.id, textColor, subtextColor, copyable: true),
              _infoRow('Order Number', _order.orderNumber, textColor, subtextColor, copyable: true),
              _infoRow('Vendor ID', _order.vendorId, textColor, subtextColor),
              _infoRow('Customer ID', _order.customerId, textColor, subtextColor),
              if (_order.riderId != null) _infoRow('Rider ID', _order.riderId!, textColor, subtextColor),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Assign Rider Sheet
  // ═══════════════════════════════════════════════════════════════════
  void _showAssignRiderSheet(BuildContext context, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) async {
    List<Map<String, dynamic>> riders = [];
    bool loading = true;

    try {
      final service = AdminDashboardService(context.read<AuthProvider>().apiService);
      final result = await service.getRiders(perPage: 100);
      riders = List<Map<String, dynamic>>.from(result['riders'] ?? []);
      loading = false;
    } catch (e) {
      loading = false;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.person_add_rounded, color: accentGreen, size: 22),
                    const SizedBox(width: 10),
                    Text('Select Rider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                  ],
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                    : riders.isEmpty
                        ? Center(child: Text('No riders available', style: TextStyle(color: subtextColor)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: riders.length,
                            itemBuilder: (_, i) {
                              final r = riders[i];
                              final name = r['name'] ?? r['first_name'] ?? 'Rider ${r['id']}';
                              final phone = r['phone'] ?? 'No phone';
                              final isCurrentRider = r['id']?.toString() == _order.riderId;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isCurrentRider ? accentGreen.withOpacity(0.08) : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF9FAFB)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrentRider ? accentGreen.withOpacity(0.3) : borderColor,
                                    width: 0.5,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.two_wheeler_rounded, size: 20, color: Color(0xFF8B5CF6)),
                                  ),
                                  title: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                                  subtitle: Text(phone, style: TextStyle(fontSize: 12, color: subtextColor)),
                                  trailing: isCurrentRider
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                          child: const Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50))),
                                        )
                                      : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                  onTap: isCurrentRider ? null : () async {
                                    Navigator.pop(ctx);
                                    await _assignRider(r['id'].toString(), name);
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _assignRider(String riderId, String riderName) async {
    setState(() => _assigningRider = true);
    try {
      final service = AdminDashboardService(context.read<AuthProvider>().apiService);
      final result = await service.assignOrderToRider(orderId: _order.id, riderId: riderId);
      if (mounted) {
        // Refresh order list
        context.read<AdminOrderProvider>().fetchOrders();
        // Show success with rider name from response
        final assignedName = result['rider_name'] ?? riderName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('$assignedName assigned — rider & customer notified')),
              ],
            ),
            backgroundColor: accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign rider: $e'),
            backgroundColor: red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigningRider = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Send Notification
  // ═══════════════════════════════════════════════════════════════════
  void _sendNotification(BuildContext context, String target, Color textColor, Color subtextColor, Color cardColor, Color borderColor, bool isDark) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: accentGreen, size: 22),
            const SizedBox(width: 10),
            Text(
              target == 'all' ? 'Notify Everyone' : 'Notify ${target[0].toUpperCase()}${target.substring(1)}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Write a message to send as push notification', style: TextStyle(fontSize: 12, color: subtextColor)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Please check this order...',
                hintStyle: TextStyle(color: subtextColor.withOpacity(0.5)),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: subtextColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final service = AdminDashboardService(context.read<AuthProvider>().apiService);
                final recipients = target == 'all' ? ['customer', 'vendor', 'rider'] : [target];
                await service.sendOrderMessage(orderId: _order.id, message: controller.text.trim(), recipients: recipients);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Notification sent!'), backgroundColor: accentGreen, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Send', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Widget Helpers
  // ═══════════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, IconData icon, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: accentGreen),
          ),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
        ],
      ),
    );
  }

  Widget _personCard({
    required IconData icon, required String role, required String name, required String phone, required Color color,
    required bool isDark, required Color textColor, required Color subtextColor, required Color borderColor, required Color cardColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.2)),
                const SizedBox(height: 1),
                Text(phone, style: TextStyle(fontSize: 12, color: subtextColor)),
              ],
            ),
          ),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.phone_rounded, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  Widget _riderCard(bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final hasRider = _order.riderName != null && _order.riderName!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !hasRider && _order.status != OrderStatus.cancelled ? red.withOpacity(0.4) : borderColor,
          width: !hasRider && _order.status != OrderStatus.cancelled ? 1.5 : 0.5,
        ),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasRider 
                    ? [purple.withOpacity(0.15), purple.withOpacity(0.08)]
                    : [red.withOpacity(0.12), red.withOpacity(0.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.two_wheeler_rounded, size: 22,
              color: hasRider ? purple : red,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RIDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: hasRider ? purple : red, letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Text(
                  hasRider ? _order.riderName! : 'No Rider Assigned',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: hasRider ? textColor : red, letterSpacing: -0.2),
                ),
                const SizedBox(height: 1),
                Text(
                  hasRider ? (_order.riderPhone ?? 'No phone') : 'Tap Actions tab to assign',
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
              ],
            ),
          ),
          if (!hasRider && _order.status != OrderStatus.cancelled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: red.withOpacity(0.2)),
              ),
              child: const Text('ASSIGN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
            )
          else if (hasRider)
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.phone_rounded, size: 16, color: purple),
            ),
        ],
      ),
    );
  }

  Widget _timelineStep({
    required String label, required String time, String? duration, required IconData icon, required Color color,
    required bool isCompleted, bool isLate = false, bool isLast = false,
    required bool isDark, required Color textColor, required Color subtextColor, required Color borderColor, required Color cardColor,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical line + dot
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted ? color.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF3F4F6)),
                    shape: BoxShape.circle,
                    border: Border.all(color: isCompleted ? color : borderColor),
                  ),
                  child: Icon(icon, size: 14, color: isCompleted ? color : subtextColor.withOpacity(0.4)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2, 
                      color: isCompleted ? color.withOpacity(0.3) : borderColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isLate ? red.withOpacity(0.3) : borderColor, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isCompleted ? textColor : subtextColor)),
                        if (duration != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            duration,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isLate ? red : accentGreen),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(time, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isCompleted ? textColor : subtextColor.withOpacity(0.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riderMetric({required String label, required String value, required Color color, required bool isDark}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _payRow(String label, String value, Color textColor, Color subtextColor, {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: subtextColor)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: valueColor ?? textColor)),
      ],
    );
  }

  Widget _payChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _codeCard(String title, String code, bool verified, bool isDark, Color cardColor, Color textColor, Color subtextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: verified ? accentGreen.withOpacity(0.3) : borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subtextColor)),
          const SizedBox(height: 6),
          Text(code, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 2)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: verified ? accentGreen.withOpacity(0.1) : gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              verified ? 'Verified' : 'Pending',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: verified ? accentGreen : gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingCard(String role, int rating, String? review, bool isDark, Color cardColor, Color textColor, Color subtextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$role Rating', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor)),
              const Spacer(),
              ...List.generate(5, (i) => Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: i < rating ? gold : subtextColor.withOpacity(0.2),
                ),
              )),
              const SizedBox(width: 6),
              Text('$rating/5', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
            ],
          ),
          if (review != null && review.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, size: 14, color: subtextColor.withOpacity(0.3)),
                const SizedBox(width: 6),
                Expanded(child: Text(review, style: TextStyle(fontSize: 12, color: subtextColor, fontStyle: FontStyle.italic, height: 1.4))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon, required String label, required String subtitle, required Color color, required VoidCallback onTap,
    required bool isDark, required Color textColor, required Color subtextColor, required Color borderColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: subtextColor)),
                ],
              ),
            ),
            Icon(Icons.send_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color textColor, Color subtextColor, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: subtextColor)),
          const Spacer(),
          Text(
            value.length > 20 ? '${value.substring(0, 20)}...' : value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
          ),
          if (copyable) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied: $label'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                );
              },
              child: Icon(Icons.copy_rounded, size: 14, color: subtextColor.withOpacity(0.5)),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return '${hours}h ${remaining}m';
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
