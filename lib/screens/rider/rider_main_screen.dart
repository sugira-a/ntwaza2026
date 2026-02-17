import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_order_provider.dart';
import 'package:go_router/go_router.dart';
import 'rider_dashboard.dart';
import 'rider_earnings_screen.dart';
import 'rider_delivery_history.dart';
import 'rider_profile_screen.dart';

class RiderMainScreen extends StatefulWidget {
  const RiderMainScreen({super.key});

  @override
  State<RiderMainScreen> createState() => _RiderMainScreenState();
}

class _RiderMainScreenState extends State<RiderMainScreen> {
  int _selectedIndex = 0;
  late RiderOrderProvider _riderOrderProvider;

  @override
  void initState() {
    super.initState();
    _riderOrderProvider = context.read<RiderOrderProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
  }

  Future<void> _initializeDashboard() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null || authProvider.user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final riderOrderProvider = context.read<RiderOrderProvider>();
      await riderOrderProvider.fetchAvailableOrders();
      await riderOrderProvider.fetchDeliveryHistory();
    } catch (e) {
      print('❌ Error initializing rider dashboard: $e');
      if (e.toString().contains('401') && mounted) {
        authProvider.logout();
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    try {
      _riderOrderProvider.stopAutoRefresh();
    } catch (e) {
      // Provider already disposed
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFDADDE2),
        body: Center(
          child: CircularProgressIndicator(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }

    if (!authProvider.isRider) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFDADDE2),
        body: Center(
          child: Text(
            'Rider access only',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      );
    }

    final screens = const [
      RiderDashboard(),
      RiderEarningsScreen(),
      RiderDeliveryHistory(),
      RiderProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: const Color(0xFF1F2937),
            height: 64,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Colors.white);
              }
              return const IconThemeData(color: Color(0xFF9CA3AF));
            }),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, color: Colors.transparent),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Wallet',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
