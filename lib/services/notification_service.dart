import 'dart:async';
import 'package:apnt/models/print_order_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'backend_service.dart';
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
    FirebaseAuth.instance.authStateChanges().listen((user) {
      loadNotifications();
    });
    if (FirebaseAuth.instance.currentUser != null) {
      loadNotifications();
    }
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    try {
      if (!kIsWeb) {
        // 🚀 Initialize for Android/iOS (Using stable 17.x signature)
        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (details) {
             debugPrint("🔔 Notification Tapped: ${details.payload}");
          },
        );

        // 🛡️ Create High-Importance Channel (Matching Expiry Success)
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'order_notifications',
          'Order Status Updates',
          description: 'Real-time alerts for print completion',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
      // Request permissions (Unified Web/Mobile)
      await requestPermission();
    } catch (e) {
      debugPrint("Notification Plugin initialization check failed: $e");
    }



    // 🚀 Initialize FCM (Background/Killed logic)
    // 🌐 Runs on web too: registers web/firebase-messaging-sw.js and syncs the
    // browser's FCM token so backend pushes reach web/PWA users.
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;
    
    // 🔔 Request Permissions
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // 📡 🛡️ AUTH-AWARE TOKEN SYNC
    // We listen to auth changes so if user logs in LATER, we still get their token
    FirebaseAuth.instance.authStateChanges().listen((user) async {
       if (user != null) {
          try {
            final token = await messaging.getToken();
            if (token != null) {
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'fcmToken': token,
                'email': user.email, // 🛡️ Sync email for backend fallback lookups
                'tokenUpdatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              debugPrint("🚀 FCM: Token successfully linked to UID: ${user.uid}");
            }
          } catch (e) {
            debugPrint("⚠️ FCM: Token sync failed: $e");
          }
       }
    });

    // 🔥 Foreground Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       if (message.notification != null) {
         addNotification(
           title: message.notification!.title ?? "New Update", 
           body: message.notification!.body ?? "Check your orders.",
           type: 'info'
         );
       }
    });

    // 📩 Handle notification tap (when app was opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("🎯 User tapped on a notification!");
    });
  }

  StreamSubscription? _orderSubscription;
  void initOrderListeners() {
    _orderSubscription?.cancel();
    _orderSubscription = FirestoreService().getActiveOrders().listen((orders) {
      _checkOrdersStatusRealtime(orders);
    });
  }

  void _checkOrdersStatusRealtime(List<PrintOrderModel> orders) {
    // Completion alerts are handled exclusively by Backend FCM.
  }

  Future<void> requestPermission() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      if (kIsWeb) {
        // 🌐 WEB REQUEST via Safe Abstraction
        final String status = await web_js.getBrowserNotificationStatus();
        if (status == 'default') {
           debugPrint("🌐 Requesting Web Notification Permission...");
           web_js.triggerBrowserNotificationPermission();
        } else {
           debugPrint("🌐 Web notification status: $status");
        }
      } else {
        // 📱 MOBILE REQUEST
        int retryCount = prefs.getInt('notification_permission_retries') ?? 0;

        // 🛡️ STOP after 3 failed attempts to avoid annoying the user
        if (retryCount >= 3) {
          debugPrint("🔔 Permission Retry Policy: Max attempts (3) reached.");
          return;
        }

        NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
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
        }
      }
    } catch (e) {
      debugPrint("Error requesting notification permission: $e");
    }
  }

  CollectionReference _getNotificationsCollection() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'guest_user';
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');
  }

  StreamSubscription? _notificationsSubscription;

  Future<void> loadNotifications() async {
    _notificationsSubscription?.cancel();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _notifications.clear();
      notifyListeners();
      return;
    }

    _notificationsSubscription = _getNotificationsCollection()
        .orderBy('time', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notifications.clear();
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          _notifications.add(NotificationItem(
            id: doc.id,
            title: data['title'] ?? '',
            body: data['body'] ?? '',
            time: data['time'] is Timestamp
                ? (data['time'] as Timestamp).toDate()
                : DateTime.parse(data['time'] ?? DateTime.now().toIso8601String()),
            type: data['type'] ?? 'info',
            isRead: data['isRead'] ?? false,
          ));
        } catch (e) {
          debugPrint("Error parsing notification: $e");
        }
      }
      notifyListeners();
    }, onError: (e) async {
      debugPrint("ℹ️ Notification stream status: $e. Syncing via REST API...");
      await _loadFromRestApi(user.uid);
    });

    // Also trigger initial load from REST API to ensure immediate population
    _loadFromRestApi(user.uid);
  }

  Future<void> _loadFromRestApi(String userId) async {
    try {
      final list = await BackendService().getNotifications(userId);
      if (list.isNotEmpty) {
        final existingIds = _notifications.map((n) => n.id).toSet();
        bool updated = false;
        for (final data in list) {
          final id = (data['id'] ?? '').toString();
          if (id.isNotEmpty && !existingIds.contains(id)) {
            _notifications.add(NotificationItem(
              id: id,
              title: data['title'] ?? '',
              body: data['body'] ?? '',
              time: DateTime.tryParse(data['time']?.toString() ?? '') ?? DateTime.now(),
              type: data['type'] ?? 'info',
              isRead: data['isRead'] == true,
            ));
            updated = true;
          }
        }
        if (updated) {
          _notifications.sort((a, b) => b.time.compareTo(a.time));
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("REST API notification load error: $e");
    }
  }

  Future<void> addNotification({
    required String title,
    required String body,
    required String type,
    bool showLocal = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newItem = NotificationItem(
      id: id,
      title: title,
      body: body,
      time: DateTime.now(),
      type: type,
    );

    try {
      await _getNotificationsCollection().doc(id).set({
        'title': title,
        'body': body,
        'time': Timestamp.fromDate(newItem.time),
        'type': type,
        'isRead': false,
      });
    } catch (e) {
      debugPrint("Error saving notification to Firestore: $e");
    }

    if (showLocal && !kIsWeb) {
      await _showSystemNotification(title: title, body: body);
    }
  }

  Future<void> _showSystemNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'order_notifications',
      'Order Status Updates',
      channelDescription: 'Real-time alerts for print completion and pickup codes',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> markAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();

    try {
      final unreadSnapshot = await _getNotificationsCollection().where('isRead', isEqualTo: false).get();
      if (unreadSnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in unreadSnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Firestore markAsRead error: $e");
    }

    await BackendService().markNotificationsAsRead(user.uid);
  }

  Future<void> clearAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notifications.clear();
    notifyListeners();

    try {
      final snapshot = await _getNotificationsCollection().get();
      if (snapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Firestore clearAll error: $e");
    }

    await BackendService().clearNotifications(user.uid);
  }

  void notifyOrderCompleted(PrintOrderModel order) {
    final String orderNum = (order.customId ?? order.orderId).toLowerCase().replaceFirst('order_', '');
    
    // 🛡️ [SILENCED] - FCM Push already shows the system alert.
    // We only add to the in-app history now to avoid duplicates.
    addNotification(
      title: 'Print Complete! 🎉',
      body: 'Your order $orderNum is ready for pickup! Visit again!',
      type: 'success',
      showLocal: false, // 🛡️ Ensure no system tray duplicate
    );
  }

  void notifyOrderCreated(String pickupCode, {bool isXerox = false}) {
    addNotification(
      title: 'Order Status: Active',
      body: isXerox
          ? 'Your Xerox order is active. Visit the shop and scan their QR code to collect.'
          : 'Your order is active. Proceed to the printer to scan and collect.',
      type: 'success',
    );
  }
}
