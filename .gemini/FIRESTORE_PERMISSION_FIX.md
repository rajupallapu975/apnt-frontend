# Firestore Permission Fix Guide

## Issue
```
W/Firestore: Listen for Query failed: Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}
```

## Root Cause
Firestore security rules are not set up or are in test mode that has expired.

## Solution

### Step 1: Deploy Firestore Security Rules

#### Option A: Using Firebase CLI (Recommended)

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Firebase** (if not already done):
   ```bash
   firebase init firestore
   ```
   - Select your Firebase project
   - Accept default file names (firestore.rules, firestore.indexes.json)

4. **Deploy the rules**:
   ```bash
   firebase deploy --only firestore:rules
   ```

#### Option B: Using Firebase Console (Manual)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Firestore Database** in the left menu
4. Click the **Rules** tab
5. Replace the existing rules with the content from `firestore.rules`
6. Click **Publish**

### Step 2: Verify Rules Are Active

1. In Firebase Console → Firestore Database → Rules
2. You should see:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // ... your rules
     }
   }
   ```

3. Check the "Last published" timestamp - it should be recent

### Step 3: Create Required Indexes

The app now uses simplified queries that don't require complex composite indexes. However, you still need a basic index:

#### Required Index:
- **Collection**: `orders`
- **Fields**:
  1. `userId` (Ascending)
  2. `status` (Ascending)
  3. `createdAt` (Descending)

#### How to Create:

**Option A: Automatic (Recommended)**
1. Run the app
2. When you see an error about missing index, click the link in the error
3. Firebase will create the index automatically

**Option B: Manual**
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Collection ID: `orders`
4. Add fields:
   - `userId` - Ascending
   - `status` - Ascending
   - `createdAt` - Descending
5. Query scope: Collection
6. Click "Create"

### Step 4: Test the Fix

1. **Stop the app** (if running)
2. **Clear app data** on your device:
   - Settings → Apps → Your App → Storage → Clear Data
3. **Run the app again**:
   ```bash
   flutter run
   ```
4. **Sign in** with your Google account
5. **Check for errors** in the console

### Expected Behavior After Fix

✅ No more "PERMISSION_DENIED" errors
✅ Orders appear in the upload page
✅ History page loads correctly
✅ Notifications work properly

## Troubleshooting

### Issue: Rules deployed but still getting permission denied

**Solution**: Clear app cache and restart
```bash
flutter clean
flutter pub get
flutter run
```

### Issue: "Index not found" error

**Solution**: Click the link in the error message to create the index automatically, or create it manually in Firebase Console.

### Issue: Rules show as published but not working

**Solution**: 
1. Check that you're using the correct Firebase project
2. Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is up to date
3. Re-download configuration files from Firebase Console if needed

### Issue: App Check warning

The warning about App Check is not critical for development:
```
W/LocalRequestInterceptor: Error getting App Check token; using placeholder token instead.
```

To fix (optional):
1. Enable App Check in Firebase Console
2. Add App Check to your app
3. For development, use debug tokens

## Security Rules Explanation

### Orders Collection
```javascript
match /orders/{orderId} {
  // Users can only read their own orders
  allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
  
  // Users can only create orders for themselves
  allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
  
  // Users can only update their own orders
  allow update: if isSignedIn() && resource.data.userId == request.auth.uid;
  
  // Users can only delete their own orders
  allow delete: if isSignedIn() && resource.data.userId == request.auth.uid;
}
```

### Notifications Collection
```javascript
match /notifications/{notificationId} {
  // Same pattern as orders - users can only access their own notifications
  allow read, create, update, delete: if isSignedIn() && 
    resource.data.userId == request.auth.uid;
}
```

## Query Optimization Changes

### Before (Required Complex Indexes)
```dart
.where('expiresAt', isGreaterThan: Timestamp.now())
.orderBy('expiresAt')
.orderBy('createdAt', descending: true)
```

### After (Simpler, No Complex Index Needed)
```dart
.orderBy('createdAt', descending: true)
.map((snapshot) {
  // Filter in-memory
  final now = DateTime.now();
  return snapshot.docs
    .map((doc) => PrintOrderModel.fromFirestore(doc))
    .where((order) => order.expiresAt.isAfter(now))
    .toList();
})
```

**Benefits:**
- ✅ No complex composite indexes required
- ✅ Faster deployment (no index build time)
- ✅ Works immediately after rules deployment
- ✅ More flexible for future changes

**Trade-off:**
- Filtering happens in-memory (client-side)
- For large datasets (1000+ orders), consider server-side filtering
- For this app, in-memory filtering is perfectly fine

## Verification Checklist

After deploying rules, verify:

- [ ] Rules are published in Firebase Console
- [ ] "Last published" timestamp is recent
- [ ] Required index is created (userId + status + createdAt)
- [ ] App runs without PERMISSION_DENIED errors
- [ ] Can create new orders
- [ ] Can view order history
- [ ] Can receive notifications

## Additional Notes

### Development vs Production

**Development (Current Setup):**
- Rules allow authenticated users to access their own data
- Good for testing and development

**Production (Future Enhancement):**
- Add rate limiting
- Add data validation
- Add admin-only operations
- Consider Cloud Functions for sensitive operations

### Monitoring

Enable Firestore monitoring in Firebase Console:
1. Go to Firestore Database → Usage
2. Monitor read/write operations
3. Set up billing alerts
4. Watch for unusual patterns

## Quick Fix Commands

```bash
# Deploy rules
firebase deploy --only firestore:rules

# Clean and rebuild app
flutter clean
flutter pub get
flutter run

# Check Firebase project
firebase projects:list
firebase use <project-id>
```

## Support

If issues persist:
1. Check Firebase Console → Firestore → Rules → Playground
2. Test your queries in the Rules Playground
3. Verify user authentication is working
4. Check device logs for detailed error messages
