import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
// flutter_local_notifications handled by NotificationService internally
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/upload_viewmodel.dart';
import 'xerox_shop/xerox_shop_viewmodel.dart';
import 'views/screens/login_view.dart';
import 'views/screens/upload_page.dart';
import 'views/screens/name_onboarding_screen.dart';
import 'utils/app_theme.dart';
import 'utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

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
  
  // 🛡️ On hot restart the FCM background isolate re-registers plugins at the
  // same time as initializeApp, causing a transient native
  // ConcurrentModificationException. Retry with growing backoff — the native
  // default app survives restarts, so a later attempt always succeeds.
  const int maxInitRetries = 5;
  int retries = 0;
  while (retries < maxInitRetries) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      break;
    } catch (e) {
      retries++;
      if (retries >= maxInitRetries) {
        debugPrint("⚠️ Main Firebase Init failed after $maxInitRetries retries: $e");
      } else {
        final waitMs = 400 * retries;
        debugPrint("⚠️ Main Firebase Init failed (try $retries), retrying in ${waitMs}ms...: $e");
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }
  }

  // 🛡️ Last-chance attempt after a longer settle if all retries failed
  if (Firebase.apps.isEmpty) {
    await Future.delayed(const Duration(seconds: 2));
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint("✅ Main Firebase Init succeeded on last-chance attempt");
    } catch (e) {
      debugPrint("❌ Main Firebase Init permanently failed: $e");
    }
  }

  // 🔔 FCM Background Handler registration
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔔 Initialize Notifications — never allow this to abort startup
  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } catch (e) {
    debugPrint("⚠️ Notification init failed (continuing startup): $e");
  }

  // 🔤 Wait for Google Fonts (Manrope/Inter) before first frame so web/mobile
  // never render a fallback font and then "jump" to the real one.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.manrope(),
      GoogleFonts.inter(),
    ]).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint("⚠️ Font preload skipped: $e");
  }

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

  // 🚀 Secondary Firebase apps are not needed for the first frame — initialize
  // them in the background so startup doesn't skip frames.
  // FirestoreService.getFirestore falls back to the primary instance until ready.
  unawaited(_initializeSecondaryApps());

  // 🛡️ Start the Background Watchman (Android only)
  if (!kIsWeb && Platform.isAndroid && Firebase.apps.isNotEmpty) {
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

/// Initializes the four secondary Firebase apps and their anonymous sessions
/// AFTER the first frame. Kept sequential with the original 300ms gaps to
/// avoid the native ConcurrentModificationException the delays were added for.
Future<void> _initializeSecondaryApps() async {
  // ⏳ Small delay to prevent ConcurrentModificationException on native side
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
      // 🔠 Respect the user's system text size, but clamp it so extreme
      // accessibility settings scale text without shattering fixed layouts.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler
                .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.2),
          ),
          child: child!,
        );
      },
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

    final user = authVM.user;
    if (user != null) {
      if (user.isAnonymous) {
        // 🔒 Anonymous (Guest): Must have an onboarded name before accessing the app.
        // If not set yet, show LoginView (enabling Google Sign-In or Continue as Guest choice).
        if (authVM.displayName == null || authVM.displayName!.trim().isEmpty) {
          return const LoginView();
        }
      } else {
        // 🔐 Google User: Must confirm/onboard their name.
        if (authVM.displayName == null || authVM.displayName!.trim().isEmpty) {
          return const NameOnboardingScreen();
        }
      }
      return const UploadPage();
    }

    // 🔐 Safe fallback
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
