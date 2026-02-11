# Order History & Reprint Feature Implementation

## Overview
This implementation adds comprehensive order history tracking with the ability to view active/expired prints and reprint expired orders.

## Features Implemented

### 1. **Order History Tracking**
- All orders are now saved to Cloud Firestore
- Orders include:
  - Order ID and Pickup Code
  - User ID (linked to authenticated user)
  - Creation and expiration timestamps (24-hour expiry)
  - Order status (active, expired, completed, cancelled)
  - Print settings and file information
  - Total pages and price

### 2. **Upload Page Enhancements**
- **Active Prints Section**: Shows up to 3 active orders with:
  - Order ID and creation date
  - Pickup code (prominently displayed)
  - Total pages and price
  - Time remaining until expiration
  
- **Expired Prints Section**: Shows up to 3 expired orders with:
  - Order details
  - "Reprint" button for easy reordering
  
- **History Button**: Added to AppBar for quick access to full history

### 3. **History Page**
A dedicated page with three tabs:
- **Active Tab**: Shows all active (non-expired) orders
- **Expired Tab**: Shows all expired orders with reprint option
- **All Tab**: Shows complete order history

Each order card displays:
- Order ID and status badge
- Pickup code (highlighted)
- Creation and expiration dates
- Total pages and price
- Time remaining (for active orders)
- Action buttons (View Details, Reprint)

### 4. **Reprint Functionality**
- One-click reprint for expired orders
- Creates a new order with:
  - Same print settings
  - New order ID and pickup code
  - Fresh 24-hour expiration
- Confirmation dialog before reprinting
- Success/error feedback

## Files Created

### Models
- **`lib/models/print_order_model.dart`**
  - Complete order data model
  - Status enum (active, expired, completed, cancelled)
  - Firestore serialization/deserialization
  - Helper methods (isExpired, isActive, copyWith)

### Services
- **`lib/services/firestore_service.dart`**
  - Database operations for orders
  - Stream-based real-time updates
  - Methods:
    - `saveOrder()` - Save new order
    - `getUserOrders()` - Get all user orders
    - `getActiveOrders()` - Get active orders only
    - `getExpiredOrders()` - Get expired orders only
    - `reprintOrder()` - Create new order from expired one
    - `updateOrderStatus()` - Update order status
    - `markOrderCompleted()` / `markOrderCancelled()`

### Views
- **`lib/views/screens/history_page.dart`**
  - Tabbed interface for order history
  - Beautiful order cards with status badges
  - Order details modal
  - Reprint confirmation dialog
  - Empty states for each tab

## Files Modified

### 1. **`lib/models/order_model.dart`**
- Added `totalPages` and `totalPrice` fields
- Updated factory constructor

### 2. **`lib/views/screens/upload_page.dart`**
- Added FirestoreService integration
- Added history button to AppBar
- Added active orders section
- Added expired orders section
- Added order card builder
- Added reprint functionality

### 3. **`lib/views/screens/payment_processing_page.dart`**
- Added Firestore save operation after order creation
- Orders are now persisted to database

### 4. **`pubspec.yaml`**
- Added `intl: ^0.19.0` for date formatting

## Database Structure

### Firestore Collection: `orders`
```
orders/
  {orderId}/
    - orderId: string
    - pickupCode: string
    - userId: string
    - createdAt: timestamp
    - expiresAt: timestamp (createdAt + 24 hours)
    - status: string (active/expired/completed/cancelled)
    - printSettings: map
    - totalPages: number
    - totalPrice: number
    - fileUrls: array<string>
```

## Security Considerations

### Firestore Rules (Recommended)
Add these rules to your `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /orders/{orderId} {
      // Users can only read their own orders
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      
      // Users can only create orders for themselves
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      
      // Users can only update their own orders
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
      
      // Users can only delete their own orders
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
  }
}
```

## Usage Flow

### For Users:
1. **Upload files** → Create order → Order saved to Firestore
2. **View active orders** on upload page
3. **See expired orders** with reprint option
4. **Click history icon** to view full order history
5. **Reprint expired orders** with one click

### Order Lifecycle:
1. **Created** → Status: `active`, 24-hour timer starts
2. **Active** → Visible in "Active Prints" section
3. **Expired** → Automatically moves to "Expired Prints" after 24 hours
4. **Reprinted** → New order created with same settings
5. **Completed/Cancelled** → Manual status update (future feature)

## Backend Integration

The backend (`mock_backend.py`) should be updated to return `totalPages` and `totalPrice` in the order response:

```python
response = {
    'orderId': order_id,
    'pickupCode': pickup_code,
    'totalPages': total_pages,
    'totalPrice': total_price
}
```

## Future Enhancements

1. **Order Completion**: Mark orders as completed when picked up
2. **Order Cancellation**: Allow users to cancel active orders
3. **Push Notifications**: Notify users before order expiration
4. **Order Search**: Search orders by ID or pickup code
5. **Order Filters**: Filter by date range, status, price
6. **Export History**: Export order history as PDF/CSV
7. **Reorder with Edits**: Allow editing print settings before reprinting

## Testing Checklist

- [ ] Create new order and verify it appears in active section
- [ ] Verify order appears in history page
- [ ] Wait 24 hours or manually change expiry time to test expiration
- [ ] Test reprint functionality
- [ ] Verify real-time updates (create order in one device, see in another)
- [ ] Test with no orders (empty states)
- [ ] Test with multiple orders
- [ ] Test order details modal
- [ ] Verify Firestore security rules
- [ ] Test offline behavior

## Notes

- Orders expire after 24 hours automatically
- Real-time updates using Firestore streams
- User must be authenticated to view/create orders
- Pickup codes are 4-digit numbers
- All prices in Indian Rupees (₹)
