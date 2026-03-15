// lib/screens/rider/rider_main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/pickup_order_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/order.dart';
import '../../models/pickup_order.dart';
import '../../utils/helpers.dart';
import 'rider_order_detail.dart';
import 'rider_pickup_order_detail.dart';
import 'rider_earnings_screen.dart';
import 'rider_delivery_history.dart';
import 'rider_profile_screen.dart';
import 'rider_notifications_screen.dart';

class RiderMainScreen extends StatefulWidget {
  const RiderMainScreen({super.key});

  @override
  State<RiderMainScreen> createState() => _RiderMainScreenState();
}

class _RiderMainScreenState extends State<RiderMainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _orderTabController;
  bool _initialized = false;
  bool _isOnline = false;

  static const int _pollSeconds = 30;
  static const String supportPhone = '0782195474';

  @override
  void initState() {
    super.initState();
    _orderTabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeData());
  }

  Future<void> _initializeData() async {
    if (_initialized) return;
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null || authProvider.user == null) {
      if (mounted) context.go('/login');
      return;
    }
    _initialized = true;

    final riderProvider = context.read<RiderOrderProvider>();
    final riderId = authProvider.user!.id;

    await riderProvider.fetchAvailableOrders();
    if (!mounted) return;
    await riderProvider.fetchAssignedOrders();
    if (!mounted) return;
    await riderProvider.fetchEarnings();
    if (!mounted) return;
    await riderProvider.fetchDeliveryHistory();
    if (!mounted) return;
    riderProvider.startAutoRefresh(_pollSeconds);

    if (riderId != null) {
      await context.read<PickupOrderProvider>().fetchRiderPickupOrders(riderId);
      if (!mounted) return;
      await context.read<PickupOrderProvider>().fetchAvailablePickupOrders();
    }
    if (!mounted) return;
    context.read<NotificationProvider>().initialize(pollingInterval: _pollSeconds);
  }

  @override
  void dispose() {
    _orderTabController.dispose();
    try {
      context.read<RiderOrderProvider>().stopAutoRefresh();
      context.read<NotificationProvider>().stopPolling();
    } catch (_) {}
    super.dispose();
  }

  void _toggleOnlineStatus(bool val) {
    setState(() => _isOnline = val);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: val ? Colors.white : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(val ? 'You are now online' : 'You are now offline',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
          ]),
          backgroundColor: val ? const Color(0xFF22C55E) : const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    if (val) {
      final np = context.read<NotificationProvider>();
      if (!np.isPolling) np.startPolling(intervalSeconds: _pollSeconds);
    }
  }

  Future<void> _callSupport(BuildContext ctx) async {
    final uri = Uri(scheme: 'tel', path: supportPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  SnackBar _buildSnackBar(String message, {bool isError = false}) {
    return SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      backgroundColor: isError ? Colors.red : const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    );
  }

  Future<bool> _confirmAction(
    BuildContext ctx, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black)),
        content: Text(message,
            style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // â”€â”€â”€ BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final orderProvider = context.watch<RiderOrderProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final isDark = themeProvider.isDarkMode;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black)),
      );
    }

    if (!authProvider.isRider) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return Scaffold(
        backgroundColor: bg,
        body: Center(
            child: Text('Rider access only',
                style: TextStyle(color: isDark ? Colors.white : Colors.black))),
      );
    }

    final riderName = authProvider.user?.firstName?.trim().isNotEmpty == true
        ? authProvider.user!.firstName!.trim()
        : 'Rider';

    // â”€â”€â”€ HOME TAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final homeTab = CustomScrollView(
      slivers: [
        // Compact Header
        SliverToBoxAdapter(
          child: Container(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.black,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        riderName,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: _isOnline ? const Color(0xFF22C55E) : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ],
                  ),
                ),
                _buildOnlinePill(isDark),
                const SizedBox(width: 8),
                _buildHeaderIcon(
                  icon: Icons.notifications,
                  badge: notificationProvider.unreadCount,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderNotificationsScreen())),
                ),
              ],
            ),
          ),
        ),

        // Dashboard Content
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverToBoxAdapter(
            child: orderProvider.isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : Colors.black, strokeWidth: 2),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTodayStats(orderProvider, isDark),
                      const SizedBox(height: 16),
                      _buildStatusGrid(orderProvider, isDark),
                      const SizedBox(height: 24),
                      if (_isOnline) ...[
                        _buildAvailableOrders(context, orderProvider, isDark),
                        const SizedBox(height: 24),
                        _buildAvailablePickups(context, isDark),
                        const SizedBox(height: 24),
                      ],
                      _buildActiveOrders(orderProvider, isDark, context),
                      const SizedBox(height: 24),
                      _buildPickupOrders(context, isDark),
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ),
      ],
    );

    // â”€â”€â”€ SCREENS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final screens = [
      homeTab,
      _RiderOrdersTab(
        tabController: _orderTabController,
        onAccept: (o) => _handleAccept(orderProvider, o),
        onDecline: (o) => _handleDecline(orderProvider, o),
      ),
      const RiderDeliveryHistory(),
      const RiderProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitDialog(context, isDark);
      },
      child: Scaffold(
        backgroundColor: bg,
        body: IndexedStack(index: _selectedIndex, children: screens),
        floatingActionButton: _selectedIndex == 0 ? _buildGoOnlineButton(isDark) : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: bg,
            selectedItemColor: isDark ? Colors.white : Colors.black,
            unselectedItemColor: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                activeIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle_outlined),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ HEADER WIDGETS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHeaderIcon({
    required IconData icon,
    int? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, color: Colors.white, size: 20)),
            if (badge != null && badge > 0)
              Positioned(
                right: -4, top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badge > 9 ? '9+' : badge.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlinePill(bool isDark) {
    final green = const Color(0xFF22C55E);
    return GestureDetector(
      onTap: () => _toggleOnlineStatus(!_isOnline),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isOnline ? green.withOpacity(0.15) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isOnline ? green : Colors.white.withOpacity(0.15), width: 1.2,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: _isOnline ? green : Colors.grey,
              shape: BoxShape.circle,
              boxShadow: _isOnline
                  ? [BoxShadow(color: green.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _isOnline ? green : Colors.white70,
            ),
          ),
        ]),
      ),
    );
  }

  // â”€â”€â”€ GO ONLINE BUTTON â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildGoOnlineButton(bool isDark) {
    const green = Color(0xFF22C55E);
    final isOn = _isOnline;
    return GestureDetector(
      onTap: () => _toggleOnlineStatus(!_isOnline),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        width: isOn ? 160 : 180,
        height: 56,
        decoration: BoxDecoration(
          gradient: isOn
              ? const LinearGradient(
                  colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (isOn ? Colors.black : green).withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isOn ? Colors.red[400] : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isOn ? Colors.red : Colors.white).withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isOn ? 'Go Offline' : 'Go Online',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ TODAY STATS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTodayStats(RiderOrderProvider p, bool isDark) {
    final s = _todaySummary(p);
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 2),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8)),
          boxShadow: isDark ? null : [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY\'S DELIVERIES',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${s['deliveries']}',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 36, fontWeight: FontWeight.w900, height: 1, letterSpacing: -2,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios,
              color: isDark ? Colors.grey[600] : Colors.grey[400], size: 18),
        ]),
      ),
    );
  }

  // â”€â”€â”€ STATUS GRID â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStatusGrid(RiderOrderProvider p, bool isDark) {
    final s = _todaySummary(p);
    return Column(children: [
      Row(children: [
        Expanded(child: _buildStatusCard(s['available'] as int, 'Available', Colors.orange, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatusCard(s['active'] as int, 'Active', Colors.blue, isDark)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _buildStatusCard(s['deliveries'] as int, 'Completed', Colors.green, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildEarningsCard(s['earnings'] as double, isDark)),
      ]),
    ]);
  }

  Widget _buildStatusCard(int count, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8)),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label.toUpperCase(),
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        Text('$count',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1, letterSpacing: -1, color: isDark ? Colors.white : Colors.black)),
      ]),
    );
  }

  Widget _buildEarningsCard(double earnings, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('EARNINGS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        Text('RWF ${earnings.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1, letterSpacing: -0.5, color: Colors.white)),
      ]),
    );
  }

  // â”€â”€â”€ QUICK ACTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildQuickActions(bool isDark) {
    final card = isDark ? const Color(0xFF252525) : Colors.white;
    final border = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final text = isDark ? Colors.white : Colors.black;
    return Row(children: [
      Expanded(
        child: _buildActionTile(Icons.support_agent, 'Support', card, border, text, () => _callSupport(context)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _buildActionTile(Icons.account_balance_wallet, 'Earnings', card, border, text, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderEarningsScreen()));
        }),
      ),
    ]);
  }

  Widget _buildActionTile(IconData icon, String label, Color card, Color border, Color text, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(children: [
            Icon(icon, color: text, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text))),
            Icon(Icons.arrow_forward_ios, size: 12, color: text),
          ]),
        ),
      ),
    );
  }

  // â”€â”€â”€ AVAILABLE ORDERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildAvailableOrders(BuildContext ctx, RiderOrderProvider p, bool isDark) {
    final orders = _sortByPriority(p.availableOrders);
    final display = orders.take(5).toList();
    final hasMore = orders.length > 5;
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final card = isDark ? const Color(0xFF252525) : Colors.white;
    final border = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Available Orders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.5)),
        const SizedBox(width: 8),
        _badge('${orders.length}'),
        const Spacer(),
        if (hasMore)
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 1),
            child: const Text('View All',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF22C55E))),
          ),
      ]),
      const SizedBox(height: 12),
      if (orders.isEmpty)
        _buildEmpty(Icons.inbox, 'No Available Orders', 'New delivery requests will appear here', isDark)
      else
        ...display.map((o) => _buildAvailableCard(ctx, o, p, isDark, text, sub, card, border)),
    ]);
  }

  Widget _buildAvailableCard(
    BuildContext ctx, Order order, RiderOrderProvider p,
    bool isDark, Color text, Color sub, Color card, Color border,
  ) {
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => RiderOrderDetailScreen(order: order))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _vendorIcon(order, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.vendorName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('RWF ${order.total.toStringAsFixed(0)} Â· ${order.items.length} item${order.items.length != 1 ? "s" : ""}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sub)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(order.statusDisplay.toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF22C55E), letterSpacing: 0.5)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _handleDecline(p, order),
                style: OutlinedButton.styleFrom(
                  foregroundColor: text,
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleAccept(p, order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // â”€â”€â”€ ACTIVE ORDERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildActiveOrders(RiderOrderProvider p, bool isDark, BuildContext ctx) {
    final orders = p.orders;
    if (orders.isEmpty) return const SizedBox.shrink();
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final card = isDark ? const Color(0xFF252525) : Colors.white;
    final border = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Active Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.5)),
        _badge('${orders.length}'),
      ]),
      const SizedBox(height: 12),
      ...orders.map((o) => _buildActiveCard(o, isDark, text, sub, card, border, ctx)),
    ]);
  }

  Widget _buildActiveCard(Order order, bool isDark, Color text, Color sub, Color card, Color border, BuildContext ctx) {
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    Color statusColor = Colors.orange;
    if (order.status == OrderStatus.ready) statusColor = Colors.green;
    if (order.status == OrderStatus.pickedUp) statusColor = const Color(0xFF3B82F6);
    return InkWell(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => RiderOrderDetailScreen(order: order))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          _vendorIcon(order, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.vendorName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text('RWF ${order.total.toStringAsFixed(0)} Â· ${order.items?.length ?? 0} item${(order.items?.length ?? 0) != 1 ? "s" : ""}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sub)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(order.statusDisplay.toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5)),
          ),
        ]),
      ),
    );
  }

  // â”€â”€â”€ PICKUP ORDERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildAvailablePickups(BuildContext ctx, bool isDark) {
    final pickupProvider = ctx.watch<PickupOrderProvider>();
    final orders = pickupProvider.availablePickupOrders;
    if (orders.isEmpty) return const SizedBox.shrink();

    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Available Pickups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.5)),
        const SizedBox(width: 8),
        _badge('${orders.length}'),
      ]),
      const SizedBox(height: 12),
      ...orders.take(5).map((o) => _buildAvailablePickupCard(o, isDark, text, sub, ctx)),
    ]);
  }

  Widget _buildAvailablePickupCard(PickupOrder order, bool isDark, Color text, Color sub, BuildContext ctx) {
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF8B5CF6), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pickup #${order.orderNumber}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
              const SizedBox(height: 3),
              Text('RWF ${order.totalAmount.toStringAsFixed(0)} \u00b7 ${order.items.length} item${order.items.length != 1 ? "s" : ""}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sub)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: const Text('PICKUP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6), letterSpacing: 0.5)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleAcceptPickup(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              child: const Text('Accept Pickup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _handleAcceptPickup(PickupOrder order) async {
    final confirmed = await _confirmAction(context, title: 'Accept Pickup', message: 'Accept this pickup delivery?', confirmLabel: 'Accept');
    if (!confirmed) return;
    final provider = context.read<PickupOrderProvider>();
    final ok = await provider.acceptPickupOrder(order.id);
    if (!mounted) return;
    if (ok) {
      final riderId = context.read<AuthProvider>().user?.id;
      if (riderId != null && riderId.isNotEmpty) {
        await provider.fetchRiderPickupOrders(riderId);
      }
      ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar('Pickup order accepted'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(provider.error ?? 'Failed to accept', isError: true));
    }
  }

  Widget _buildPickupOrders(BuildContext ctx, bool isDark) {
    final pickupProvider = ctx.watch<PickupOrderProvider>();
    final orders = pickupProvider.riderAssignedOrders
        .where((o) => o.status != PickupOrderStatus.delivered && o.status != PickupOrderStatus.cancelled)
        .toList();
    if (orders.isEmpty) return const SizedBox.shrink();

    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final border = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Pickup Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text)),
        _badge('${orders.length}'),
      ]),
      const SizedBox(height: 12),
      ...orders.map((o) => _buildPickupCard(o, isDark, text, sub, border, ctx)),
    ]);
  }

  Widget _buildPickupCard(PickupOrder order, bool isDark, Color text, Color sub, Color border, BuildContext ctx) {
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    return InkWell(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => RiderPickupOrderDetailScreen(order: order))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF3B82F6), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pickup #${order.orderNumber}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
                const SizedBox(height: 3),
                Text('RWF ${order.totalAmount.toStringAsFixed(0)} \u00b7 ${order.items.length} item${order.items.length != 1 ? "s" : ""}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sub)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.15), borderRadius: BorderRadius.circular(8),
              ),
              child: Text(order.statusDisplay.toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
            ),
          ]),
          if (order.status == PickupOrderStatus.assignedToRider) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _promptPickupCode(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Enter Pickup Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _promptPickupCode(PickupOrder order) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enter Pickup Code'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number, maxLength: 6,
          decoration: const InputDecoration(hintText: '4-digit code', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty) return;

    final provider = context.read<PickupOrderProvider>();
    final ok = await provider.updateOrderStatus(order.id, PickupOrderStatus.pickedUp, pickupCode: code);
    if (!mounted) return;
    if (ok) {
      final riderId = context.read<AuthProvider>().user?.id;
      if (riderId != null && riderId.isNotEmpty) await provider.fetchRiderPickupOrders(riderId);
      ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar('Pickup confirmed'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(provider.error ?? 'Failed to verify pickup code', isError: true));
    }
  }

  // â”€â”€â”€ SHARED HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF22C55E))),
    );
  }

  Widget _vendorIcon(Order order, {double size = 40}) {
    final isRestaurant = order.vendorName.toLowerCase().contains('restaurant');
    final color = isRestaurant ? const Color(0xFF22C55E) : const Color(0xFF3B82F6);
    final fallback = Icon(isRestaurant ? Icons.restaurant_rounded : Icons.store_rounded, color: color, size: size * 0.5);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: order.vendorLogo != null && order.vendorLogo!.isNotEmpty
          ? Image.network(order.vendorLogo!, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, e, ___) {
                return Container(
                  width: size, height: size,
                  decoration: BoxDecoration(color: color.withOpacity(0.12)),
                  child: Center(child: fallback),
                );
              },
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: size, height: size,
                  decoration: BoxDecoration(color: color.withOpacity(0.12)),
                  child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))),
                );
              },
            )
          : Container(
              width: size, height: size,
              decoration: BoxDecoration(color: color.withOpacity(0.12)),
              child: Center(child: fallback),
            ),
    );
  }

  Widget _buildEmpty(IconData icon, String title, String message, bool isDark) {
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: const Color(0xFF22C55E)),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 6),
          Text(message,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF6B7280)),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Map<String, dynamic> _todaySummary(RiderOrderProvider p) {
    final now = nowInRwanda();
    final today = p.deliveryHistory.where((o) {
      final c = o.completedAt;
      if (c == null) return false;
      final rw = toRwandaTime(c);
      return rw.year == now.year && rw.month == now.month && rw.day == now.day;
    }).toList();
    final earnings = today.fold<double>(0, (s, o) => s + (o.deliveryFee > 0 ? o.deliveryFee : o.total));
    return {
      'earnings': earnings,
      'deliveries': today.length,
      'available': p.availableOrders.length,
      'active': p.orders.length,
    };
  }

  List<Order> _sortByPriority(List<Order> orders) {
    final sorted = List<Order>.from(orders);
    sorted.sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at != null && bt != null) {
        final c = at.compareTo(bt);
        if (c != 0) return c;
      }
      return b.total.compareTo(a.total);
    });
    return sorted;
  }

  // â”€â”€â”€ ORDER ACTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _handleAccept(RiderOrderProvider p, Order order) async {
    if (order.id == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar('Order ID missing', isError: true));
      return;
    }
    final confirmed = await _confirmAction(context, title: 'Accept Order', message: 'Accept this delivery?', confirmLabel: 'Accept');
    if (!confirmed) return;
    final ok = await p.acceptOrder(order.id!);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(ok ? 'Order accepted' : 'Accept failed', isError: !ok));
  }

  Future<void> _handleDecline(RiderOrderProvider p, Order order) async {
    if (order.id == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar('Order ID missing', isError: true));
      return;
    }
    final confirmed = await _confirmAction(context, title: 'Decline Order', message: 'Decline this order?', confirmLabel: 'Decline');
    if (!confirmed) return;
    final ok = await p.rejectOrder(order.id!);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(ok ? 'Order declined' : 'Decline failed', isError: !ok));
  }

  // â”€â”€â”€ EXIT DIALOG â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showExitDialog(BuildContext ctx, bool isDark) async {
    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.logout_rounded, color: Color(0xFF22C55E), size: 22),
          ),
          const SizedBox(width: 12),
          Text('Exit App?', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        content: Text('Choose what you want to do.',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))),
          TextButton(
            onPressed: () async {
              Navigator.pop(c, false);
              final auth = context.read<AuthProvider>();
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (result == true) SystemNavigator.pop();
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  RIDER ORDERS TAB â€” mimics VendorOrdersTab with search + 4 TabBar filters
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _RiderOrdersTab extends StatefulWidget {
  final TabController tabController;
  final Future<void> Function(Order) onAccept;
  final Future<void> Function(Order) onDecline;

  const _RiderOrdersTab({
    required this.tabController,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_RiderOrdersTab> createState() => _RiderOrdersTabState();
}

class _RiderOrdersTabState extends State<_RiderOrdersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final border = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return SafeArea(
      child: Column(children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            Text('Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: text)),
          ]),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: TextStyle(color: text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search vendor or location...',
              hintStyle: TextStyle(color: sub, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: sub, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: isDark ? const Color(0xFF252525) : const Color(0xFFF3F4F6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        // TabBar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252525) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: widget.tabController,
            indicator: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: isDark ? Colors.black : Colors.white,
            unselectedLabelColor: sub,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Available'),
              Tab(text: 'Active'),
              Tab(text: 'Pickup'),
              Tab(text: 'Done'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: widget.tabController,
            children: [
              _AvailableOrdersList(query: _searchQuery, onAccept: widget.onAccept, onDecline: widget.onDecline),
              _ActiveOrdersList(query: _searchQuery),
              _PickupOrdersList(query: _searchQuery),
              _CompletedOrdersList(query: _searchQuery),
            ],
          ),
        ),
      ]),
    );
  }
}

// â”€â”€â”€ Available Orders List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AvailableOrdersList extends StatelessWidget {
  final String query;
  final Future<void> Function(Order) onAccept;
  final Future<void> Function(Order) onDecline;
  const _AvailableOrdersList({required this.query, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<RiderOrderProvider>();
    final orders = _filter(p.availableOrders, query);

    if (p.isLoading) return _loader(isDark);
    if (orders.isEmpty) return _emptyList('No available orders', isDark);

    return RefreshIndicator(
      onRefresh: () => p.fetchAvailableOrders(),
      color: isDark ? Colors.white : Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        itemCount: orders.length,
        itemBuilder: (ctx, i) {
          final o = orders[i];
          return _OrderCard(order: o, showActions: true, onAccept: () => onAccept(o), onDecline: () => onDecline(o));
        },
      ),
    );
  }
}

// â”€â”€â”€ Active Orders List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActiveOrdersList extends StatelessWidget {
  final String query;
  const _ActiveOrdersList({required this.query});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<RiderOrderProvider>();
    final orders = _filter(p.orders, query);

    if (p.isLoading) return _loader(isDark);
    if (orders.isEmpty) return _emptyList('No active orders', isDark);

    return RefreshIndicator(
      onRefresh: () => p.fetchAssignedOrders(),
      color: isDark ? Colors.white : Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        itemCount: orders.length,
        itemBuilder: (ctx, i) => _OrderCard(order: orders[i]),
      ),
    );
  }
}

