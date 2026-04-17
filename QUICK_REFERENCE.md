# Quick Reference - Pickup Code Interface

## 🚀 Start the System

```bash
# Start backend server
python mock_backend.py

# Open interface
# Double-click: pickup_interface.html
```

## 📋 Workflow

1. **Create Order** → Pickup code printed in terminal
2. **Open Interface** → Enter pickup code
3. **Retrieve Order** → View details
4. **Print Now** → Files copied to auto-print folder
5. **Raspberry Pi** → Automatically prints

## 🔌 Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/create-order` | Create new order |
| POST | `/upload-files` | Upload order files |
| POST | `/get-order` | Get order by pickup code |
| POST | `/trigger-print` | Trigger auto-print |
| GET | `/health` | Health check |

## 📂 Folders

```
uploads/              → Original files
  └── {orderId}/

auto-print/           → Raspberry Pi monitors this
  └── {pickupCode}_{orderId}/
      ├── files...
      └── order_metadata.json
```

## 🎯 Interface Actions

1. **Enter Code** → 4-digit number
2. **Retrieve Order** → Shows order details
3. **Print Now** → Triggers Raspberry Pi

## 🔧 Configuration

### Backend URL
```javascript
// In pickup_interface.html
fetch('http://13.233.76.8:5001/get-order', ...)
fetch('http://13.233.76.8:5001/trigger-print', ...)
```

### Auto-Print Path
```python
# In mock_backend.py
AUTO_PRINT_DIR = 'auto-print'
```

## 📊 Order Metadata (JSON)

```json
{
  "pickupCode": "1234",
  "orderId": "abc-123",
  "totalPages": 10,
  "totalPrice": 50,
  "printSettings": {
    "doubleSide": true,
    "files": [...]
  },
  "triggeredAt": "2026-02-04T18:20:00"
}
```

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Can't connect | Start backend: `python mock_backend.py` |
| Invalid code | Check terminal for correct 4-digit code |
| No files | Ensure files were uploaded first |
| Pi not printing | Check Pi file watcher is running |

## 💡 Tips

- ✅ Keep backend running while using interface
- ✅ Pickup codes are 4 digits (1000-9999)
- ✅ Orders stored in memory (lost on restart)
- ✅ Check terminal for detailed logs
- ✅ Interface works on mobile too!

## 📱 Browser Support

✅ Chrome/Edge  
✅ Firefox  
✅ Safari  
✅ Opera  

## 🎨 Features

- Dark theme with gradients
- Smooth animations
- Auto-focus input
- Real-time validation
- One-click printing
- Status updates
- Error handling

---

**Need more details?** See `PICKUP_INTERFACE_README.md` or `SUMMARY.md`
