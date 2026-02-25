// lib/screens/admin/admin_performance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/admin_order_provider.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';

class AdminPerformanceScreen extends StatefulWidget {
  const AdminPerformanceScreen({super.key});

  @override
  State<AdminPerformanceScreen> createState() => _AdminPerformanceScreenState();
}

class _AdminPerformanceScreenState extends State<AdminPerformanceScreen> {
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color mutedGray = Color(0xFF6B7280);
  static const Color gold = Color(0xFFFFB800);

  String _selectedPeriod = 'all';
  String _viewMode = 'vendors'; // vendors, riders

  List<Order> _filterByPeriod(List<Order> orders) {
    if (_selectedPeriod == 'all') return orders;
    final now = nowInRwanda();
    return orders.where((o) {
      if (o.createdAt == null) return false;
      final created = toRwandaTime(o.createdAt!);
      switch (_selectedPeriod) {
        case 'today':
          return created.year == now.year && created.month == now.month && created.day == now.day;
        case 'week':
          return now.difference(created).inDays < 7;
        case 'month':
          return now.difference(created).inDays < 30;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0B) : const Color(0xFFDADDE2);
    final textColor = isDark ? Colors.white : const Color(0xFF0B0B0B);
    final subtextColor = isDark ? Colors.white70 : mutedGray;
    final cardColor = isDark ? Colors.black : const Color(0xFFDADDE2);
    final borderColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    final allOrders = context.watch<AdminOrderProvider>().orders;
    final orders = _filterByPeriod(allOrders);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(color: Colors.black),
            padding: EdgeInsets.only(top: statusBarHeight),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Performance & Ratings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4),
                  ),
                ),
                const SizedBox(height: 14),
                _buildPeriodSelector(),
                const SizedBox(height: 14),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<AdminOrderProvider>().fetchOrders(),
              color: accentGreen,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                  // Overall metrics
                  _buildOverallMetrics(orders, isDark, textColor, subtextColor, cardColor, borderColor),
                  const SizedBox(height: 20),

                  // Toggle view
                  _buildViewToggle(isDark),
                  const SizedBox(height: 14),

