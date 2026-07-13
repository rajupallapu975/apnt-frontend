import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
// flutter_local_notifications handled by NotificationService internally
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/upload_viewmodel.dart';
import 'xerox_shop/xerox_shop_viewmodel.dart';
import 'views/screens/login_view.dart';
import 'views/screens/upload_page.dart';
import 'utils/app_theme.dart';
import 'utils/app_colors.dart';

import 'services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_auth/firebase_auth.dart';
// cloud_firestore and shared_preferences are used transitively via services
import 'dart:io';

// 🛡️ High-fidelity top-level background handler for User App (Closed/Killed state)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 🛡️ Firebase.initializeApp is removed from background handler to prevent process-wide
  // ConcurrentModificationException. The handler is empty and does not run any Firebase tasks.
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
  
  int retries = 0;
  while (retries < 3) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      break;
    } catch (e) {
      retries++;
      if (retries >= 3) {
        debugPrint("⚠️ Main Firebase Init failed after 3 retries: $e");
      } else {
        debugPrint("⚠️ Main Firebase Init failed (try $retries), retrying in 500ms...: $e");
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  // 🔔 FCM Background Handler registration
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ⏳ Introduce a small delay to prevent ConcurrentModificationException on native side
  await Future.delayed(const Duration(milliseconds: 300));

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

  // ⏳ Introduce another small delay before the next Firebase app initialization
  await Future.delayed(const Duration(milliseconds: 300));

  // 🏪 Initialize Zikrinter Project as a secondary app for service catalogs
  try {
    await Firebase.initializeApp(
      name: "zikrinter",
      options: kIsWeb
          ? const FirebaseOptions(
              apiKey: 'AIzaSyDB-g9ey111EaWfj5sf2n7KjY1MMjjibh4',
              appId: '1:947972179342:web:38e04561ca1132f60210df',
              messagingSenderId: '947972179342',
              projectId: 'zikrinter',
              authDomain: 'zikrinter.firebaseapp.com',
              storageBucket: 'zikrinter.firebasestorage.app',
            )
          : (defaultTargetPlatform == TargetPlatform.iOS
              ? const FirebaseOptions(
                  apiKey: 'AIzaSyCk48p1rCR74_J2WyFJ9ZGVkjw8AhC-yZ8',
                  appId: '1:947972179342:ios:271ef98eb23942b70210df',
                  messagingSenderId: '947972179342',
                  projectId: 'zikrinter',
                  storageBucket: 'zikrinter.firebasestorage.app',
                  iosBundleId: 'com.zikrinter.zikrinter',
                )
              : const FirebaseOptions(
                  apiKey: 'AIzaSyBCKnAcecrspWbELBfO6f0OegcfhyxrS38',
                  appId: '1:947972179342:android:b9b56746265d8cb00210df',
                  messagingSenderId: '947972179342',
                  projectId: 'zikrinter',
                  storageBucket: 'zikrinter.firebasestorage.app',
                )),
    );
    debugPrint("🚀 Zikrinter Project Secondary App Initialized");
  } catch (e) {
    debugPrint("⚠️ Zikrinter Project Init Error: $e");
  }

  // 🏪 Initialize Customer Project 2 (Backup 1) as a secondary app
  try {
    await Firebase.initializeApp(
      name: "zikrint-944a4",
      options: const FirebaseOptions(
        apiKey: "AIzaSyD34jkVSpxyjHBY_CVoyP2e8xgJdJv6ucw",
        appId: "1:484986026046:android:bd7da1c8d0dfc217b1796f",
        messagingSenderId: "484986026046",
        projectId: "zikrint-944a4",
      ),
    );
    debugPrint("🚀 Customer Project 2 (Backup 1) Initialized");
  } catch (e) {
    debugPrint("⚠️ Customer Project 2 Init Error: $e");
  }

  await Future.delayed(const Duration(milliseconds: 300));

  // 🏪 Initialize Customer Project 3 (Backup 2) as a secondary app
  try {
    await Firebase.initializeApp(
      name: "think-ink",
      options: const FirebaseOptions(
        apiKey: "AIzaSyCZW5G6byY78K9o4a_YW0GqsPwr_t0gstA",
        appId: "1:802839616382:android:e6a312bfff81a52c4c312f",
        messagingSenderId: "802839616382",
        projectId: "think-ink",
      ),
    );
    debugPrint("🚀 Customer Project 3 (Backup 2) Initialized");
  } catch (e) {
    debugPrint("⚠️ Customer Project 3 Init Error: $e");
  }

  // 🚀 Authenticate on secondary apps anonymously to bypass PERMISSION_DENIED on multi-app reads
  try {
    final secondaryApps = ["zikrint_admin", "zikrinter", "zikrint-944a4", "think-ink"];
    for (final appName in secondaryApps) {
      try {
        final app = Firebase.app(appName);
        final auth = FirebaseAuth.instanceFor(app: app);
        if (auth.currentUser == null) {
          await auth.signInAnonymously();
          debugPrint("🚀 Signed in anonymously to secondary app: $appName");
        }
      } catch (e) {
        debugPrint("⚠️ Anonymous auth failed for $appName: $e");
      }
    }
  } catch (e) {
    debugPrint("⚠️ Secondary apps auth error: $e");
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
    Workmanager().initialize(callbackDispatcher);
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

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zikrint',
      theme: AppTheme.lightTheme,
      scrollBehavior: MyCustomScrollBehavior(),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    // 🔄 Show splash while auth state is loading
    if (authVM.isLoading) {
      return const _SplashScreen();
    }

    // ✅ Authenticated with a real Google account (not anonymous)
    final user = authVM.user;
    if (user != null && !user.isAnonymous) {
      return const UploadPage();
    }

    // 🔐 Not authenticated — show Google Sign-In
    return const LoginView();
  }
}

/// 🌟 Branded splash screen shown while Firebase auth state resolves
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/image.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}
