# Pickup Code Interface

A beautiful web interface for entering pickup codes to retrieve print orders.

## Features

✨ **Modern Design**
- Premium dark theme with gradient accents
- Smooth animations and micro-interactions
- Responsive layout that works on all devices
- Glassmorphism effects

🔐 **Secure Input**
- 4-digit code validation
- Number-only input
- Real-time validation

📊 **Order Details**
- View Order ID
- Check order status
- See total pages and price
- Instant retrieval

## How to Use

### 1. Start the Backend Server

First, make sure your backend server is running:

```bash
python mock_backend.py
```

The server will start on `http://localhost:5000`

### 2. Open the Interface

Open `pickup_interface.html` in your web browser. You can either:
- Double-click the file to open it in your default browser
- Right-click and choose "Open with" to select a specific browser
- Serve it using a local web server (recommended for production)

### 3. Enter Pickup Code

1. The pickup code input field will be automatically focused
2. Enter the 4-digit pickup code that was printed in the terminal when an order was created
3. Click "Retrieve Order" or press Enter
4. The order details will be displayed if the code is valid

## Workflow Example

### Complete Workflow with Auto-Print (Raspberry Pi)

1. **Create an Order** (via your Flutter app or API):
   - User uploads files and creates a print order
   - Backend saves files to `uploads/{orderId}/`
   - Backend generates and prints pickup code in terminal
   - Example: `🔑 Pickup Code: 1234`

2. **Retrieve and Print the Order** (via the web interface):
   - Open `pickup_interface.html` in your browser
   - Enter the pickup code: `1234`
   - Click "Retrieve Order" to view order details
   - Click "🖨️ Print Now" button
   - Backend copies files to `auto-print/{pickupCode}_{orderId}/`
   - Raspberry Pi monitors the `auto-print` folder
   - Raspberry Pi detects new files and automatically prints them

### How the Auto-Print Works

The backend creates an `auto-print` directory that your Raspberry Pi should monitor. When you click "Print Now":

1. All order files are copied from `uploads/{orderId}/` to `auto-print/{pickupCode}_{orderId}/`
2. A `order_metadata.json` file is created with print settings
3. Your Raspberry Pi script detects the new folder
4. Raspberry Pi reads the metadata and prints the files accordingly

### Setting Up Raspberry Pi Auto-Print

Configure your Raspberry Pi to monitor the `auto-print` folder:

```python
# Example Raspberry Pi script (pseudo-code)
import os
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class PrintHandler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            # New order folder detected
            order_folder = event.src_path
            metadata_file = os.path.join(order_folder, 'order_metadata.json')
            
            # Wait for all files to be copied
            time.sleep(2)
            
            # Read metadata and print files
            # ... your printing logic here

# Monitor the auto-print folder
observer = Observer()
observer.schedule(PrintHandler(), path='/path/to/auto-print', recursive=False)
observer.start()
```

## API Integration

The interface connects to the backend endpoint:

```
POST http://localhost:5000/get-order
```

**Request Body:**
```json
{
  "pickupCode": "1234"
}
```

**Response (Success):**
```json
{
  "success": true,
  "data": {
    "orderId": "abc-123-def-456",
    "pickupCode": "1234",
    "totalPages": 10,
    "totalPrice": 50,
    "status": "Ready for Pickup",
    "createdAt": "2026-02-04T12:00:00"
  }
}
```

**Response (Error):**
```json
{
  "success": false,
  "message": "Invalid pickup code. Order not found."
}
```

### Trigger Print Endpoint

```
POST http://localhost:5000/trigger-print
```

**Request Body:**
```json
{
  "pickupCode": "1234"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Print job triggered successfully",
  "filesCount": 3,
  "orderDetails": {
    "orderId": "abc-123-def-456",
    "totalPages": 10,
    "totalPrice": 50
  }
}
```

**Response (Error):**
```json
{
  "success": false,
  "message": "Invalid pickup code. Order not found."
}
```

## Customization

### Change Backend URL

If your backend is running on a different host or port, update line 436 in `pickup_interface.html`:

```javascript
const response = await fetch('http://YOUR_HOST:YOUR_PORT/get-order', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
    },
    body: JSON.stringify({ pickupCode })
});
```

### Styling

All styles are contained in the `<style>` section of the HTML file. You can customize:
- Colors (CSS variables in `:root`)
- Animations
- Layout
- Typography

## Browser Compatibility

The interface works on all modern browsers:
- Chrome/Edge (recommended)
- Firefox
- Safari
- Opera

## Notes

- The backend stores orders in memory, so they will be lost when the server restarts
- For production use, consider implementing a database
- CORS is enabled on the backend for testing purposes
- The interface uses the Fetch API for HTTP requests

## Troubleshooting

**"Unable to connect to server"**
- Make sure the backend server is running
- Check that the backend URL is correct
- Verify CORS is enabled on the backend

**"Invalid pickup code"**
- Ensure the order was created successfully
- Check the terminal output for the correct pickup code
- Verify the code is exactly 4 digits

**Order not displaying**
- Check the browser console for errors (F12)
- Verify the backend response format matches the expected structure
