import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/notification.dart' as app_models;
import 'vendor_order_detail_screen.dart';

class VendorNotificationsScreen extends StatefulWidget {
  const VendorNotificationsScreen({super.key});

  @override
  State<VendorNotificationsScreen> createState() => _VendorNotificationsScreenState();
}

class _VendorNotificationsScreenState extends State<VendorNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: _buildAppBar(notificationProvider, isDark),
      body: RefreshIndicator(
        onRefresh: () => notificationProvider.fetchNotifications(),
        color: isDark ? Colors.white : Colors.black,
        child: notificationProvider.isLoading
            ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black, strokeWidth: 2))
            : notificationProvider.notifications.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notificationProvider.notifications.length,
                    itemBuilder: (context, index) => _NotificationCard(
                      notification: notificationProvider.notifications[index],
                      isDark: isDark,
                      onTap: () => _handleNotificationTap(notificationProvider.notifications[index]),
                    ),
                  ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(NotificationProvider provider, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? Colors.black : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Notifications', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      actions: [
        if (provider.unreadCount > 0)
          TextButton(
            onPressed: provider.markAllAsRead,
            child: Text('Mark all read', style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.w600)),
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
          color: isDark ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) => value == 'clear_all' ? _showClearDialog(provider, isDark, true) : _showClearDialog(provider, isDark, false),
          itemBuilder: (context) => [
            _buildMenuItem('clear_read', Icons.delete_sweep, 'Clear read', isDark ? Colors.white : Colors.black, isDark),
            _buildMenuItem('clear_all', Icons.delete_outline, 'Clear all', Colors.red, isDark),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String text, Color color, bool isDark) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 12), Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))]),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No notifications yet', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('You\'ll see updates about orders here', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  void _handleNotificationTap(app_models.Notification notification) async {
    if (!notification.isRead) await context.read<NotificationProvider>().markAsRead(notification.id);
    final orderId = notification.data?['order_id'];
    if (orderId != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VendorOrderDetailScreen(orderId: orderId.toString())));
    }
  }

  void _showClearDialog(NotificationProvider provider, bool isDark, bool clearAll) {
    final count = clearAll ? provider.notifications.length : provider.notifications.where((n) => n.isRead).length;
    if (count == 0) {
      if (!clearAll) _showSnackBar('No read notifications to clear', isDark);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(clearAll ? 'Clear All Notifications' : 'Clear Read Notifications', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        content: Text('Delete ${clearAll ? 'all ' : ''}$count notification${count > 1 ? 's' : ''}?${clearAll ? ' This cannot be undone.' : ''}', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              clearAll ? await provider.clearAllNotifications() : await provider.clearReadNotifications();
              if (context.mounted) _showSnackBar(clearAll ? 'All notifications cleared' : 'Cleared $count notification${count > 1 ? 's' : ''}', isDark);
            },
            style: ElevatedButton.styleFrom(backgroundColor: clearAll ? Colors.red : Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(clearAll ? 'Clear All' : 'Clear', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, bool isDark) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isDark ? Colors.grey[800] : Colors.black, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final app_models.Notification notification;
  final bool isDark;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) => _showDeleteDialog(context),
      onDismissed: (direction) async {
        await context.read<NotificationProvider>().deleteNotification(notification.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Notification deleted'), backgroundColor: isDark ? Colors.grey[800] : Colors.black, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 2)),
          );
        }
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? (isUnread ? Colors.grey[850] : Colors.grey[900]) : (isUnread ? Colors.blue.withOpacity(0.05) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isUnread ? (isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.3)) : (isDark ? Colors.grey[800]! : Colors.grey[300]!), width: isUnread ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _getTypeColor(notification.type).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(_getTypeIcon(notification.type), color: _getTypeColor(notification.type), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(notification.title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15, fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600, letterSpacing: -0.3))),
                        if (isUnread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(notification.message, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.timeAgo, style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(notification.formattedTime, style: TextStyle(color: isDark ? Colors.grey[700] : Colors.grey[400], fontSize: 10)),
                          ],
                        ),
                        Text('Swipe to delete', style: TextStyle(color: isDark ? Colors.grey[700] : Colors.grey[400], fontSize: 10, fontStyle: FontStyle.italic)),
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

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Notification', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        content: Text('Are you sure you want to delete this notification?', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'order': return Colors.blue;
      case 'success': return Colors.green;
      case 'warning': return Colors.orange;
      case 'error': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'order': return Icons.receipt_long;
      case 'success': return Icons.check_circle_outline;
      case 'warning': return Icons.warning_amber;
      case 'error': return Icons.error_outline;
      default: return Icons.info_outline;
    }
  }
}