// â”€â”€â”€ Pickup Orders List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PickupOrdersList extends StatelessWidget {
  final String query;
  const _PickupOrdersList({required this.query});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pp = context.watch<PickupOrderProvider>();
    var assignedOrders = pp.riderAssignedOrders;
    var availableOrders = pp.availablePickupOrders;
    if (query.isNotEmpty) {
      assignedOrders = assignedOrders.where((o) =>
        o.orderNumber.toLowerCase().contains(query) ||
        o.pickupLocation.address.toLowerCase().contains(query)
      ).toList();
      availableOrders = availableOrders.where((o) =>
        o.orderNumber.toLowerCase().contains(query) ||
        o.pickupLocation.address.toLowerCase().contains(query)
      ).toList();
    }

    if (assignedOrders.isEmpty && availableOrders.isEmpty) return _emptyList('No pickup orders', isDark);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      children: [
        if (availableOrders.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Available Pickups', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
          ),
          ...availableOrders.map((o) => _PickupCard(order: o, showAccept: true)),
        ],
        if (assignedOrders.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(top: availableOrders.isNotEmpty ? 16 : 0, bottom: 8),
            child: Text('My Pickups', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
          ),
          ...assignedOrders.map((o) => _PickupCard(order: o)),
        ],
      ],
    );
  }
}

