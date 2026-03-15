// lib/screens/vendor/vendor_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vendor_order_provider.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';

class VendorEarningsScreen extends StatefulWidget {
  const VendorEarningsScreen({super.key});

  @override
  State<VendorEarningsScreen> createState() => _VendorEarningsScreenState();
}

class _VendorEarningsScreenState extends State<VendorEarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────
  List<Order> _completedOrders(VendorOrderProvider p) =>
      p.orders.where((o) => o.status == OrderStatus.completed).toList();

  List<Order> _todayOrders(VendorOrderProvider p) =>
      _completedOrders(p).where((o) => _isToday(o.createdAt)).toList();

  List<Order> _weekOrders(VendorOrderProvider p) =>
      _completedOrders(p).where((o) => _isThisWeek(o.createdAt)).toList();

  List<Order> _monthOrders(VendorOrderProvider p) =>
      _completedOrders(p).where((o) => _isThisMonth(o.createdAt)).toList();

  double _sumSubtotal(List<Order> orders) =>
      orders.fold(0.0, (s, o) => s + o.subtotal);

  int _sumItems(List<Order> orders) =>
      orders.fold(0, (s, o) => s + o.items.length);

  bool _isToday(DateTime d) {
    final n = nowInRwanda(), r = toRwandaTime(d);
    return r.year == n.year && r.month == n.month && r.day == n.day;
  }

  bool _isThisWeek(DateTime d) {
    final n = nowInRwanda();
    return toRwandaTime(d)
        .isAfter(n.subtract(Duration(days: n.weekday - 1 + 1)));
  }

  bool _isThisMonth(DateTime d) {
    final n = nowInRwanda(), r = toRwandaTime(d);
    return r.year == n.year && r.month == n.month;
  }

  String _fmt(double v) => NumberFormat('#,###').format(v);

  // ── build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final prov = context.watch<VendorOrderProvider>();
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF1F2F4);
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final card = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    const accent = Color(0xFF22C55E);

    final todayList = _todayOrders(prov);
    final weekList = _weekOrders(prov);
    final monthList = _monthOrders(prov);

    final selectedOrders = [todayList, weekList, monthList][_tabController.index];
    final selectedEarnings = _sumSubtotal(selectedOrders);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Earnings',
            style: TextStyle(
                color: text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
      ),
      body: RefreshIndicator(
        onRefresh: () => prov.fetchOrders(),
        color: text,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(children: [
                  // ── Earnings card ──────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF111111), Color(0xFF1A1A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'RWF ${_fmt(selectedEarnings)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5)),
                              const SizedBox(height: 2),
                              Text('Product sales earnings',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.45),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                            ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_bag_rounded,
                                  color: accent, size: 14),
                              const SizedBox(width: 5),
                              Text('${selectedOrders.length}',
                                  style: const TextStyle(
                                      color: accent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                            ]),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 14),

                  // ── Tab bar ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: isDark ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      labelColor: isDark ? Colors.black : Colors.white,
                      unselectedLabelColor: sub,
                      labelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      splashFactory: NoSplash.splashFactory,
                      tabs: const [
                        Tab(text: 'Today'),
                        Tab(text: 'Week'),
                        Tab(text: 'Month'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Quick stats row ────────────────────────
                  Row(children: [
                    _miniStat('Orders', '${selectedOrders.length}', Icons.receipt_long_rounded, accent, card, text, sub),
                    const SizedBox(width: 10),
                    _miniStat('Items', '${_sumItems(selectedOrders)}', Icons.inventory_2_rounded, const Color(0xFF3B82F6), card, text, sub),
                    const SizedBox(width: 10),
                    _miniStat('Avg', selectedOrders.isEmpty ? '0' : 'RWF ${_fmt(selectedEarnings / selectedOrders.length)}', Icons.trending_up_rounded, const Color(0xFFF59E0B), card, text, sub),
                  ]),

                  const SizedBox(height: 18),

                  // ── Recent orders label ────────────────────
                  Row(children: [
                    Text('Recent Orders',
                        style: TextStyle(
                            color: text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2)),
                    const Spacer(),
                    Text('${selectedOrders.length} total',
                        style: TextStyle(
                            color: sub,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                ]),
              ),
            ),

            // ── Order list ─────────────────────────────────
            if (selectedOrders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(text, sub),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) =>
                        _orderTile(selectedOrders[i], isDark, card, text, sub),
                    childCount: selectedOrders.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Mini stat chip ─────────────────────────────────────────
  Widget _miniStat(String label, String value, IconData icon, Color accent,
      Color card, Color text, Color sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: sub, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── Order tile ─────────────────────────────────────────────
  Widget _orderTile(
      Order order, bool isDark, Color card, Color text, Color sub) {
    final time = formatRwandaTime(
        toRwandaTime(order.createdAt), 'MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        // status dot
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF22C55E), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                        order.customerName ??
                            shortenOrderNumber(order.orderNumber),
                        style: TextStyle(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('RWF ${_fmt(order.subtotal)}',
                      style: TextStyle(
                          color: text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Text(shortenOrderNumber(order.orderNumber),
                      style: TextStyle(
                          color: sub,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Container(
                      width: 3,
                      height: 3,
                      decoration:
                          BoxDecoration(color: sub, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                      '${order.items.length} item${order.items.length != 1 ? "s" : ""}',
                      style: TextStyle(
                          color: sub,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text(time,
                      style: TextStyle(color: sub, fontSize: 10)),
                ]),
              ]),
        ),
      ]),
    );
  }

  // ── Empty state ────────────────────────────────────────────
  Widget _emptyState(Color text, Color sub) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.receipt_long_rounded,
              size: 36, color: Color(0xFF22C55E)),
        ),
        const SizedBox(height: 16),
        Text('No orders yet',
            style: TextStyle(
                color: text, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Completed orders will appear here',
            style: TextStyle(color: sub, fontSize: 12)),
      ]),
    );
  }

  // ── Payout dialog (kept) ───────────────────────────────────
  void _showPayoutDialog(
    BuildContext context,
    double suggestedAmount,
    bool isDarkMode,
    Color cardColor,
    Color textColor,
  ) {
    final TextEditingController amountController = TextEditingController(
      text: suggestedAmount > 0 ? suggestedAmount.toStringAsFixed(0) : '',
    );
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Request Payout',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance, size: 64, color: Color(0xFF3B82F6)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter amount in RWF',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                  ),
                  prefix: Text(
                    'Rwf ',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B82F6),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Funds will be transferred to your registered bank account within 2-3 business days.',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                amountController.dispose();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                amountController.dispose();
                _submitPayoutRequest(context, amount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPayoutRequest(BuildContext context, double amount) async {
    try {
      final authProvider = context.read<AuthProvider>();

      final response = await authProvider.apiService.post(
        '/api/vendor/payout-request',
        {'amount': amount},
      );

      if (mounted) {
        try {
          if (response['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Payout request submitted successfully'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
                margin: const EdgeInsets.all(16),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['error'] ?? 'Failed to submit payout request'),
                backgroundColor: Colors.red,
                margin: const EdgeInsets.all(16),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          // Silently ignore if widget is no longer active
          print('Snackbar error: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              margin: const EdgeInsets.all(16),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          // Silently ignore if widget is no longer active
          print('Snackbar error: $e');
        }
      }
    }
  }

  void _showInfoDialog(
    BuildContext context,
    bool isDarkMode,
    Color cardColor,
    Color textColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Earnings Info',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.info_outline, 'Your real earnings from completed orders', isDarkMode),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.schedule, 'Payout time: 2-3 business days', isDarkMode),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.account_balance, 'Paid to registered bank account', isDarkMode),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.receipt, 'Detailed statement available on web', isDarkMode),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDarkMode) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}