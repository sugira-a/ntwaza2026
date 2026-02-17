# Working Hours & Online/Offline Status System

## Overview
Complete rebuild of the working hours and online/offline status system using **Kigali Time (EAT, UTC+2)** consistently throughout.

## Key Components

### 1. Timezone Utility (`app/utils/timezone.py`)
- **`now_kigali()`**: Returns current Kigali time as naive datetime
- **`to_kigali_naive(dt)`**: Converts any datetime to Kigali time
- **`serialize_datetime_utc(dt)`**: Serializes datetime to ISO format with UTC indicator

### 2. User Model Methods (`app/models/user.py`)

#### `is_within_working_hours(kigali_now=None)`
Checks if vendor is within working hours based on Kigali time.
- Returns `True` if vendor should be open based on day and time
- Handles manual closed override
- Supports overnight hours (e.g., 22:00 - 02:00)
- Returns `True` by default if no hours are configured

#### `update_vendor_status(kigali_now=None)`
Updates vendor's `is_open` and `accepts_orders` flags based on:
1. Account active status
2. Manual closed override  
3. Working hours

#### `set_manual_closed(is_closed)`
Sets or clears the manual closed override flag.

### 3. Vendor Routes (`app/web/vendor.py`)

#### `/working-hours` (GET/POST)
- Displays and updates working hours
- Shows current status using Kigali time
- Preserves manual closed status when updating hours
- Provides detailed debug information

#### `/business-hours` (GET/POST)
- Alternative route for restaurant profile
- Same functionality as `/working-hours`
- AJAX-compatible for smooth updates

#### `/toggle-status` (POST)
- Toggles online/offline status (manual override)
- Updates vendor status automatically
- Returns JSON for AJAX requests

#### `/profile/restaurant/status` (POST)
- Restaurant-specific status toggle
- Handles both JSON and form data
- Returns comprehensive status information

#### `/status-check` (GET)
- Diagnostic endpoint for debugging
- Shows all status factors
- Lists reasons for closed status

### 4. Templates

#### `vendor/working_hours.html`
- Full working hours editor
- Shows Kigali time prominently
- Timezone indicator: "EAT, UTC+2"
- Real-time status updates
- Debug mode with `?debug=1`

#### `vendor/business_hours.html`
- Restaurant-focused hours editor
- Timezone-aware messaging
- AJAX form submission

## Timezone Handling

All times are in **Kigali Time (EAT, UTC+2)**:
- Database stores hours as HH:MM strings (no timezone)
- Comparison always uses Kigali time via `now_kigali()`
- UI clearly indicates timezone
- No UTC conversion confusion

## Status Logic

A vendor is **OPEN** when ALL of these are true:
1. ✅ Account is active (`is_active = True`)
2. ✅ Not manually closed (`_manual_closed` not set)
3. ✅ Within working hours for current Kigali day/time

A vendor is **CLOSED** if ANY of these:
1. ❌ Account inactive
2. ❌ Manually closed by vendor
3. ❌ Outside working hours

## Working Hours Structure

```json
{
  "monday": {
    "open": true,
    "open_time": "09:00",
    "close_time": "17:00"
  },
  "tuesday": {
    "open": true,
    "open_time": "09:00",
    "close_time": "17:00"
  },
  // ... other days
  "_manual_closed": false  // Optional override flag
}
```

## Testing

### Check Vendor Status
```
GET /web/vendor/status-check
```

Returns:
- Current Kigali time
- Account status
- Manual closed flag
- Working hours status
- Reasons for closed status

### Debug Mode
Add `?debug=1` to working hours page:
```
GET /web/vendor/working-hours?debug=1
```

Shows detailed debug panel with all status factors.

## API Integration

For mobile apps / external systems:
- Use `is_open` and `accepts_orders` fields
- Always check `vendor.is_within_working_hours(now_kigali())` 
- Respect manual closed override

## Migration Notes

### Previous Issues Fixed:
1. ✅ Mixed timezone handling (UTC vs Kigali)
2. ✅ Inconsistent working hours checking
3. ✅ Manual override not properly saved
4. ✅ Status not updating after hours change
5. ✅ No clear timezone indicators in UI

### Changes Made:
1. ✅ Centralized working hours logic in User model
2. ✅ Consistent Kigali time usage everywhere
3. ✅ Proper manual closed handling
4. ✅ Automatic status updates
5. ✅ Clear timezone labeling in UI

## Future Enhancements

Possible additions:
- Holiday/special hours
- Break times (lunch break)
- Seasonal hours
- Multiple shift support
- Auto-close if no staff available
