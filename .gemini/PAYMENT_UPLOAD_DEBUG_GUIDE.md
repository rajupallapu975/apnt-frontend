# Payment & PDF Upload Issue - Debugging Guide

## Problem Summary
When making a payment, the PDF files are not being uploaded and you're getting an error code.

## Root Causes Identified

### 1. **Missing Error Logging** ❌
- The app was failing silently without showing what went wrong
- No visibility into whether the issue was:
  - Order creation failure
  - File upload failure  
  - Network connectivity issue

### 2. **Potential Network Issues** 🌐
- Backend URL: `http://10.33.125.155:5000`
- This is a local network IP address
- **Possible problems:**
  - Backend server might not be running
  - IP address might have changed
  - Network firewall blocking the connection
  - Device not on the same network

### 3. **Payment Flow** 💳
The payment process follows these steps:
1. User clicks "Payment" button
2. Enters payment code (0579)
3. If correct → navigates to `PaymentProcessingPage`
4. Creates order on backend
5. Uploads files to backend
6. Shows success/error page

**If ANY step fails, the entire process stops!**

---

## Changes Made ✅

I've added **comprehensive logging** to help you identify the exact failure point:

### 1. **PaymentProcessingPage** (`payment_processing_page.dart`)
- Logs when processing starts
- Shows print settings being sent
- Shows number of files to upload
- Logs order creation success with Order ID and Pickup Code
- Lists each file being uploaded with size
- **Captures and displays the EXACT error message**

### 2. **LocalUploadService** (`local_upload_service.dart`)
- Logs upload URL
- Shows each file being added to the request
- Displays content type for each file
- Shows server response status code
- **Captures server error response body**

### 3. **OrderService** (`order_service.dart`)
- Logs backend URL
- Shows complete request body
- Displays server response
- **Shows detailed error from backend**

---

## How to Debug 🔍

### Step 1: Run the App
Run your Flutter app in debug mode:
\`\`\`bash
flutter run
\`\`\`

### Step 2: Trigger the Payment
1. Select a PDF file
2. Configure print options
3. Click the "Payment" button
4. Enter code: `0579`
5. Watch the console output

### Step 3: Check the Logs
Look for these emoji markers in the console:

- 🔄 = Process starting
- 📋 = Data being sent
- 📁 = File information
- 📝 = Order creation
- ✅ = Success
- ❌ = **ERROR** (this is what you're looking for!)
- 🌐 = Network request
- 📍 = URL being called
- 📤 = Upload starting
- 📥 = Response received

### Step 4: Identify the Failure Point

#### **If you see:** "❌ ERROR during payment processing"
- Look at the error message right below it
- This will tell you EXACTLY what failed

#### **Common Error Messages:**

1. **"Failed to create order: Connection refused"**
   - ❌ Backend server is not running
   - ✅ **Solution:** Start your backend server

2. **"Failed to create order: 404"**
   - ❌ Backend endpoint doesn't exist
   - ✅ **Solution:** Check backend route configuration

3. **"File upload failed with status 500"**
   - ❌ Backend crashed while processing files
   - ✅ **Solution:** Check backend logs for errors

4. **"SocketException: Network is unreachable"**
   - ❌ Device can't reach the backend
   - ✅ **Solution:** 
     - Verify device is on same network as backend
     - Check IP address is correct
     - Disable firewall temporarily to test

5. **"TimeoutException"**
   - ❌ Backend is too slow or not responding
   - ✅ **Solution:** Check backend server health

---

## Testing Checklist ✓

Before testing, verify:

- [ ] Backend server is running on `http://10.33.125.155:5000`
- [ ] Device/emulator is on the same network
- [ ] Backend has `/create-order` endpoint
- [ ] Backend has `/upload-files` endpoint
- [ ] Backend can handle PDF files
- [ ] Backend returns `orderId` and `pickupCode` in response

---

## Next Steps

1. **Run the app** and try to make a payment
2. **Copy the console logs** (especially the ❌ error messages)
3. **Share the logs** so we can see the exact error
4. Based on the error, we'll fix the specific issue

---

## Quick Backend Test

To test if your backend is reachable, you can use this command in PowerShell:

\`\`\`powershell
Invoke-WebRequest -Uri "http://10.33.125.155:5000/create-order" -Method POST -ContentType "application/json" -Body '{"printSettings":{"test":"data"}}'
\`\`\`

If this fails, your backend is not accessible from your device.

---

## Files Modified

1. `lib/views/screens/payment_processing_page.dart` - Added detailed logging
2. `lib/services/local_upload_service.dart` - Added upload tracking
3. `lib/services/order_service.dart` - Added order creation logging

All changes are **non-breaking** and only add logging for debugging purposes.
