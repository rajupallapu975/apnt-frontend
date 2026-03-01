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
          // Extract content within parentheses if possible, or just the part before the first comma
          final match = RegExp(r'\(([^,)]+)').firstMatch(timeZoneName);
          if (match != null && match.groupCount >= 1) {
            timeZoneName = match.group(1)!;
          }
        }
        
        try {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
          debugPrint("🔔 Timezone initialized: $timeZoneName");
        } catch (e) {
          debugPrint("⚠️ Location $timeZoneName not found in database, falling back to UTC");
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
      }
    } catch (e) {
      debugPrint("⚠️ Could not initialize timezone: $e");
      // Fallback to UTC to prevent crashes later
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
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
          onDidReceiveNotificationResponse: (details) {
            // Handle notification tap
          },
        );
        // Request permissions
        await requestPermission();
      }
    } catch (e) {
      debugPrint("Notification Plugin not linked yet. Please perform a Full Re-run (Stop & Run). Error: $e");
    }

    _startExpiryChecker();
  }

  Future<void> requestPermission() async {
    if (kIsWeb) return;
    try {
      await Permission.notification.request();
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (await Permission.scheduleExactAlarm.isDenied) {
          await Permission.scheduleExactAlarm.request();
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
    for (var n in _notifications) {
      n.isRead = true;
    }
    saveNotifications();
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    saveNotifications();
    notifyListeners();
  }

  // ─── Trigger Logic ─────────────────────────────────────────────────────────

  void notifyOrderCreated(String pickupCode, DateTime expiresAt) {
    addNotification(
      title: 'Order Status: Active',
      body: 'Pickup code generated: $pickupCode. Scan it at the printer.',
      type: 'success',
    );
    
    // Schedule background alerts for expiry
    _scheduleExpiryAlerts(pickupCode, expiresAt);
  }

  void notifyOrderPrinted(String orderId) {
    addNotification(
      title: 'Print Complete!',
      body: 'Your order #${orderId.substring(0,6).toUpperCase()} has been printed.',
      type: 'success',
    );
  }

  // Schedule alerts that work when app is closed
  Future<void> _scheduleExpiryAlerts(String pickupCode, DateTime expiresAt) async {
    if (kIsWeb) return;

    final now = DateTime.now();
    
    // 4 Hour Alert
    final fourHourMark = expiresAt.subtract(const Duration(hours: 4));
    if (fourHourMark.isAfter(now)) {
      await _scheduleLocalNotification(
        id: (pickupCode.hashCode + 400),
        title: 'Order Expiring Soon',
        body: 'Your order (Code: $pickupCode) expires in 4 hours.',
        scheduledDate: fourHourMark,
      );
    }

    // 1 Hour Alert
    final oneHourMark = expiresAt.subtract(const Duration(hours: 1));
    if (oneHourMark.isAfter(now)) {
      await _scheduleLocalNotification(
        id: (pickupCode.hashCode + 100),
        title: 'Final Expiry Warning',
        body: 'Order (Code: $pickupCode) will expire in 1 hour. Pick it up now!',
        scheduledDate: oneHourMark,
      );
    }

    // 📢 EXPIRE ALERT (Exactly at expiry)
    if (expiresAt.isAfter(now)) {
      await _scheduleLocalNotification(
        id: (pickupCode.hashCode + 0),
        title: 'Order Expired',
        body: 'Your order (Code: $pickupCode) has expired.',
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
    // This part still adds items to the IN-APP list for when user opens app
    final fs = FirestoreService();
    final orders = await fs.getActiveOrders().first; 
    final now = DateTime.now();

    for (var order in orders) {
      final remaining = order.expiresAt.difference(now);
      final minutes = remaining.inMinutes;

      if (minutes > 0) {
        if (minutes > 225 && minutes <= 240) {
          _triggerListAlert(order.orderId, '4 hours', 'warning');
        }
        else if (minutes > 45 && minutes <= 60) {
          _triggerListAlert(order.orderId, '1 hour', 'warning');
        }
      } else {
        // 🚨 JUST EXPIRED
        _triggerListAlert(order.orderId, 'now (Expired)', 'payment');
        
        // 🗳️ ARCHIVE TO LOCAL HISTORY
        // We set status to expired so it shows up correctly in history
        final expiredOrder = order.copyWith(status: OrderStatus.expired, reason: "Auto-Expired");
        await fs.archiveOrderLocally(expiredOrder);
        
        // ☁️ UPDATE FIRESTORE STATUS
        await fs.updateOrderStatus(orderId: order.orderId, status: 'EXPIRED');
        debugPrint("🗑️ Order ${order.orderId} moved to history because it expired.");
      }
    }
  }

  final Set<String> _sentAlerts = {};
  void _triggerListAlert(String orderId, String label, String type) {
    final key = '${orderId}_$label';
    if (_sentAlerts.contains(key)) return;

    addNotification(
      title: label.contains('Expired') ? 'Order Expired' : 'Order Expiring Soon',
      body: label.contains('Expired') 
        ? 'Order #${orderId.substring(0,6).toUpperCase()} is no longer valid.'
        : 'Order #${orderId.substring(0,6).toUpperCase()} expires in $label.',
      type: type,
      showLocal: false, 
    );
    _sentAlerts.add(key);
  }
}
