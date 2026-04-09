import 'dart:async';
import 'package:apnt/models/print_order_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'firestore_service.dart';
// 🛡️ Safe platform abstraction for JS calls
import '../utils/notification_helper.dart' if (dart.library.js) '../utils/notification_helper_web.dart' as web_js;


class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final String type; // success, payment, info, warning
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'time': time.toIso8601String(),
    'type': type,
    'isRead': isRead,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: json['id'],
    title: json['title'],
    body: json['body'],
    time: DateTime.parse(json['time']),
    type: json['type'],
    isRead: json['isRead'] ?? false,
  );
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      if (!kIsWeb) {
        String timeZoneName = (await FlutterTimezone.getLocalTimezone()).toString();
        
        // 🛠️ FIX: Handle cases where platform returns decorated strings like "TimezoneInfo(Asia/Kolkata, ...)"
        if (timeZoneName.contains('(')) {
          final match = RegExp(r'\(([^,)]+)').firstMatch(timeZoneName);
          if (match != null && match.groupCount >= 1) {
            timeZoneName = match.group(1)!;
          }
        }
        
        try {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
        } catch (e) {
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
      }
    } catch (e) {
      try { tz.setLocalLocation(tz.getLocation('UTC')); } catch (_) {}
    }

    await loadNotifications();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    try {
      if (!kIsWeb) {
        await _localNotifications.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (details) {},
        );
      }
      // Request permissions (Unified Web/Mobile)
      await requestPermission();
    } catch (e) {
      debugPrint("Notification Plugin initialization check failed: $e");
    }

    _startExpiryChecker();
    initOrderListeners();
  }

  StreamSubscription? _orderSubscription;
  void initOrderListeners() {
    _orderSubscription?.cancel();
    _orderSubscription = FirestoreService().getActiveOrders().listen((orders) {
      _checkOrdersStatusRealtime(orders);
    });
  }

  void _checkOrdersStatusRealtime(List<PrintOrderModel> orders) {
    for (var order in orders) {
      // 🛡️ 1. Detect COMPLETION (Real-time)
      if (order.status == OrderStatus.completed || order.isPrintingCompleted) {
        final completionKey = 'comp_${order.orderId}';
        if (!_sentAlerts.contains(completionKey)) {
          notifyOrderCompleted(order);
          _sentAlerts.add(completionKey);
        }
        continue;
      }
    }
  }

  Future<void> requestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    int retryCount = prefs.getInt('notification_permission_retries') ?? 0;
    
    // 🛡️ STOP after 3 failed attempts to avoid annoying the user
    if (retryCount >= 3) {
      debugPrint("🔔 Permission Retry Policy: Max attempts (3) reached.");
      return;
    }

    try {
      if (kIsWeb) {
        // 🌐 WEB REQUEST via Safe Abstraction
        final String status = await web_js.getBrowserNotificationStatus();
        if (status != 'granted') {
           debugPrint("🌐 Requesting Web Notification Permission (Attempt ${retryCount + 1})...");
           web_js.triggerBrowserNotificationPermission();
           
           // We'll check again next time or via an event listener if we had JS-to-Dart callbacks
           // For now, optimistic retry count increment if not granted
           await prefs.setInt('notification_permission_retries', retryCount + 1);
        } else {
           await prefs.setInt('notification_permission_retries', 0); // Reset on success
        }
      } else {
        // 📱 MOBILE REQUEST
        PermissionStatus status = await Permission.notification.request();
        
        if (status.isDenied || status.isPermanentlyDenied) {
          debugPrint("📱 Notification Permission Denied (Attempt ${retryCount + 1}).");
          await prefs.setInt('notification_permission_retries', retryCount + 1);
          
          if (retryCount < 2) {
            addNotification(
              title: "Notifications Disabled",
              body: "Enable system notifications to receive order updates.",
              type: "warning",
              showLocal: false
            );
          }
        } else {
          await prefs.setInt('notification_permission_retries', 0); // Reset on success
          if (defaultTargetPlatform == TargetPlatform.android) {
            if (await Permission.scheduleExactAlarm.isDenied) {
              await Permission.scheduleExactAlarm.request();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error requesting notification permission: $e");
    }
  }

  Future<void> addNotification({
    required String title,
    required String body,
    required String type,
    bool showLocal = true,
  }) async {
    final newItem = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      time: DateTime.now(),
      type: type,
    );
    _notifications.insert(0, newItem);
    await saveNotifications();

    if (showLocal && !kIsWeb) {
      await _showSystemNotification(title: title, body: body);
    }

    notifyListeners();
  }

  Future<void> _showSystemNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'thinkink_alerts',
      'ThinkInk Alerts',
      channelDescription: 'Order updates and expiry warnings',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_notifications');
    if (data != null) {
      final List<dynamic> list = jsonDecode(data);
      _notifications.clear();
      _notifications.addAll(list.map((e) => NotificationItem.fromJson(e)).toList());
      notifyListeners();
    }
  }

  Future<void> saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_notifications.map((e) => e.toJson()).toList());
    await prefs.setString('user_notifications', data);
  }

  void markAsRead() {
    for (var n in _notifications) { n.isRead = true; }
    saveNotifications();
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    saveNotifications();
    notifyListeners();
  }

  void notifyOrderCompleted(PrintOrderModel order) {
    final String orderNum = (order.customId ?? order.orderId).toLowerCase().replaceFirst('order_', '');
    
    addNotification(
      title: 'Greetings! Print Complete! 🎉',
      body: 'the printing of order $orderNum is completed so collect your prints at your shop',
      type: 'success',
    );

    // 🛡️ Cancel any scheduled expiry alerts for this order
    _cancelExpiryAlerts(order.pickupCode);
  }

  Future<void> _cancelExpiryAlerts(String pickupCode) async {
    if (kIsWeb) return;
    try {
      await _localNotifications.cancel(id: pickupCode.hashCode + 100); // 1h warning
      await _localNotifications.cancel(id: pickupCode.hashCode + 0);   // expiry alert
      debugPrint("🔕 Cancelled scheduled expiry alerts for pickup code: $pickupCode");
    } catch (e) {
      debugPrint("Error cancelling notifications: $e");
    }
  }

  void notifyOrderCreated(String pickupCode, DateTime expiresAt, {bool isXerox = false}) {
    addNotification(
      title: 'Order Status: Active',
      body: isXerox
          ? 'Your Xerox order is active. Visit the shop and scan their QR code to collect.'
          : 'Your order is active. Proceed to the printer to scan and collect.',
      type: 'success',
    );
    _scheduleExpiryAlerts(pickupCode, expiresAt, isXerox: isXerox);
  }

  Future<void> _scheduleExpiryAlerts(String pickupCode, DateTime expiresAt, {bool isXerox = false}) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final String orderRef = isXerox ? 'Xerox order' : 'order ($pickupCode)';
    
    // 1 Hour Alert
    final oneHourMark = expiresAt.subtract(const Duration(hours: 1));
    if (oneHourMark.isAfter(now)) {
      await _scheduleLocalNotification(
        id: (pickupCode.hashCode + 100),
        title: 'Final Expiry Warning',
        body: 'Your $orderRef will expire in 1 hour.',
        scheduledDate: oneHourMark,
      );
    }

    // Exactly at expiry
    if (expiresAt.isAfter(now)) {
      await _scheduleLocalNotification(
        id: (pickupCode.hashCode + 0),
        title: 'Order Expired',
        body: 'Your $orderRef has expired.',
        scheduledDate: expiresAt,
      );
    }
  }

  Future<void> _scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'thinkink_expiry',
          'Expiry Warnings',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Timer? _expiryTimer;
  void _startExpiryChecker() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _checkOrdersExpiry();
    });
  }

  Future<void> _checkOrdersExpiry() async {
    final fs = FirestoreService();
    final orders = await fs.getActiveOrders().first; 
    final now = DateTime.now();

    for (var order in orders) {
      // 🛡️ SKIP EXPIRED NOTIFICATION IF COMPLETED
      if (order.status == OrderStatus.completed || order.isPrintingCompleted) {
        // Real-time listener handles the notification, but we double check here
        final completionKey = 'comp_${order.orderId}';
        if (!_sentAlerts.contains(completionKey)) {
          notifyOrderCompleted(order);
          _sentAlerts.add(completionKey);
        }
        continue;
      }

      final remaining = order.expiresAt.difference(now);
      final minutes = remaining.inMinutes;

      if (minutes <= 0) {
        _triggerListAlert(order.orderId, 'now (Expired)', 'payment');
        final expiredOrder = order.copyWith(status: OrderStatus.expired, reason: "Auto-Expired");
        await fs.archiveOrderLocally(expiredOrder);
        await fs.updateOrderStatus(orderId: order.orderId, status: 'EXPIRED');
      }
    }
  }

  final Set<String> _sentAlerts = {};
  void _triggerListAlert(String orderId, String label, String type) {
    final key = '${orderId}_$label';
    if (_sentAlerts.contains(key)) return;
    final String displayId = orderId.length > 6 ? orderId.substring(0, 6).toUpperCase() : orderId.toUpperCase();
    addNotification(
      title: label.contains('Expired') ? 'Order Expired' : 'Order Expiring Soon',
      body: label.contains('Expired') 
        ? 'Order #$displayId is no longer valid.'
        : 'Order #$displayId expires in $label.',
      type: type,
      showLocal: false, 
    );
    _sentAlerts.add(key);
  }
}
