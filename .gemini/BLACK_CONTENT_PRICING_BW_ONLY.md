# Black Content Pricing - B&W Only

## Important: Color Prints Are NOT Affected

**Black content detection and dynamic pricing ONLY applies to Black & White (B&W) prints.**

Color prints always use standard pricing regardless of black content.

## Pricing Logic

### Black & White Prints
- **Normal content** (<60% black): ₹3 per page
- **High black content** (>60% black): ₹6 per page (2x multiplier)

### Color Prints
- **Any content**: ₹10 per page (no multiplier applied)

## Why This Makes Sense

### B&W Printing
- Uses toner/ink based on coverage
- High black content = more toner used
- Double pricing compensates for higher toner cost

### Color Printing
- Already priced higher (₹10 vs ₹3)
- Uses multiple color cartridges
- Black content doesn't significantly impact cost
- Pricing already accounts for full coverage

## Code Implementation

```dart
// FileVerificationService
double getPriceMultiplier(double blackContentPercentage, {bool isColor = false}) {
  // Black content pricing only applies to B&W prints
  if (isColor) {
    return 1.0; // No multiplier for color prints
  }
  return blackContentPercentage > 60 ? 2.0 : 1.0;
}
```

## Example Scenarios

### Scenario 1: Text Document (B&W)
- Content: Mostly white with black text (30% black)
- Price: ₹3 per page (standard B&W)

### Scenario 2: Filled Form (B&W)
- Content: Heavy black areas (70% black)
- Price: ₹6 per page (2x multiplier)
- Warning: "High black content detected. Price will be doubled."

### Scenario 3: Color Photo
- Content: Any amount of black
- Price: ₹10 per page (standard color, no multiplier)

### Scenario 4: Color Document with Black Background
- Content: 80% black background
- Price: ₹10 per page (color pricing, no multiplier)

## User Experience

### B&W Print with High Black Content
1. User selects file
2. System analyzes black content → 65%
3. Warning shown: "⚠️ High black content detected (65%). Price will be doubled for this page."
4. User sees: ₹6 instead of ₹3
5. User can choose to:
   - Proceed with current file
   - Modify file to reduce black content
   - Convert to color (if appropriate)

### Color Print
1. User selects file
2. System analyzes black content (for information only)
3. No warning shown
4. Price: ₹10 (standard color pricing)

## Backend Integration

### Order Creation Request
```json
{
  "printSettings": {
    "files": [
      {
        "fileIndex": 0,
        "pageCount": 1,
        "color": "BW",
        "blackContentPercentage": 65.0,
        "copies": 1
      }
    ]
  }
}
```

### Backend Pricing Logic
```python
for file_info in files:
    is_color = file_info.get('color') == 'COLOR'
    black_percentage = file_info.get('blackContentPercentage', 0)
    
    # Base price
    unit_price = 10 if is_color else 3
    
    # Apply black content multiplier ONLY for B&W
    if not is_color and black_percentage > 60:
        unit_price *= 2
        print(f"⚫ High black content ({black_percentage}%) - B&W price doubled!")
    
    file_price = unit_price * page_count * copies
```

## Benefits

### For Users
- ✅ Fair pricing based on actual resource usage
- ✅ Clear warnings before ordering
- ✅ Option to optimize files to save money
- ✅ Color prints not penalized

### For Business
- ✅ Covers increased toner costs for heavy B&W prints
- ✅ Encourages efficient file preparation
- ✅ Transparent pricing model
- ✅ Competitive color pricing maintained

## Testing

### Test Cases

1. **B&W Text Document**
   - Expected: Standard ₹3 pricing
   - Black content: ~20-40%

2. **B&W Filled Form**
   - Expected: Double ₹6 pricing
   - Black content: >60%

3. **Color Photo**
   - Expected: Standard ₹10 pricing
   - Black content: Any %

4. **Color Document with Black Background**
   - Expected: Standard ₹10 pricing
   - Black content: >60% (but ignored)

## Future Enhancements

1. **Adjustable Threshold**: Allow admin to change 60% threshold
2. **Graduated Pricing**: Multiple tiers instead of just 2x
   - 40-60%: 1.5x
   - 60-80%: 2x
   - >80%: 2.5x

3. **Optimization Suggestions**: 
   - "Your file has 70% black content. Consider using outline text to reduce to 40% and save ₹3 per page."

4. **Preview**: Show before/after pricing when toggling B&W vs Color

## Summary

- ✅ Black content pricing = B&W prints only
- ✅ Color prints = Always standard pricing
- ✅ Fair and transparent
- ✅ Encourages optimization
- ✅ Covers business costs
