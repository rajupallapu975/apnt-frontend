import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/upload_viewmodel.dart';
import 'xerox_shop/xerox_shop_viewmodel.dart';
import 'views/screens/login_view.dart';
import 'views/screens/upload_page.dart';
import 'utils/app_theme.dart';

import 'services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// 🛡️ High-fidelity top-level background handler for User App (Closed/Killed state)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 🛡️ Initialization
  await Firebase.initializeApp();
  
  // 🛡️ Manual local notification removed to avoid duplicates.
  // The system automatically shows notifications if the FCM payload has a 'notification' block.
}

// 🛡️ BACKGROUND LOGIC: Checker that runs even if app is killed
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 🛡️ BACKGROUND CHECKER: Manual local alerts removed to favor high-fidelity FCM.
    // This dispatcher can still be used for background data sync if needed.
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔔 FCM Background Handler registration
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🏪 Initialize Zikrint Admin as a secondary app
  try {
    await Firebase.initializeApp(
      name: "zikrint_admin",
      options: const FirebaseOptions(
        apiKey: "AIzaSyAM_UmfDJyCSObGjyb2-Cp0titzv068CLM",
        authDomain: "zikrint-admin.firebaseapp.com",
        projectId: "zikrint-admin",
        storageBucket: "zikrint-admin.firebasestorage.app",
        messagingSenderId: "71044416645",
        appId: "1:71044416645:web:20135d3480fc6e3ab7d5ec",
      ),
    );
    debugPrint("🚀 Zikrint Admin Secondary App Initialized");
  } catch (e) {
    debugPrint("⚠️ Zikrint Admin Init Error: $e");
  }

  // 🔔 Initialize Notifications
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => UploadViewModel()),
        ChangeNotifierProvider(create: (_) => XeroxShopViewModel()),
        ChangeNotifierProvider.value(value: notificationService),
      ],
      child: const MyApp(),
    ),
  );

  // 🛡️ Start the Background Watchman (Android only)
  if (!kIsWeb && Platform.isAndroid) {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Workmanager().registerPeriodicTask(
        "order_check_task",
        "checkOrderStatus",
        inputData: {'userId': user.uid},
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zikrint',
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

/// Decides: Login OR Upload page
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    if (authVM.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authVM.isAuthenticated) {
      return const UploadPage();
    }

    return const LoginView();
  }
}
