# Backend Connection Issue - DIAGNOSIS & SOLUTIONS

## 🔴 Current Error

```
Error: ClientException: Failed to fetch, uri=http://10.33.125.155:5000/create-order
```

**What this means:** Your Flutter app cannot connect to the backend server.

---

## 🔍 Diagnosis

### Test Result: ❌ Backend Not Reachable
- IP Address: `10.33.125.155`
- Port: `5000`
- Status: **NOT RESPONDING**

### Possible Reasons:

1. ✅ **Backend server is not running** (Most Likely)
2. ⚠️ **Wrong IP address** (IP might have changed)
3. ⚠️ **Firewall blocking** the connection
4. ⚠️ **Different network** (device not on same network as backend)
5. ⚠️ **CORS issue** (web browser blocking cross-origin requests)

---

## 🎯 Solutions

### **Solution 1: Start Your Backend Server** ⭐ (Most Important)

Based on your conversation history, you have a **Raspberry Pi 4** running the backend server.

#### **On Raspberry Pi:**

1. **SSH into your Raspberry Pi:**
   ```bash
   ssh pi@10.33.125.155
   ```

2. **Navigate to your backend directory:**
   ```bash
   cd /path/to/your/backend
   ```

3. **Start the server:**
   ```bash
   # If it's a Python Flask server:
   python3 app.py
   
   # Or if using a different command:
   python3 server.py
   
   # Or if it's a Node.js server:
   node server.js
   ```

4. **Verify it's running:**
   ```bash
   # Check if port 5000 is listening
   sudo netstat -tulpn | grep 5000
   ```

---

### **Solution 2: Verify IP Address** 🌐

The IP address might have changed. 

#### **On Raspberry Pi, check current IP:**
```bash
hostname -I
```

#### **If IP is different:**
Update the IP in your Flutter app:

**Files to update:**
1. `lib/services/local_upload_service.dart` - Line 11
2. `lib/services/order_service.dart` - Line 9

Change:
```dart
// OLD
final uri = Uri.parse("http://10.33.125.155:5000/upload-files");

// NEW (use your actual IP)
final uri = Uri.parse("http://YOUR_NEW_IP:5000/upload-files");
```

---

### **Solution 3: Fix CORS for Web** 🌍

Since you're testing on **web (Chrome)**, the backend needs to allow cross-origin requests.

#### **For Flask Backend (Python):**

Add CORS support:

```python
from flask import Flask
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # ✅ Allow all origins

# Or be more specific:
# CORS(app, resources={r"/*": {"origins": "*"}})

@app.route('/create-order', methods=['POST'])
def create_order():
    # Your code here
    pass

@app.route('/upload-files', methods=['POST'])
def upload_files():
    # Your code here
    pass

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
```

**Install flask-cors:**
```bash
pip3 install flask-cors
```

---

### **Solution 4: Test on Mobile Instead** 📱 (Recommended)

Web has CORS restrictions. Testing on **mobile** is easier and more realistic for a print app.

#### **For Android:**

1. **Connect your Android device** via USB
2. **Enable USB debugging** on the device
3. **Run:**
   ```bash
   flutter run -d <device-name>
   ```

#### **Benefits:**
- ✅ No CORS issues
- ✅ No PDF.js needed (native support)
- ✅ Better performance
- ✅ Easier to connect to local network backend

---

### **Solution 5: Use localhost for Testing** 💻

If your backend is on the **same machine** as your Flutter app:

#### **Update URLs to use localhost:**

**For Web:**
```dart
final uri = Uri.parse("http://localhost:5000/upload-files");
```

**For Android Emulator:**
```dart
final uri = Uri.parse("http://10.0.2.2:5000/upload-files");
```

**For iOS Simulator:**
```dart
final uri = Uri.parse("http://localhost:5000/upload-files");
```

---

## 🧪 Quick Backend Test

### Test 1: Check if Backend is Running

**From PowerShell:**
```powershell
# Test connection
Test-NetConnection -ComputerName 10.33.125.155 -Port 5000

# Or use curl
curl http://10.33.125.155:5000/create-order
```

**Expected Result:**
- ✅ If backend is running: Connection successful or HTTP response
- ❌ If backend is down: Connection timeout or refused

### Test 2: Test Backend Endpoints

**Using PowerShell:**
```powershell
# Test create-order endpoint
Invoke-WebRequest -Uri "http://10.33.125.155:5000/create-order" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"printSettings":{"test":"data"}}'
```

**Expected Response:**
```json
{
  "orderId": "some-id",
  "pickupCode": "1234"
}
```

---

## 📋 Backend Requirements Checklist

Your backend must have:

- [ ] **Running** on `http://10.33.125.155:5000` (or correct IP)
- [ ] **Endpoint:** `POST /create-order`
  - Accepts: `{"printSettings": {...}}`
  - Returns: `{"orderId": "...", "pickupCode": "..."}`
- [ ] **Endpoint:** `POST /upload-files`
  - Accepts: Multipart form data with `orderId` and `files`
  - Returns: Status 200 on success
- [ ] **CORS enabled** (for web testing)
- [ ] **Firewall allows** port 5000
- [ ] **Network accessible** from your device

---

## 🔧 Recommended Next Steps

### **Step 1: Start Backend** (Priority 1)
1. SSH into Raspberry Pi
2. Navigate to backend directory
3. Start the server
4. Verify it's listening on port 5000

### **Step 2: Test Connection**
```powershell
curl http://10.33.125.155:5000/create-order
```

### **Step 3: Enable CORS** (for web)
Add `flask-cors` to your backend

### **Step 4: Test on Mobile** (Recommended)
```bash
flutter run -d <android-device>
```

---

## 🎯 Quick Fix for Testing

If you just want to test the app flow without a real backend, I can create a **mock backend** that runs locally on your machine. This would:

- ✅ Run on `localhost:5000`
- ✅ Accept orders and files
- ✅ Return mock Order IDs and Pickup Codes
- ✅ Let you test the complete flow

Would you like me to create this mock backend for testing?

---

## 📝 Summary

**Current Issue:** Backend server at `10.33.125.155:5000` is not responding

**Most Likely Cause:** Backend server is not running

**Immediate Action Required:**
1. Start your backend server on Raspberry Pi
2. Verify it's accessible
3. Enable CORS for web testing
4. OR test on mobile device instead

**Alternative:** Create a local mock backend for testing

Let me know which solution you'd like to pursue! 🚀
