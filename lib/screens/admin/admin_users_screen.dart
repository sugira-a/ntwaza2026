// lib/screens/admin/admin_users_screen.dart
// Professional admin users management - vendors, riders, customers
// Matches rider/vendor screen patterns exactly

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_dashboard_service.dart';
import 'admin_riders_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _riders = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final service = AdminDashboardService(context.read<AuthProvider>().apiService);
      
      // Load all data with proper error handling
      Map<String, dynamic> vendorsResult = {'vendors': []};
      Map<String, dynamic> ridersResult = {'riders': []};
      Map<String, dynamic> customersResult = {'customers': []};
      
      try {
        vendorsResult = await service.getVendors(perPage: 100);
        print('✅ Loaded ${vendorsResult['vendors']?.length ?? 0} vendors');
      } catch (e) {
        print('❌ Error loading vendors: $e');
      }
      
      try {
        ridersResult = await service.getRiders(perPage: 100);
        print('✅ Loaded ${ridersResult['riders']?.length ?? 0} riders');
      } catch (e) {
        print('❌ Error loading riders: $e');
      }
      
      try {
        customersResult = await service.getCustomers(perPage: 100);
        print('✅ Loaded ${customersResult['customers']?.length ?? 0} customers');
      } catch (e) {
        print('❌ Error loading customers: $e');
      }
      
      if (mounted) {
        setState(() {
          _vendors = List<Map<String, dynamic>>.from(vendorsResult['vendors'] ?? []);
          _riders = List<Map<String, dynamic>>.from(ridersResult['riders'] ?? []);
          _customers = List<Map<String, dynamic>>.from(customersResult['customers'] ?? []);
          _isLoading = false;
        });
        print('📊 Users loaded - Vendors: ${_vendors.length}, Riders: ${_riders.length}, Customers: ${_customers.length}');
      }
    } catch (e) {
      print('❌ Critical error loading users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> items) {
    if (_searchQuery.isEmpty) return items;
    return items.where((item) {
      final name = (item['name'] ?? item['business_name'] ?? '').toString().toLowerCase();
      final email = (item['email'] ?? '').toString().toLowerCase();
      final phone = (item['phone'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          phone.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Header
          Container(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.black,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Users',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : Colors.white)),
                      ),
                      _buildHeaderIcon(Icons.person_add_rounded, () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AdminRidersScreen()));
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Tabs
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF22C55E),
                  indicatorWeight: 2.5,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[500],
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: [
                    Tab(text: 'Vendors (${_vendors.length})'),
                    Tab(text: 'Riders (${_riders.length})'),
                    Tab(text: 'Customers (${_customers.length})'),
                  ],
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVendorList(isDark, text, sub, bg),
                      _buildRiderList(isDark, text, sub, bg),
                      _buildCustomerList(isDark, text, sub, bg),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }

  // ── Vendor List ──────────────────────────────────────────────

  Widget _buildVendorList(bool isDark, Color text, Color sub, Color bg) {
    final vendors = _filter(_vendors);
    if (vendors.isEmpty) return _buildEmptyState('No vendors found', isDark);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF22C55E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vendors.length,
        itemBuilder: (context, i) {
          final v = vendors[i];
          final name = v['business_name'] ?? v['name'] ?? 'Unknown';
          final email = v['email'] ?? '';
          final status = v['status'] ?? 'pending';
          final isApproved = status == 'approved' || status == 'active';
          final ordersCount = v['total_orders'] ?? 0;

          return _buildUserCard(
            isDark: isDark,
            icon: Icons.store_rounded,
            iconColor: const Color(0xFF6366F1),
            name: name.toString(),
            subtitle: email.toString(),
            badge: isApproved ? 'Active' : status.toString().toUpperCase(),
            badgeColor: isApproved ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
            trailing: '$ordersCount orders',
            trailingColor: sub,
            onTap: () => _showUserDetail(v, 'vendor', isDark),
          );
        },
      ),
    );
  }

  // ── Rider List ──────────────────────────────────────────────

  Widget _buildRiderList(bool isDark, Color text, Color sub, Color bg) {
    final riders = _filter(_riders);
    if (riders.isEmpty) return _buildEmptyState('No riders found', isDark);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF22C55E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: riders.length,
        itemBuilder: (context, i) {
          final r = riders[i];
          final name = r['name'] ?? 'Unknown';
          final email = r['email'] ?? '';
          final status = r['status'] ?? 'pending';
          final isApproved = status == 'approved' || status == 'active';
          final deliveries = r['total_deliveries'] ?? 0;

          return _buildUserCard(
            isDark: isDark,
            icon: Icons.two_wheeler_rounded,
            iconColor: const Color(0xFF06B6D4),
            name: name.toString(),
            subtitle: email.toString(),
            badge: isApproved ? 'Active' : status.toString().toUpperCase(),
            badgeColor: isApproved ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
            trailing: '$deliveries deliveries',
            trailingColor: sub,
            onTap: () => _showUserDetail(r, 'rider', isDark),
          );
        },
      ),
    );
  }

  // ── Customer List ──────────────────────────────────────────

  Widget _buildCustomerList(bool isDark, Color text, Color sub, Color bg) {
    final customers = _filter(_customers);
    if (customers.isEmpty) return _buildEmptyState('No customers found', isDark);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF22C55E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: customers.length,
        itemBuilder: (context, i) {
          final c = customers[i];
          final name = c['name'] ?? c['first_name'] ?? 'Unknown';
          final email = c['email'] ?? '';
          final orders = c['total_orders'] ?? 0;

          return _buildUserCard(
            isDark: isDark,
            icon: Icons.person_rounded,
            iconColor: const Color(0xFF3B82F6),
            name: name.toString(),
            subtitle: email.toString(),
            badge: null,
            badgeColor: Colors.transparent,
            trailing: '$orders orders',
            trailingColor: sub,
            onTap: () => _showUserDetail(c, 'customer', isDark),
          );
        },
      ),
    );
  }

  // ── Shared Card ──────────────────────────────────────────────

  Widget _buildUserCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String name,
    required String subtitle,
    required String? badge,
    required Color badgeColor,
    required String trailing,
    required Color trailingColor,
    required VoidCallback onTap,
  }) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8);
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.white60 : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor)),
                  ),
                const SizedBox(height: 4),
                Text(trailing,
                    style: TextStyle(fontSize: 10, color: trailingColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetail(Map<String, dynamic> user, String role, bool isDark) {
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final name = user['business_name'] ?? user['name'] ?? user['first_name'] ?? 'Unknown';
        final email = user['email'] ?? 'N/A';
        final phone = user['phone'] ?? 'N/A';
        final createdAt = user['created_at'] ?? '';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      role == 'vendor'
                          ? Icons.store_rounded
                          : role == 'rider'
                              ? Icons.two_wheeler_rounded
                              : Icons.person_rounded,
                      color: const Color(0xFF22C55E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.toString(),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: text,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 2),
                        Text(role.toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF22C55E),
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow(Icons.email_outlined, 'Email', email.toString(), text, sub),
              _detailRow(Icons.phone_outlined, 'Phone', phone.toString(), text, sub),
              if (createdAt.toString().isNotEmpty)
                _detailRow(Icons.calendar_today_outlined, 'Joined', createdAt.toString().split('T').first, text, sub),
              if (role == 'vendor') ...[
                _detailRow(Icons.receipt_long, 'Orders', '${user['total_orders'] ?? 0}', text, sub),
                _detailRow(Icons.star_rounded, 'Rating', '${user['rating'] ?? 'N/A'}', text, sub),
              ],
              if (role == 'rider') ...[
                _detailRow(Icons.local_shipping, 'Deliveries', '${user['total_deliveries'] ?? 0}', text, sub),
                _detailRow(Icons.directions_bike, 'Vehicle', '${user['vehicle'] ?? 'N/A'}', text, sub),
              ],
              if (role == 'customer') ...[
                _detailRow(Icons.shopping_bag, 'Orders', '${user['total_orders'] ?? 0}', text, sub),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: sub),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: sub, fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
