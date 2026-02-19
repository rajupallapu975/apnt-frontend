import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/upload_viewmodel.dart';
import 'views/screens/login_view.dart';
import 'views/screens/upload_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => UploadViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the base text theme using Manrope
    final baseTextTheme = GoogleFonts.manropeTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThinkInk',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
        ),
        fontFamily: GoogleFonts.manrope().fontFamily,
        textTheme: baseTextTheme.copyWith(
          // Use Inter for titles/headlines
          displayLarge: GoogleFonts.inter(textStyle: baseTextTheme.displayLarge, fontWeight: FontWeight.bold),
          displayMedium: GoogleFonts.inter(textStyle: baseTextTheme.displayMedium, fontWeight: FontWeight.bold),
          displaySmall: GoogleFonts.inter(textStyle: baseTextTheme.displaySmall, fontWeight: FontWeight.bold),
          headlineLarge: GoogleFonts.inter(textStyle: baseTextTheme.headlineLarge, fontWeight: FontWeight.bold),
          headlineMedium: GoogleFonts.inter(textStyle: baseTextTheme.headlineMedium, fontWeight: FontWeight.bold),
          headlineSmall: GoogleFonts.inter(textStyle: baseTextTheme.headlineSmall, fontWeight: FontWeight.bold),
          titleLarge: GoogleFonts.inter(textStyle: baseTextTheme.titleLarge, fontWeight: FontWeight.bold),
          titleMedium: GoogleFonts.inter(textStyle: baseTextTheme.titleMedium, fontWeight: FontWeight.bold),
          titleSmall: GoogleFonts.inter(textStyle: baseTextTheme.titleSmall, fontWeight: FontWeight.bold),
        ),
      ),
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

    // While checking auth state
    if (authVM.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Logged in → Upload page
    if (authVM.isAuthenticated) {
      return const UploadPage();
    }

    // Not logged in → Login page
    return const LoginView();
  }
}
