// lib/widgets/admin/notifications_panel.dart
// Modern Notification Screen with Creative Design
// Shows all notifications with actions, animations, and theme support

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';

class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key});

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  String _selectedFilter = 'all'; // all, unread, system, orders

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final notifProvider = context.watch<NotificationProvider>();

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [const Color(0xFF0B0B0B), const Color(0xFF1A1A1A)]
                : [const Color(0xFFFFFFFF), const Color(0xFFFAFAFA)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Close Button
              _buildHeader(context, isDarkMode),

              // Filter Tabs
              _buildFilterTabs(isDarkMode),

              // Notifications List
              Expanded(
                child: notifProvider.notifications.isEmpty
                    ? _buildEmptyState(isDarkMode)
                    : _buildNotificationsList(context, notifProvider, isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      const Color(0xFF4CAF50),
                      const Color(0xFF2E7D32),
                    ],
                  ).createShader(bounds);
                },
                child: const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close_rounded,
                color: const Color(0xFF4CAF50),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isDarkMode) {
    final filters = [
      ('all', 'All'),
      ('unread', 'Unread'),
      ('system', 'System'),
      ('orders', 'Orders'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ...filters.map((filter) {
            final isSelected = _selectedFilter == filter.$1;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF4CAF50),
                            Color(0xFF2E7D32),
                          ],
                        )
                      : null,
                  color: !isSelected
                      ? isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                ),
                child: Text(
                  filter.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(BuildContext context,
      NotificationProvider notifProvider, bool isDarkMode) {
    // Filter notifications based on selected tab
    List notifications = notifProvider.notifications;
    
    switch (_selectedFilter) {
      case 'unread':
        notifications = notifications
            .where((n) => n.isRead == false || n.isRead == null)
            .toList();
        break;
      case 'system':
        notifications = notifications
            .where((n) => (n.type ?? '').toLowerCase().contains('system') || 
                          (n.type ?? '').toLowerCase().contains('alert'))
            .toList();
        break;
      case 'orders':
        notifications = notifications
            .where((n) => (n.type ?? '').toLowerCase().contains('order'))
            .toList();
        break;
      case 'all':
      default:
        break;
    }

    if (notifications.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _NotificationCard(
            notification: notification,
            isDarkMode: isDarkMode,
            onDismiss: () {
              // Mark as read or delete notification
              notifProvider.markAsRead(notification.id);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 64,
              color: const Color(0xFF4CAF50).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are all caught up!',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// Individual Notification Card Component
class _NotificationCard extends StatefulWidget {
  final dynamic notification;
  final bool isDarkMode;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.isDarkMode,
    required this.onDismiss,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Color _getTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'error':
      case 'alert':
        return const Color(0xFFEF4444);
      case 'success':
      case 'delivered':
        return const Color(0xFF4CAF50);
      case 'warning':
      case 'pending':
        return const Color(0xFFFBBC04);
      case 'info':
      case 'order':
      default:
        return const Color(0xFF4CAF50);
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'error':
      case 'alert':
        return Icons.error_outline_rounded;
      case 'success':
      case 'delivered':
        return Icons.check_circle_outline_rounded;
      case 'warning':
      case 'pending':
        return Icons.warning_amber_rounded;
      case 'info':
      case 'order':
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(widget.notification.type);
    final typeIcon = _getTypeIcon(widget.notification.type);

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)),
      child: Dismissible(
        key: Key(widget.notification.id.toString()),
        onDismissed: (_) => widget.onDismiss(),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.02),
            border: Border.all(
              color: widget.isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.06),
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.notification.title ?? 'Notification',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.notification.message ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDarkMode ? Colors.grey : Colors.grey.shade600,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(widget.notification.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action Button
              GestureDetector(
                onTap: () {
                  // TODO: Handle notification action
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: typeColor,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return 'Just now';
    // TODO: Implement proper time formatting
    return 'Just now';
  }
}
