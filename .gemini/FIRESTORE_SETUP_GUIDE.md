# Firestore Setup Guide

## Prerequisites
- Firebase project already configured (firebase_options.dart exists)
- Cloud Firestore enabled in Firebase Console

## Step 1: Enable Cloud Firestore

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click on **Firestore Database** in the left menu
4. Click **Create Database**
5. Choose **Start in test mode** (for development)
6. Select a location (choose closest to your users)
7. Click **Enable**

## Step 2: Configure Firestore Security Rules

1. In Firebase Console, go to **Firestore Database** → **Rules**
2. Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Orders collection
    match /orders/{orderId} {
      // Users can only read their own orders
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      
      // Users can only create orders for themselves
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid &&
                       request.resource.data.keys().hasAll(['orderId', 'pickupCode', 'userId', 'createdAt', 'expiresAt', 'status', 'printSettings', 'totalPages', 'totalPrice']);
      
      // Users can only update their own orders (status changes)
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
      
      // Users can only delete their own orders
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
  }
}
```

3. Click **Publish**

## Step 3: Create Indexes (Optional but Recommended)

For better query performance, create composite indexes:

### Index 1: Active Orders Query
- **Collection**: `orders`
- **Fields**:
  1. `userId` (Ascending)
  2. `status` (Ascending)
  3. `expiresAt` (Ascending)
  4. `createdAt` (Descending)

### Index 2: Expired Orders Query
- **Collection**: `orders`
- **Fields**:
  1. `userId` (Ascending)
  2. `status` (Ascending)
  3. `expiresAt` (Descending)

### Index 3: All User Orders Query
- **Collection**: `orders`
- **Fields**:
  1. `userId` (Ascending)
  2. `createdAt` (Descending)

**Note**: Firebase will automatically prompt you to create these indexes when you first run queries that need them. You can click the link in the error message to create them automatically.

## Step 4: Test the Setup

1. Run the app
2. Create a test order
3. Go to Firebase Console → Firestore Database
4. You should see a new document in the `orders` collection
5. Verify the document structure matches the expected format

## Firestore Data Structure

### Collection: `orders`

Each document represents a print order:

```json
{
  "orderId": "abc123...",
  "pickupCode": "1234",
  "userId": "user_firebase_uid",
  "createdAt": Timestamp,
  "expiresAt": Timestamp,
  "status": "active",
  "printSettings": {
    "doubleSide": false,
    "files": [
      {
        "fileIndex": 0,
        "pageNumber": 1,
        "pageCount": 5,
        "isPdf": true,
        "color": "COLOR",
        "orientation": "PORTRAIT",
        "copies": 1
      }
    ]
  },
  "totalPages": 5,
  "totalPrice": 50.0,
  "fileUrls": []
}
```

## Security Best Practices

1. **Never use test mode in production**
   - Test mode allows anyone to read/write data
   - Always use proper security rules

2. **Validate data on write**
   - Ensure required fields are present
   - Validate data types
   - Check field values are within acceptable ranges

3. **Use Firebase Authentication**
   - All queries check `request.auth.uid`
   - Users can only access their own data

4. **Monitor usage**
   - Set up billing alerts
   - Monitor read/write operations
   - Watch for suspicious activity

## Troubleshooting

### Error: "Missing or insufficient permissions"
- **Cause**: Security rules are blocking the operation
- **Solution**: Check that the user is authenticated and rules allow the operation

### Error: "The query requires an index"
- **Cause**: Composite index not created
- **Solution**: Click the link in the error message to create the index automatically

### Orders not appearing in real-time
- **Cause**: Network issues or Firestore offline mode
- **Solution**: Check internet connection, verify Firestore is enabled

### Expired orders not showing
- **Cause**: Timestamp comparison issue
- **Solution**: Verify device time is correct, check query logic

## Cost Optimization

### Free Tier Limits (Spark Plan)
- 50,000 reads/day
- 20,000 writes/day
- 20,000 deletes/day
- 1 GB storage

### Tips to Stay Within Free Tier
1. **Use pagination**: Limit query results with `.limit()`
2. **Cache data**: Use local caching to reduce reads
3. **Batch operations**: Group multiple writes together
4. **Delete old data**: Regularly clean up expired orders
5. **Monitor usage**: Set up alerts in Firebase Console

### Estimated Usage for This App
- **Per order**: 1 write (create) + ~10 reads (viewing history)
- **100 orders/day**: ~100 writes + ~1,000 reads
- **Well within free tier** for small to medium usage

## Migration from Test Mode to Production

When ready for production:

1. **Update security rules** (as shown above)
2. **Test thoroughly** with different user accounts
3. **Set up monitoring** in Firebase Console
4. **Enable billing** (optional, for scaling)
5. **Set up backups** (Firestore automatic backups)

## Additional Resources

- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Pricing Calculator](https://firebase.google.com/pricing)
- [Best Practices](https://firebase.google.com/docs/firestore/best-practices)
