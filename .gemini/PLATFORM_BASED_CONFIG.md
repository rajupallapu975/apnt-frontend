# ✅ Automatic Platform-Based Backend Configuration

## 🎯 What This Does

Your app now **automatically** uses the correct backend URL based on the platform:
- **Web** → `http://localhost:5000`
- **Android** → `http://10.15.250.155:5000`
- **iOS** → `http://10.15.250.155:5000`

**No code changes needed!** Just run the app on any platform and it works! 🎉

---

## 📁 Files Created/Modified

### New File: `lib/config/backend_config.dart`
This file contains the smart configuration that detects the platform and uses the correct URL.

```dart
class BackendConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5000";  // Web
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.15.250.155:5000";  // Android
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return "http://10.15.250.155:5000";  // iOS
    } else {
      return "http://localhost:5000";  // Desktop
    }
  }
}
```

### Modified Files:
1. ✅ `lib/services/order_service.dart` - Now uses `BackendConfig.createOrderUrl`
2. ✅ `lib/services/local_upload_service.dart` - Now uses `BackendConfig.uploadFilesUrl`

---

## 🚀 How to Use

### For Web Development:
```bash
flutter run -d chrome
```
**Automatically uses:** `http://localhost:5000` ✅

### For Android:
```bash
flutter run
```
**Automatically uses:** `http://10.15.250.155:5000` ✅

### For iOS:
```bash
flutter run -d ios
```
**Automatically uses:** `http://10.15.250.155:5000` ✅

---

## 🔧 How to Change IPs

If your Windows PC IP changes or you want to use a different backend, just edit **ONE file**:

**File:** `lib/config/backend_config.dart`

```dart
static String get baseUrl {
  if (kIsWeb) {
    return "http://localhost:5000";  // ← Change this for web
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    return "http://YOUR_NEW_IP:5000";  // ← Change this for Android
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    return "http://YOUR_NEW_IP:5000";  // ← Change this for iOS
  } else {
    return "http://localhost:5000";  // ← Change this for desktop
  }
}
```

---

## 📊 Platform Detection Logic

| Platform | Detection Method | URL Used |
|----------|-----------------|----------|
| **Web** | `kIsWeb == true` | `localhost:5000` |
| **Android** | `TargetPlatform.android` | `10.15.250.155:5000` |
| **iOS** | `TargetPlatform.iOS` | `10.15.250.155:5000` |
| **Desktop** | Other platforms | `localhost:5000` |

---

## 🧪 Testing Different Platforms

### Test on Web:
```bash
flutter run -d chrome
```
**Expected log:**
```
📍 Backend URL: http://localhost:5000/create-order
```

### Test on Android:
```bash
flutter run
```
**Expected log:**
```
📍 Backend URL: http://10.15.250.155:5000/create-order
```

### Test on iOS:
```bash
flutter run -d ios
```
**Expected log:**
```
📍 Backend URL: http://10.15.250.155:5000/create-order
```

---

## 🔍 Debugging

To see which configuration is being used, add this to your app startup:

```dart
import 'package:apnt/config/backend_config.dart';

void main() {
  BackendConfig.printConfig();  // Prints current config
  runApp(MyApp());
}
```

**Output:**
```
🔧 Backend Configuration:
   Platform: android
   Is Web: false
   Base URL: http://10.15.250.155:5000
```

---

## 🌐 Network Requirements

### For Web:
- ✅ Backend running on same PC
- ✅ No network setup needed

### For Android/iOS:
- ✅ Backend running on Windows PC
- ✅ Mobile device on **same WiFi** as PC
- ✅ Windows Firewall allows Node.js (port 5000)

---

## 🎯 Production Deployment

### Option 1: Use Raspberry Pi for Production

Update `backend_config.dart`:

```dart
static String get baseUrl {
  if (kIsWeb) {
    return "http://localhost:5000";  // Development
  } else {
    return "http://10.33.125.155:5000";  // Production (Raspberry Pi)
  }
}
```

### Option 2: Use Environment Variables

For more advanced setup:

```dart
static String get baseUrl {
  const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  
  if (isProduction) {
    return "http://10.33.125.155:5000";  // Production
  } else if (kIsWeb) {
    return "http://localhost:5000";  // Development Web
  } else {
    return "http://10.15.250.155:5000";  // Development Mobile
  }
}
```

Then run with:
```bash
flutter run --dart-define=PRODUCTION=true
```

---

## ✅ Benefits

1. **No Code Changes** - Switch platforms without editing code
2. **Single Source of Truth** - All URLs in one file
3. **Easy Maintenance** - Change IP in one place
4. **Platform Aware** - Automatically adapts to platform
5. **Developer Friendly** - Clear and simple configuration

---

## 📝 Summary

**Before:**
- Had to manually change IPs for each platform
- URLs hardcoded in multiple files
- Easy to forget to update

**After:**
- ✅ Automatic platform detection
- ✅ Single configuration file
- ✅ Works on web, Android, and iOS without changes

**Just run and it works!** 🎉

---

## 🔗 Quick Reference

| File | Purpose |
|------|---------|
| `lib/config/backend_config.dart` | **Configure IPs here** |
| `lib/services/order_service.dart` | Uses `BackendConfig.createOrderUrl` |
| `lib/services/local_upload_service.dart` | Uses `BackendConfig.uploadFilesUrl` |

**To change backend IP:** Edit `backend_config.dart` only!
