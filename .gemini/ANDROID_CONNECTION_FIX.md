# Android Device Connection - Fixed! ✅

## Problem
Your Android device couldn't connect to the backend because it was using `localhost`, which refers to the Android device itself, not your Windows PC.

## Solution Applied

### 1. Updated Backend URLs
Changed from `localhost` to your Windows PC IP address:

**Before:**
```dart
http://localhost:5000
```

**After:**
```dart
http://10.15.250.155:5000
```

### 2. Files Updated
- ✅ `lib/services/order_service.dart` → Line 10
- ✅ `lib/services/local_upload_service.dart` → Line 14

---

## Next Steps

### 1. Make Sure Backend Accepts Network Connections

Your backend in `index.js` already has this (which is correct):
```javascript
app.listen(PORT, "0.0.0.0", () => {
  console.log(`🚀 Backend running on port ${PORT}`);
});
```

The `"0.0.0.0"` means it accepts connections from any IP address. ✅

### 2. Check Windows Firewall

Make sure Windows Firewall allows Node.js to accept incoming connections on port 5000.

**To check/fix:**
1. Open Windows Defender Firewall
2. Click "Allow an app through firewall"
3. Find "Node.js" and make sure both Private and Public are checked
4. If not listed, click "Allow another app" and add Node.js

### 3. Verify Backend is Running

Make sure your backend is still running:
```bash
cd C:\Users\SATYA ANANDA RAJU\Desktop\PrinteR-backend
node index.js
```

You should see:
```
🚀 Backend running on port 5000
```

### 4. Test Connection from Android

Run your app on Android:
```bash
flutter run
```

Now when you make a payment, it should connect to your Windows PC!

---

## Network Setup

```
┌─────────────────────────┐
│   Windows PC            │
│   IP: 10.15.250.155     │
│                         │
│   ┌─────────────┐      │
│   │ Backend     │      │
│   │ Port: 5000  │      │
│   └─────────────┘      │
└───────────┬─────────────┘
            │
            │ WiFi Network
            │ (10.15.250.x)
            │
┌───────────▼─────────────┐
│   Android Device        │
│                         │
│   ┌─────────────┐      │
│   │ Flutter App │      │
│   └─────────────┘      │
└─────────────────────────┘
```

Both devices must be on the **same WiFi network**!

---

## Troubleshooting

### If it still doesn't connect:

1. **Check if both devices are on same WiFi**
   - Windows PC: Connected to WiFi
   - Android: Connected to same WiFi (not mobile data!)

2. **Test backend from Android browser**
   - Open Chrome on Android
   - Go to: `http://10.15.250.155:5000`
   - You should see: "✅ Backend is running"

3. **Check Windows Firewall**
   - Temporarily disable to test
   - If it works, add Node.js as exception

4. **Restart backend**
   - Stop: Ctrl+C
   - Start: `node index.js`

---

## URL Configuration Reference

| Platform | URL to Use |
|----------|------------|
| **Web (same PC)** | `http://localhost:5000` |
| **Android Emulator** | `http://10.0.2.2:5000` |
| **Android Device** | `http://10.15.250.155:5000` ✅ (Current) |
| **Raspberry Pi** | `http://10.33.125.155:5000` |

---

## Summary

✅ **Fixed:** Changed backend URL to Windows PC IP address
✅ **Ready:** Android device can now connect to backend
⏳ **Next:** Run the app and test!

```bash
flutter run
```

The payment and upload should work now! 🎉
