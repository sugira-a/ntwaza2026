// lib/widgets/admin/notifications_panel.dart
// Full-screen notification page for admin (push-navigated)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification.dart' as models;

class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key});

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel>
    with SingleTickerProviderStateMixin {
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF2E7D32);
  static const Color warningRed = Color(0xFFEF4444);

  String _selectedFilter = 'all';
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animController.forward();
    // Refresh notifications on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<models.Notification> _applyFilter(List<models.Notification> all) {
    switch (_selectedFilter) {
      case 'unread':
        return all.where((n) => !n.isRead).toList();
      case 'system':
        return all
            .where((n) =>
                n.type.toLowerCase().contains('system') ||
                n.type.toLowerCase().contains('alert') ||
                n.type.toLowerCase().contains('admin'))
            .toList();
      case 'orders':
        return all
            .where((n) =>
                n.type.toLowerCase().contains('order') ||
                n.type.toLowerCase().contains('delivery') ||
                n.type.toLowerCase().contains('rider'))
            .toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0B) : Colors.white;
    final notifProvider = context.watch<NotificationProvider>();
    final filtered = _applyFilter(notifProvider.notifications);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildHeader(context, isDark, notifProvider),
          _buildFilterTabs(isDark, notifProvider),
          if (notifProvider.isLoading && notifProvider.notifications.isEmpty)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: accentGreen)),
            )
          else if (filtered.isEmpty)
            Expanded(child: _buildEmptyState(isDark))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => notifProvider.fetchNotifications(),
                color: accentGreen,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final notification = filtered[index];
                    return _NotificationCard(
                      notification: notification,
                      isDark: isDark,
                      onMarkRead: () {
                        notifProvider.markAsRead(notification.id);
                      },
                      onDelete: () {
                        notifProvider.deleteNotification(notification.id);
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────
  Widget _buildHeader(
      BuildContext context, bool isDark, NotificationProvider provider) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final unread = provider.unreadCount;

    return Container(
      decoration: const BoxDecoration(color: Colors.black),
      padding: EdgeInsets.only(top: statusBarHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          children: [
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [accentGreen, darkGreen],
                    ).createShader(bounds),
                    child: const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$unread unread',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            if (provider.notifications.isNotEmpty) ...[
              // Mark all read
              if (unread > 0)
                _HeaderAction(
                  icon: Icons.done_all_rounded,
                  tooltip: 'Mark all read',
                  onTap: () async {
                    await provider.markAllAsRead();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All marked as read'),
                          backgroundColor: accentGreen,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              const SizedBox(width: 8),
              // Clear all
              _HeaderAction(
                icon: Icons.delete_sweep_rounded,
                tooltip: 'Clear all',
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor:
                          isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      title: Text('Clear All',
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black)),
                      content: Text(
                          'Delete all notifications? This cannot be undone.',
                          style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Clear All',
                              style: TextStyle(color: warningRed)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await provider.clearAllNotifications();
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            // Close
            _HeaderAction(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter Tabs ──────────────────────────────────────────────────
  Widget _buildFilterTabs(bool isDark, NotificationProvider provider) {
    final unreadCount = provider.unreadCount;
    final orderCount = provider.notifications
        .where((n) =>
            n.type.toLowerCase().contains('order') ||
            n.type.toLowerCase().contains('delivery') ||
            n.type.toLowerCase().contains('rider'))
        .length;

    final filters = <_FilterDef>[
      _FilterDef('all', 'All', null),
      _FilterDef('unread', 'Unread', unreadCount > 0 ? unreadCount : null),
      _FilterDef('system', 'System', null),
      _FilterDef('orders', 'Orders', orderCount > 0 ? orderCount : null),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0B0B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        children: filters
            .map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(f, isDark),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildFilterChip(_FilterDef filter, bool isDark) {
    final isSelected = _selectedFilter == filter.key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [accentGreen, darkGreen])
              : null,
          color: isSelected
              ? null
              : (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filter.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
            if (filter.count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${filter.count}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : accentGreen,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    final isFiltered = _selectedFilter != 'all';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: accentGreen.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFiltered
                  ? Icons.filter_list_off_rounded
                  : Icons.notifications_off_rounded,
              size: 56,
              color: accentGreen.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered ? 'No matching notifications' : 'No Notifications',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered ? 'Try a different filter' : 'You\'re all caught up!',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Definition ────────────────────────────────────────────
class _FilterDef {
  final String key;
  final String label;
  final int? count;
  _FilterDef(this.key, this.label, this.count);
}

// ─── Header Action Button ─────────────────────────────────────────
class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Notification Card
// ═══════════════════════════════════════════════════════════════════
class _NotificationCard extends StatelessWidget {
  final models.Notification notification;
  final bool isDark;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onMarkRead,
    required this.onDelete,
  });

  Color _getTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('error') || t.contains('alert') || t.contains('cancel')) {
      return const Color(0xFFEF4444);
    }
    if (t.contains('success') || t.contains('deliver') || t.contains('complet')) {
      return const Color(0xFF4CAF50);
    }
    if (t.contains('warning') || t.contains('late') || t.contains('pending')) {
      return const Color(0xFFF59E0B);
    }
    if (t.contains('order') || t.contains('rider') || t.contains('assign')) {
      return const Color(0xFF3B82F6);
    }
    return const Color(0xFF06B6D4);
  }

  IconData _getTypeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('error') || t.contains('alert')) return Icons.error_outline_rounded;
    if (t.contains('success') || t.contains('deliver') || t.contains('complet')) {
      return Icons.check_circle_outline_rounded;
    }
    if (t.contains('warning') || t.contains('late')) return Icons.warning_amber_rounded;
    if (t.contains('order')) return Icons.receipt_long_rounded;
    if (t.contains('rider') || t.contains('assign')) return Icons.two_wheeler_rounded;
    if (t.contains('system') || t.contains('admin')) return Icons.admin_panel_settings_rounded;
    return Icons.notifications_active_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getTypeColor(notification.type);
    final icon = _getTypeIcon(notification.type);
    final isUnread = !notification.isRead;
    final cardBg = isDark
        ? (isUnread
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.02))
        : (isUnread
            ? const Color(0xFFF0FFF4)
            : Colors.black.withOpacity(0.02));
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.white60 : Colors.black54;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      child: GestureDetector(
        onTap: () {
          if (isUnread) onMarkRead();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? color.withOpacity(0.2)
                  : (isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.06)),
              width: isUnread ? 1 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w500,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtextColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 11, color: subtextColor.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          notification.timeAgo,
                          style: TextStyle(
                            fontSize: 10,
                            color: subtextColor.withOpacity(0.7),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            notification.type.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
