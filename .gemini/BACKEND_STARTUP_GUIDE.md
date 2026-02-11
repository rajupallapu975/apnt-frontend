# Backend Startup Guide

## Your Backend: Node.js + Express + Firestore

### Prerequisites
- Node.js installed
- Firebase service account key (`serviceAccountKey.json`)
- Dependencies installed

---

## 🚀 How to Start the Backend

### Step 1: Navigate to Backend Directory
```bash
cd /path/to/your/backend
# (wherever index.js, order.js, firebase.js, upload.js are located)
```

### Step 2: Install Dependencies (First Time Only)
```bash
npm install
```

**Required packages:**
- express
- cors
- firebase-admin
- multer

If `package.json` doesn't exist, install manually:
```bash
npm install express cors firebase-admin multer
```

### Step 3: Verify Firebase Service Account Key
Make sure `serviceAccountKey.json` exists in the backend directory.

### Step 4: Start the Server
```bash
node index.js
```

**Expected Output:**
```
🚀 Backend running on port 5000
```

---

## 🔍 Verify Backend is Running

### Test 1: Health Check
```bash
curl http://10.33.125.155:5000/
```

**Expected:** `✅ Backend is running`

### Test 2: Test Create Order
```bash
curl -X POST http://10.33.125.155:5000/create-order \
  -H "Content-Type: application/json" \
  -d '{"printSettings":{"doubleSide":false,"files":[]}}'
```

**Expected:**
```json
{
  "orderId": "ORD_1234567890",
  "pickupCode": "123456"
}
```

---

## 🌐 For Web Testing: CORS is Already Enabled ✅

Your backend already has:
```javascript
app.use(cors());
```

This means web requests from Chrome should work fine!

---

## 📍 Backend Location

Your backend needs to be running on the **Raspberry Pi** at `10.33.125.155`.

### On Raspberry Pi:

1. **SSH into Raspberry Pi:**
   ```bash
   ssh pi@10.33.125.155
   ```

2. **Navigate to backend directory:**
   ```bash
   cd ~/your-backend-folder
   # or wherever you have index.js
   ```

3. **Start the server:**
   ```bash
   node index.js
   ```

4. **Keep it running:**
   Use `pm2` or `screen` to keep it running in background:
   
   **Option A: Using PM2 (Recommended)**
   ```bash
   npm install -g pm2
   pm2 start index.js --name "print-backend"
   pm2 save
   pm2 startup
   ```

   **Option B: Using screen**
   ```bash
   screen -S backend
   node index.js
   # Press Ctrl+A then D to detach
   ```

---

## 🔧 Troubleshooting

### Issue 1: Port Already in Use
```
Error: listen EADDRINUSE: address already in use :::5000
```

**Solution:**
```bash
# Find what's using port 5000
sudo lsof -i :5000

# Kill the process
sudo kill -9 <PID>

# Or use a different port
PORT=5001 node index.js
```

### Issue 2: Firebase Admin SDK Error
```
Error: Could not load the default credentials
```

**Solution:**
- Verify `serviceAccountKey.json` exists
- Check file permissions
- Ensure it's valid JSON

### Issue 3: Cannot Access from Network
```
Connection refused
```

**Solution:**
- Check Raspberry Pi firewall:
  ```bash
  sudo ufw allow 5000
  ```
- Verify server is listening on `0.0.0.0` (it is in your code ✅)

---

## 📱 Testing from Flutter App

Once backend is running, your Flutter app should work!

### Expected Flow:
1. User enters payment code `0579` ✅
2. App calls `POST /create-order` → Gets `orderId` and `pickupCode`
3. App calls `POST /upload-files` → Uploads PDF files
4. Success page shows pickup code

### Watch Console Logs:
You'll see the detailed logs we added:
- 🔄 Starting payment processing...
- 📝 Creating order from backend...
- ✅ Order created successfully!
- 📤 Starting file upload...
- ✅ All files uploaded successfully!

---

## 🎯 Next Steps

1. **Start the backend** on Raspberry Pi:
   ```bash
   ssh pi@10.33.125.155
   cd /path/to/backend
   node index.js
   ```

2. **Verify it's running:**
   ```bash
   curl http://10.33.125.155:5000/
   ```

3. **Test in Flutter app:**
   - Upload a PDF
   - Click Payment
   - Enter code `0579`
   - Watch it work! 🎉

---

## Alternative: Run Backend Locally for Testing

If you want to test without Raspberry Pi, you can run the backend on your local machine:

1. **Copy backend files** to your local machine
2. **Update Flutter app URLs** to use `localhost`:
   ```dart
   // In local_upload_service.dart and order_service.dart
   final uri = Uri.parse("http://localhost:5000/...");
   ```
3. **Start backend locally:**
   ```bash
   node index.js
   ```

For **Android emulator**, use `http://10.0.2.2:5000` instead of `localhost`.

---

The backend code looks good! Just need to start it. 🚀
