# Flutter Wrapper ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Razorpay
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
