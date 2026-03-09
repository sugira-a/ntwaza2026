// lib/screens/rider/rider_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/rider_order_provider.dart';

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_loaded && mounted) {
        _loaded = true;
        final p = context.read<RiderOrderProvider>();
        if (p.earnings.isEmpty && !p.isLoadingEarnings) p.fetchEarnings();
      }
    });
  }

  String _currency(double v) => 'RWF ${v.toStringAsFixed(0)}';

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RiderOrderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final card = isDark ? const Color(0xFF252525) : Colors.white;
    final border = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    final e = p.earnings;
    final total = (e['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    final deliveries = (e['totalDeliveries'] as num?)?.toInt() ?? 0;
    final avg = (e['averagePerDelivery'] as num?)?.toDouble() ?? 0.0;
    final month = (e['thisMonthEarnings'] as num?)?.toDouble() ?? 0.0;
    final week = (e['thisWeekEarnings'] as num?)?.toDouble() ?? 0.0;
    final pending = (e['pendingPayouts'] as num?)?.toDouble() ?? 0.0;
    final recent = e['recentDeliveries'] as List? ?? [];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: text),
        title: Text('Earnings',
            style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: text),
            onPressed: () => p.fetchEarnings(),
          ),
        ],
      ),
      body: p.isLoadingEarnings
          ? Center(child: CircularProgressIndicator(color: text, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: () => p.fetchEarnings(),
              color: text,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Hero Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF000000), Color(0xFF1A1A1A)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text('Total Earnings',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.18), shape: BoxShape.circle),
                                child: const Icon(Icons.trending_up_rounded, color: Color(0xFF10B981), size: 20),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Text(_currency(total),
                                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1)),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _tag('All Time'),
                              _tag('Pending: ${_currency(pending)}'),
                              _tag('$deliveries deliveries'),
                            ]),
                          ]),
                        ),

                        const SizedBox(height: 24),
                        Text('Performance',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: text)),
                        const SizedBox(height: 12),

                        // 2x2 Stats Grid
                        Row(children: [
                          Expanded(child: _statCard('This Month', _currency(month), Icons.calendar_month_rounded, const Color(0xFF10B981), card, border, text, sub)),
                          const SizedBox(width: 12),
                          Expanded(child: _statCard('This Week', _currency(week), Icons.today_rounded, const Color(0xFF3B82F6), card, border, text, sub)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _statCard('Deliveries', '$deliveries', Icons.two_wheeler_rounded, Colors.grey, card, border, text, sub)),
                          const SizedBox(width: 12),
                          Expanded(child: _statCard('Avg / Delivery', _currency(avg), Icons.show_chart_rounded, Colors.grey, card, border, text, sub)),
                        ]),

                        const SizedBox(height: 24),
                        Text('Recent Deliveries',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: text)),
                        const SizedBox(height: 12),

                        if (recent.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
                            child: Center(
                              child: Column(children: [
                                Icon(Icons.two_wheeler_rounded, size: 24, color: sub),
                                const SizedBox(height: 8),
                                Text('No deliveries yet', style: TextStyle(color: sub, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          )
                        else
                          ...recent.map<Widget>((d) {
                            final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
                            final orderNum = (d['orderNumber'] ?? 'N/A').toString();
                            final customer = (d['customerName'] ?? 'Unknown').toString();
                            final date = _formatDate(d['deliveredAt']?.toString());
                            return _recentTile(orderNum, customer, _currency(amount), date, card, border, text, sub);
                          }),

                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color,
      Color card, Color border, Color text, Color sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _recentTile(String orderNum, String customer, String amount,
      String date, Color card, Color border, Color text, Color sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(orderNum, style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(customer, style: TextStyle(color: sub, fontSize: 11)),
            const SizedBox(height: 4),
            Text(date, style: TextStyle(color: sub, fontSize: 10)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(amount, style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
        ]),
      ]),
    );
  }
}