                  if (_viewMode == 'vendors')
                    _buildVendorPerformance(orders, isDark, textColor, subtextColor, cardColor, borderColor),
                  if (_viewMode == 'riders')
                    _buildRiderPerformance(orders, isDark, textColor, subtextColor, cardColor, borderColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _PeriodChip(label: 'All Time', selected: _selectedPeriod == 'all', onTap: () => setState(() => _selectedPeriod = 'all')),
          const SizedBox(width: 8),
          _PeriodChip(label: 'Today', selected: _selectedPeriod == 'today', onTap: () => setState(() => _selectedPeriod = 'today')),
          const SizedBox(width: 8),
          _PeriodChip(label: 'Week', selected: _selectedPeriod == 'week', onTap: () => setState(() => _selectedPeriod = 'week')),
          const SizedBox(width: 8),
          _PeriodChip(label: 'Month', selected: _selectedPeriod == 'month', onTap: () => setState(() => _selectedPeriod = 'month')),
        ],
      ),
    );
  }

  Widget _buildViewToggle(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _viewMode = 'vendors'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _viewMode == 'vendors' ? accentGreen.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _viewMode == 'vendors' ? accentGreen.withOpacity(0.4) : (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB)),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  'Vendor Ratings',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: _viewMode == 'vendors' ? accentGreen : (isDark ? Colors.white70 : mutedGray),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _viewMode = 'riders'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _viewMode == 'riders' ? accentGreen.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _viewMode == 'riders' ? accentGreen.withOpacity(0.4) : (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB)),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  'Rider Performance',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: _viewMode == 'riders' ? accentGreen : (isDark ? Colors.white70 : mutedGray),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Format minutes into human-readable duration
  String _formatDuration(double minutes) {
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '${minutes.toStringAsFixed(0)} min';
    final h = (minutes / 60).floor();
    final m = (minutes % 60).round();
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Widget _buildOverallMetrics(List<Order> orders, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    // Calculate metrics
    final vendorRatings = orders.where((o) => o.vendorRating != null).map((o) => o.vendorRating!).toList();
    final riderRatings = orders.where((o) => o.riderRating != null).map((o) => o.riderRating!).toList();

    final avgVendorRating = vendorRatings.isEmpty ? 0.0 : vendorRatings.reduce((a, b) => a + b) / vendorRatings.length;
    final avgRiderRating = riderRatings.isEmpty ? 0.0 : riderRatings.reduce((a, b) => a + b) / riderRatings.length;

    final hasVendorRatings = vendorRatings.isNotEmpty;
    final hasRiderRatings = riderRatings.isNotEmpty;

    // Delivery time analysis — prefer readyAt→completedAt for actual delivery time
    final deliveredOrders = orders.where((o) => o.status == OrderStatus.completed && o.completedAt != null && o.createdAt != null).toList();
    double avgDeliveryMinutes = 0;
    int lateCount = 0;
    if (deliveredOrders.isNotEmpty) {
      double totalMinutes = 0;
      for (final o in deliveredOrders) {
        // Use readyAt if available (actual delivery time), otherwise createdAt (full lifecycle)
        final start = o.readyAt != null ? toRwandaTime(o.readyAt!) : toRwandaTime(o.createdAt!);
        final completed = toRwandaTime(o.completedAt!);
        final minutes = completed.difference(start).inMinutes.toDouble();
        // Skip negative durations (data inconsistency)
        if (minutes < 0) continue;
        totalMinutes += minutes;
        if (o.isRunningLate == true || minutes > 60) lateCount++;
      }
      avgDeliveryMinutes = totalMinutes / deliveredOrders.length;
    }

    final deliveryRate = orders.isEmpty ? 0.0 : (deliveredOrders.length / orders.length * 100);

    // Display values  — show '—' when no data
    final vendorRatingValue = hasVendorRatings ? avgVendorRating.toStringAsFixed(1) : '—';
    final riderRatingValue = hasRiderRatings ? avgRiderRating.toStringAsFixed(1) : '—';
    final vendorRatingSubtitle = hasVendorRatings ? '${vendorRatings.length} reviews' : 'No ratings yet';
    final riderRatingSubtitle = hasRiderRatings ? '${riderRatings.length} reviews' : 'No ratings yet';
    final deliveryTimeValue = deliveredOrders.isEmpty ? '—' : _formatDuration(avgDeliveryMinutes);
    final deliverySubtitle = deliveredOrders.isEmpty ? 'No deliveries yet' : '${deliveredOrders.length} deliveries';

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _MetricCard(
              icon: Icons.star_rounded,
              label: 'Vendor Rating',
              value: vendorRatingValue,
              subtitle: vendorRatingSubtitle,
              color: hasVendorRatings ? gold : (isDark ? Colors.white38 : Colors.black38),
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              icon: Icons.star_rounded,
              label: 'Rider Rating',
              value: riderRatingValue,
              subtitle: riderRatingSubtitle,
              color: hasRiderRatings ? gold : (isDark ? Colors.white38 : Colors.black38),
              isDark: isDark,
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _MetricCard(
              icon: Icons.timer_rounded,
              label: 'Avg Delivery',
              value: deliveryTimeValue,
              subtitle: deliverySubtitle,
              color: const Color(0xFF3B82F6),
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              icon: Icons.warning_rounded,
              label: 'Late Deliveries',
              value: deliveredOrders.isEmpty ? '—' : '$lateCount',
              subtitle: deliveredOrders.isEmpty ? 'No data' : '${deliveryRate.toStringAsFixed(0)}% completion',
              color: lateCount > 0 ? const Color(0xFFEF4444) : accentGreen,
              isDark: isDark,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildVendorPerformance(List<Order> orders, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    // Group by vendor
    final vendorMap = <String, _VendorPerf>{};
    for (final o in orders) {
      final name = o.vendorName.isEmpty ? 'Unknown' : o.vendorName;
      vendorMap.putIfAbsent(name, () => _VendorPerf(name: name));
      vendorMap[name]!.totalOrders++;
      if (o.vendorRating != null) {
        vendorMap[name]!.ratings.add(o.vendorRating!);
      }
      if (o.vendorReview != null && o.vendorReview!.isNotEmpty) {
        vendorMap[name]!.reviews.add(o.vendorReview!);
      }
      if (o.status == OrderStatus.completed) vendorMap[name]!.deliveredCount++;
      if (o.status == OrderStatus.cancelled) vendorMap[name]!.cancelledCount++;
    }

    final sorted = vendorMap.values.toList()..sort((a, b) => b.avgRating.compareTo(a.avgRating));

    if (sorted.isEmpty) {
      return _emptyState('No vendor data available', isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vendor Rankings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final v = entry.value;
          return _VendorPerfCard(rank: rank, perf: v, isDark: isDark);
        }),
      ],
    );
  }

  Widget _buildRiderPerformance(List<Order> orders, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final riderMap = <String, _RiderPerf>{};
    for (final o in orders) {
      final name = (o.riderName ?? '').isEmpty ? 'Unassigned' : o.riderName!;
      if (name == 'Unassigned') continue;
      riderMap.putIfAbsent(name, () => _RiderPerf(name: name));
      riderMap[name]!.totalOrders++;
      if (o.riderRating != null) {
        riderMap[name]!.ratings.add(o.riderRating!);
      }
      if (o.riderReview != null && o.riderReview!.isNotEmpty) {
        riderMap[name]!.reviews.add(o.riderReview!);
      }
      if (o.status == OrderStatus.completed && o.completedAt != null && o.createdAt != null) {
        riderMap[name]!.deliveredCount++;
        final created = toRwandaTime(o.createdAt!);
        final completed = toRwandaTime(o.completedAt!);
        final mins = completed.difference(created).inMinutes.toDouble();
        riderMap[name]!.deliveryTimes.add(mins);
        if (o.isRunningLate == true || mins > 60) riderMap[name]!.lateCount++;
      }
      if (o.status == OrderStatus.cancelled) riderMap[name]!.cancelledCount++;
    }

    final sorted = riderMap.values.toList()..sort((a, b) => b.avgRating.compareTo(a.avgRating));

    if (sorted.isEmpty) {
      return _emptyState('No rider data available', isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rider Rankings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final r = entry.value;
          return _RiderPerfCard(rank: rank, perf: r, isDark: isDark);
        }),
      ],
    );
  }

  Widget _emptyState(String msg, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.insights_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(msg, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}

// ─── Data models ────────────────────────────────────────────────────
class _VendorPerf {
  final String name;
  int totalOrders = 0;
  int deliveredCount = 0;
  int cancelledCount = 0;
  List<int> ratings = [];
  List<String> reviews = [];
  double get avgRating => ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;
  _VendorPerf({required this.name});
}

class _RiderPerf {
  final String name;
  int totalOrders = 0;
  int deliveredCount = 0;
  int cancelledCount = 0;
  int lateCount = 0;
  List<int> ratings = [];
  List<String> reviews = [];
  List<double> deliveryTimes = [];
  double get avgRating => ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;
  double get avgDeliveryTime => deliveryTimes.isEmpty ? 0.0 : deliveryTimes.reduce((a, b) => a + b) / deliveryTimes.length;
  _RiderPerf({required this.name});
}

// ─── Period Chip ────────────────────────────────────────────────────
class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4CAF50).withOpacity(0.2) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFF4CAF50).withOpacity(0.4) : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF4CAF50) : Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Metric Card ────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _MetricCard({required this.icon, required this.label, required this.value, required this.subtitle, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? Colors.black : const Color(0xFFDADDE2);
    final borderColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF0B0B0B);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: subtextColor)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: subtextColor)),
        ],
      ),
    );
  }
}

