import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api/api_service.dart';
import '../services/notification_service.dart';
import '../models/notification.dart' as models;

class NotificationProvider with ChangeNotifier {
  final ApiService _apiService;
  final NotificationService _notificationService;

  NotificationProvider({
    required ApiService apiService,
    required NotificationService notificationService,
  })  : _apiService = apiService,
        _notificationService = notificationService;

  List<models.Notification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  Timer? _pollingTimer;
  bool _isPolling = false;

  List<models.Notification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPolling => _isPolling;

  Future<void> initialize({int pollingInterval = 30}) async {
    print('🔔 Initializing NotificationProvider...');
    await _notificationService.initialize();
    _notificationService.onNotificationTapped = _handleNotificationTap;
    await _registerFcmToken();
    await fetchNotifications();
    await fetchUnreadCount();
    startPolling(intervalSeconds: pollingInterval);
    print('✅ NotificationProvider initialized');
  }

  void _handleNotificationTap(String? orderId) {
    if (orderId != null) {
      print('👆 Notification tapped, order ID: $orderId');
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      final fcmToken = await _notificationService.getFCMToken();
      if (fcmToken == null) {
        print('⚠️  No FCM token available');
        return;
      }
      print('📤 Registering FCM token with backend...');

      // Preferred: generic user profile endpoint (works for all roles)
      try {
        final response = await _apiService.put('/api/user/profile', {
          'fcm_token': fcmToken,
          'push_enabled': true,
        });
        if (response['user'] != null || response['success'] == true) {
          print('✅ FCM token registered (user profile)');
          return;
        }
      } catch (_) {
        // Fall through to legacy vendor endpoint
      }

      // Legacy: vendor-only endpoint (keep for backwards compatibility)
      final legacy = await _apiService.post('/api/vendor/notifications/fcm-token', {'fcm_token': fcmToken});
      if (legacy['success'] == true) {
        print('✅ FCM token registered (vendor notifications)');
      } else {
        print('⚠️  Failed to register FCM token: ${legacy['error']}');
      }
    } catch (e) {
      print('❌ Error registering FCM token: $e');
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      // Skip polling if no auth token is set
      if ((_apiService.authToken ?? _apiService.token) == null) {
        print('⚠️ Skipping unread count fetch - no auth token');
        return;
      }

      final response = await _apiService.get('/api/notifications/unread-count');
      if (response['success'] == true) {
        _unreadCount = (response['unread_count'] ?? response['count'] ?? 0) as int;
        notifyListeners();
      }
    } catch (e) {
      // If we get a 401 / authorization error, stop polling to avoid spamming
      final err = e.toString().toLowerCase();
      print('❌ Error fetching unread count: $e');
      if (err.contains('401') || err.contains('authorization') || err.contains('invalid token')) {
        print('🛑 Authorization error while polling notifications — stopping polling');
        stopPolling();
      }
    }
  }

  void startPolling({int intervalSeconds = 30}) {
    if (_isPolling) {
      print('🔄 Polling already active');
      return;
    }
    _isPolling = true;
    print('🔄 Starting polling (every $intervalSeconds seconds)...');
    _pollingTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) => _pollNotifications());
    notifyListeners();
  }

  void stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      _isPolling = false;
      print('🛑 Polling stopped');
      notifyListeners();
    }
  }

  Future<void> _pollNotifications() async {
    try {
      // Ensure we have a token before polling
      if ((_apiService.authToken ?? _apiService.token) == null) {
        print('⚠️ Skipping polling cycle - no auth token');
        return;
      }

      final response = await _apiService.get('/api/notifications/unread-count');
      if (response['success'] == true) {
        final newUnreadCount = (response['unread_count'] ?? response['count'] ?? 0) as int;
        if (newUnreadCount > _unreadCount) {
          print('🔔 New notifications detected! ($newUnreadCount)');
          await fetchNotifications();
          _notificationService.showLocalNotification(
            title: 'New Order!',
            body: 'You have ${newUnreadCount - _unreadCount} new order(s)',
          );
        }
        _unreadCount = newUnreadCount;
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ Polling error: $e');
      final err = e.toString().toLowerCase();
      if (err.contains('401') || err.contains('authorization') || err.contains('invalid token')) {
        print('🛑 Polling encountered authorization error — stopping polling');
        stopPolling();
      }
    }
  }

  Future<void> fetchNotifications({bool unreadOnly = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final queryParams = unreadOnly ? '?unread_only=true' : '';
      final response = await _apiService.get('/api/notifications$queryParams');
      if (response['success'] == true) {
        _notifications = (response['notifications'] as List).map((json) => models.Notification.fromJson(json)).toList();
        _unreadCount = (response['unread_count'] ?? 0) as int;
        print('✅ Fetched ${_notifications.length} notifications');
      } else {
        _error = response['error'] ?? 'Failed to fetch notifications';
        print('❌ Error: $_error');
      }
    } catch (e) {
      _error = 'Network error: $e';
      print('❌ Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _apiService.put('/api/notifications/$notificationId/read', {});
      if (response['success'] == true) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          if (_unreadCount > 0) _unreadCount--;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiService.put('/api/notifications/mark-all-read', {});
      if (response['success'] == true) {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        _unreadCount = 0;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error marking all as read: $e');
      return false;
    }
  }

  // Delete single notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await _apiService.delete('/api/notifications/$notificationId');
      if (response['success'] == true) {
        final notification = _notifications.firstWhere((n) => n.id == notificationId);
        if (!notification.isRead && _unreadCount > 0) {
          _unreadCount--;
        }
        _notifications.removeWhere((n) => n.id == notificationId);
        notifyListeners();
        print('✅ Notification deleted');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting notification: $e');
      return false;
    }
  }

  // Clear all read notifications
  Future<bool> clearReadNotifications() async {
    try {
      final response = await _apiService.delete('/api/notifications/clear-read');
      if (response['success'] == true) {
        _notifications.removeWhere((n) => n.isRead);
        notifyListeners();
        print('✅ Read notifications cleared');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error clearing read notifications: $e');
      return false;
    }
  }

  // Clear all notifications
  Future<bool> clearAllNotifications() async {
    try {
      final response = await _apiService.delete('/api/notifications/clear-all');
      if (response['success'] == true) {
        _notifications.clear();
        _unreadCount = 0;
        notifyListeners();
        print('✅ All notifications cleared');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error clearing all notifications: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    await fetchNotifications();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
