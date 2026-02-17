import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? get _firebaseMessaging =>
      kIsWeb ? null : FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  bool _isInitialized = false;
  Function(String?)? onNotificationTapped;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  
  Future<String?> getFCMToken() async {
    if (kIsWeb) return null;
    if (_fcmToken != null) return _fcmToken;
    _fcmToken = await _firebaseMessaging?.getToken();
    return _fcmToken;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔔 Notification service already initialized');
      return;
    }

    if (kIsWeb) {
      print('⚠️ Notifications not supported on web');
      _isInitialized = true;
      return;
    }

    try {
      print('🔔 Initializing Notification Service...');
      await _initializeLocalNotifications();
      await _initializeFirebaseMessaging();
      _isInitialized = true;
      print('✅ Notification service initialized successfully');
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings, onDidReceiveNotificationResponse: _onNotificationTapped);
    print('✅ Local notifications initialized');
  }

  Future<void> _initializeFirebaseMessaging() async {
    final messaging = _firebaseMessaging;
    if (messaging == null) return;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permission granted');
    } else {
      print('⚠️ Notification permission denied');
    }

    _fcmToken = await messaging.getToken();
    if (_fcmToken != null) {
      print('🔑 FCM Token: $_fcmToken');
    } else {
      print('⚠️ Failed to get FCM token');
    }

    messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('🔄 FCM token refreshed: $newToken');
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }

    print('✅ Firebase messaging initialized');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Foreground message received: ${message.notification?.title}');
    
    // Check if this is a late order warning
    if (message.data['urgency'] == 'high') {
      _showLateWarningDialog(
        message.notification?.title ?? '⚠️ Alert',
        message.notification?.body ?? 'Your order is running late',
      );
    }
    
    if (message.notification != null) {
      showLocalNotification(
        title: message.notification!.title ?? 'New Order',
        body: message.notification!.body ?? 'New Order',
        payload: message.data.toString(),
      );
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('📨 Background message received: ${message.notification?.title}');
    final orderId = message.data['order_id'];
    if (orderId != null) {
      print('📦 Navigate to order: $orderId');
      if (onNotificationTapped != null) {
        onNotificationTapped!(orderId);
      }
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Notification tapped: ${response.payload}');
    if (onNotificationTapped != null) {
      onNotificationTapped!(response.payload);
    }
  }

  void _showLateWarningDialog(String title, String message) {
    print('⚠️ Late warning: $title - $message');
    // This will be called from the app context to show dialog
    // The dialog will be shown via a callback to the current widget context
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    bool isLateWarning = false,
  }) async {
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      isLateWarning ? 'late_orders' : 'vendor_orders',
      isLateWarning ? 'Late Order Warnings' : 'Order Notifications',
      channelDescription: isLateWarning ? 'Warnings for orders running late' : 'Notifications for new orders',
      importance: isLateWarning ? Importance.max : Importance.high,
      priority: isLateWarning ? Priority.max : Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: isLateWarning ? const Color.fromARGB(255, 255, 0, 0) : const Color(0xFF10B981),
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    print('🔔 Local notification shown: $title');
  }

  Future<void> showNewOrderNotification({
    required String orderNumber,
    required String customerName,
    required String orderId,
  }) async {
    await showLocalNotification(
      title: '🛒 New Order #$orderNumber',
      body: 'Order from $customerName',
      payload: orderId,
    );
  }

  Future<void> showLateWarningNotification({
    required String orderNumber,
    required int minutesLate,
  }) async {
    await showLocalNotification(
      title: '⏰ Order Running Late',
      body: 'Order $orderNumber will be ~$minutesLate min late',
      isLateWarning: true,
    );
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _localNotifications.cancelAll();
    print('🔕 All notifications cancelled');
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _localNotifications.cancel(id);
    print('🔕 Notification $id cancelled');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message handler: ${message.notification?.title}');
}