// ─── Vendor Performance Card ────────────────────────────────────────
class _VendorPerfCard extends StatefulWidget {
  final int rank;
  final _VendorPerf perf;
  final bool isDark;

  const _VendorPerfCard({required this.rank, required this.perf, required this.isDark});

  @override
  State<_VendorPerfCard> createState() => _VendorPerfCardState();
}

class _VendorPerfCardState extends State<_VendorPerfCard> {
  bool _showReviews = false;

  @override
  Widget build(BuildContext context) {
    final accentGreen = const Color(0xFF4CAF50);
    final gold = const Color(0xFFFFB800);
    final cardColor = widget.isDark ? Colors.black : const Color(0xFFDADDE2);
    final borderColor = widget.isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF0B0B0B);
    final subtextColor = widget.isDark ? Colors.white70 : const Color(0xFF6B7280);
    final v = widget.perf;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Rank
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: widget.rank <= 3 ? gold.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#${widget.rank}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.rank <= 3 ? gold : subtextColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 3),
                      v.ratings.isEmpty
                        ? Text('No ratings yet', style: TextStyle(fontSize: 11, color: subtextColor, fontStyle: FontStyle.italic))
                        : Row(
                            children: [
                              ...List.generate(5, (i) => Icon(
                                i < v.avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 13, color: i < v.avgRating.round() ? gold : subtextColor.withOpacity(0.3),
                              )),
                              const SizedBox(width: 6),
                              Text('${v.avgRating.toStringAsFixed(1)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                              Text(' (${v.ratings.length})', style: TextStyle(fontSize: 10, color: subtextColor)),
                            ],
                          ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${v.totalOrders} orders', style: TextStyle(fontSize: 11, color: subtextColor)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${v.deliveredCount}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentGreen)),
                        Text(' / ', style: TextStyle(fontSize: 10, color: subtextColor)),
                        Text('${v.cancelledCount}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Reviews expandable
          if (v.reviews.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _showReviews = !_showReviews),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showReviews ? 'Hide Reviews' : 'Show ${v.reviews.length} Reviews',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentGreen),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showReviews ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16, color: accentGreen,
                    ),
                  ],
                ),
              ),
            ),
            if (_showReviews)
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor, width: 0.3)),
                ),
                child: Column(
                  children: v.reviews.take(5).map((review) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded, size: 14, color: subtextColor.withOpacity(0.4)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            review,
                            style: TextStyle(fontSize: 12, color: subtextColor, fontStyle: FontStyle.italic, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Rider Performance Card ─────────────────────────────────────────
class _RiderPerfCard extends StatefulWidget {
  final int rank;
  final _RiderPerf perf;
  final bool isDark;

  const _RiderPerfCard({required this.rank, required this.perf, required this.isDark});

  @override
  State<_RiderPerfCard> createState() => _RiderPerfCardState();
}

class _RiderPerfCardState extends State<_RiderPerfCard> {
  bool _showReviews = false;

  @override
  Widget build(BuildContext context) {
    final accentGreen = const Color(0xFF4CAF50);
    final gold = const Color(0xFFFFB800);
    final cyan = const Color(0xFF06B6D4);
    final cardColor = widget.isDark ? Colors.black : const Color(0xFFDADDE2);
    final borderColor = widget.isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF0B0B0B);
    final subtextColor = widget.isDark ? Colors.white70 : const Color(0xFF6B7280);
    final r = widget.perf;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Rank
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: widget.rank <= 3 ? gold.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '#${widget.rank}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.rank <= 3 ? gold : subtextColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 3),
                          r.ratings.isEmpty
                            ? Text('No ratings yet', style: TextStyle(fontSize: 11, color: subtextColor, fontStyle: FontStyle.italic))
                            : Row(
                                children: [
                                  ...List.generate(5, (i) => Icon(
                                    i < r.avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 13, color: i < r.avgRating.round() ? gold : subtextColor.withOpacity(0.3),
                                  )),
                                  const SizedBox(width: 6),
                                  Text('${r.avgRating.toStringAsFixed(1)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                                  Text(' (${r.ratings.length})', style: TextStyle(fontSize: 10, color: subtextColor)),
                                ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Stats row
                Row(
                  children: [
                    _MiniStat(label: 'Deliveries', value: '${r.deliveredCount}', color: accentGreen, isDark: widget.isDark),
                    const SizedBox(width: 6),
                    _MiniStat(label: 'Avg Time', value: '${r.avgDeliveryTime.toStringAsFixed(0)}m', color: cyan, isDark: widget.isDark),
                    const SizedBox(width: 6),
                    _MiniStat(label: 'Late', value: '${r.lateCount}', color: r.lateCount > 0 ? const Color(0xFFEF4444) : accentGreen, isDark: widget.isDark),
                    const SizedBox(width: 6),
                    _MiniStat(label: 'Cancelled', value: '${r.cancelledCount}', color: const Color(0xFFEF4444), isDark: widget.isDark),
                  ],
                ),
              ],
            ),
          ),
          // Reviews
          if (r.reviews.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _showReviews = !_showReviews),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showReviews ? 'Hide Reviews' : 'Show ${r.reviews.length} Reviews',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentGreen),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showReviews ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16, color: accentGreen,
                    ),
                  ],
                ),
              ),
            ),
            if (_showReviews)
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor, width: 0.3)),
                ),
                child: Column(
                  children: r.reviews.take(5).map((review) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded, size: 14, color: subtextColor.withOpacity(0.4)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            review,
                            style: TextStyle(fontSize: 12, color: subtextColor, fontStyle: FontStyle.italic, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Mini Stat ──────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MiniStat({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