// â”€â”€â”€ Completed Orders List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CompletedOrdersList extends StatelessWidget {
  final String query;
  const _CompletedOrdersList({required this.query});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<RiderOrderProvider>();
    final orders = _filter(p.deliveryHistory, query);

    if (p.isLoadingHistory) return _loader(isDark);
    if (orders.isEmpty) return _emptyList('No completed deliveries', isDark);

    return RefreshIndicator(
      onRefresh: () => p.fetchDeliveryHistory(),
      color: isDark ? Colors.white : Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        itemCount: orders.length,
        itemBuilder: (ctx, i) => _OrderCard(order: orders[i]),
      ),
    );
  }
}

// â”€â”€â”€ Shared Order Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool showActions;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _OrderCard({required this.order, this.showActions = false, this.onAccept, this.onDecline});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    Color statusColor = Colors.orange;
    if (order.status == OrderStatus.preparing) statusColor = Colors.blue;
    if (order.status == OrderStatus.ready) statusColor = Colors.green;
    if (order.status == OrderStatus.completed) statusColor = Colors.grey;

    final isRestaurant = order.vendorName.toLowerCase().contains('restaurant');
    final iconColor = isRestaurant ? const Color(0xFF22C55E) : const Color(0xFF3B82F6);
    final fallbackIcon = Icon(isRestaurant ? Icons.restaurant_rounded : Icons.store_rounded, color: iconColor, size: 22);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RiderOrderDetailScreen(order: order))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: order.vendorLogo != null && order.vendorLogo!.isNotEmpty
                  ? Image.network(order.vendorLogo!, width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: iconColor.withOpacity(0.12)),
                        child: Center(child: fallbackIcon),
                      ))
                  : Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: iconColor.withOpacity(0.12)),
                      child: Center(child: fallbackIcon),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.vendorName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: text), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('RWF ${order.total.toStringAsFixed(0)} \u00b7 ${order.items.length} item${order.items.length != 1 ? "s" : ""}',
                    style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(order.statusDisplay.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          ]),
          if (showActions) ...[            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: text, side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// â”€â”€â”€ Shared Pickup Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PickupCard extends StatelessWidget {
  final PickupOrder order;
  final bool showAccept;
  const _PickupCard({required this.order, this.showAccept = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final badgeColor = showAccept ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6);

    return GestureDetector(
      onTap: showAccept ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RiderPickupOrderDetailScreen(order: order))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: badgeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.local_shipping_rounded, color: badgeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pickup #${order.orderNumber}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: text), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('RWF ${order.totalAmount.toStringAsFixed(0)} \u00b7 ${order.items.length} item${order.items.length != 1 ? "s" : ""}',
                    style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(showAccept ? 'AVAILABLE' : order.statusDisplay.toUpperCase(),
                  style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          ]),
          if (showAccept) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final provider = context.read<PickupOrderProvider>();
                  final ok = await provider.acceptPickupOrder(order.id);
                  if (context.mounted) {
                    if (ok) {
                      final auth = context.read<AuthProvider>();
                      final riderId = auth.user?.id;
                      if (riderId != null && riderId.isNotEmpty) {
                        await provider.fetchRiderPickupOrders(riderId);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pickup order accepted'), backgroundColor: Color(0xFF22C55E)),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(provider.error ?? 'Failed to accept'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: const Text('Accept Pickup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// â”€â”€â”€ Tab Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

List<Order> _filter(List<Order> orders, String query) {
  if (query.isEmpty) return orders;
  return orders.where((o) =>
    o.vendorName.toLowerCase().contains(query) ||
    (o.deliveryInfo?.address ?? '').toLowerCase().contains(query) ||
    (o.orderNumber ?? '').toLowerCase().contains(query)
  ).toList();
}

Widget _loader(bool isDark) {
  return Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black, strokeWidth: 2));
}

Widget _emptyList(String message, bool isDark) {
  return Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_rounded, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[300]),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w600)),
    ]),
  );
}
