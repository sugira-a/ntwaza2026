// lib/screens/admin/admin_main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/notification_service.dart';
import 'admin_dashboard_home.dart';
import 'admin_orders_screen.dart';
import 'admin_finance_screen.dart';
import 'admin_users_screen.dart';
import 'admin_profile_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  static const int _pollSeconds = 30;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null || authProvider.user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final notifProvider = context.read<NotificationProvider>();
      await notifProvider.initialize(pollingInterval: _pollSeconds);

      final notifService = NotificationService();
      await notifService.initialize();

      await context.read<AdminOrderProvider>().initialize(
            autoRefreshSeconds: _pollSeconds,
          );
    } catch (e) {
      debugPrint('Admin init error: $e');
      if (e.toString().contains('401') && mounted) {
        context.read<AuthProvider>().logout();
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    try {
      context.read<NotificationProvider>().stopPolling();
      context.read<AdminOrderProvider>().stopAutoRefresh();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black),
        ),
      );
    }

    if (!authProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Text('Admin access only',
              style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        ),
      );
    }

    final screens = const [
      AdminDashboardHome(),
      AdminOrdersScreen(),
      AdminFinanceScreen(),
      AdminUsersScreen(),
      AdminProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitConfirmation(context, isDark);
      },
      child: Scaffold(
        backgroundColor: bg,
        body: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
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
                icon: Icon(Icons.dashboard_rounded),
                activeIcon: Icon(Icons.dashboard_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Finance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people_rounded),
                label: 'Users',
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

  Future<void> _showExitConfirmation(BuildContext context, bool isDark) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFF22C55E), size: 22),
            ),
            const SizedBox(width: 12),
            Text('Exit App?',
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
          ],
        ),
        content: Text('Are you sure you want to exit NTWAZA?',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[600], fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Exit', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == true) {
      SystemNavigator.pop();
    }
  }
}
