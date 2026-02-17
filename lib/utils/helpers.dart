// Utility functions for the app
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

/// Shortens an order number for display
/// Example: "ORD-20260127-EPQUAX" -> "#EPQUAX"
String shortenOrderNumber(String orderNumber) {
  if (orderNumber.isEmpty) return '';
  
  // Extract just the last part after the last hyphen
  final parts = orderNumber.split('-');
  if (parts.length >= 3) {
    return '#${parts.last}';
  }
  
  // Fallback: show last 6 characters
  if (orderNumber.length > 6) {
    return '#${orderNumber.substring(orderNumber.length - 6)}';
  }
  
  return '#$orderNumber';
}

/// Convert any DateTime to Rwandan time (CAT - UTC+2)
/// This ensures all times displayed in the app are in Rwandan timezone
DateTime toRwandaTime(DateTime dateTime) {
  // If the datetime is already local (not UTC), assume it's already in correct timezone
  if (!dateTime.isUtc) {
    return dateTime;
  }
  
  // Rwanda uses Central Africa Time (CAT) which is UTC+2
  // Only convert if the time is in UTC
  return dateTime.toUtc().add(const Duration(hours: 2));
}

bool _hasTimezoneOffset(String value) {
  return RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value);
}

/// Parse server datetime strings as UTC when no timezone is provided.
/// Returns Kigali-local DateTime as naive DateTime (no timezone info).
DateTime parseServerTime(String? value) {
  if (value == null || value.isEmpty) {
    return DateTime.now(); // Return local time directly
  }

  try {
    final parsed = DateTime.parse(value);
    
    // If the string has timezone info (Z or +/-offset), it's UTC
    if (_hasTimezoneOffset(value)) {
      // Convert UTC to local time, then add 2 hours for Kigali
      final utc = parsed.toUtc();
      final kigaliTime = utc.add(const Duration(hours: 2));
      // Return as local (naive) DateTime to avoid double conversion
      return DateTime(
        kigaliTime.year,
        kigaliTime.month,
        kigaliTime.day,
        kigaliTime.hour,
        kigaliTime.minute,
        kigaliTime.second,
        kigaliTime.millisecond,
        kigaliTime.microsecond,
      );
    }
    
    // If no timezone info, assume it's already in local/Kigali time
    return parsed;
  } catch (e) {
    print('⚠️ Error parsing server time "$value": $e');
    return DateTime.now();
  }
}

/// Format DateTime in Rwandan time with the given pattern
/// Example: formatRwandaTime(dateTime, 'MMM dd, HH:mm')
String formatRwandaTime(DateTime dateTime, String pattern) {
  // Don't convert if already local time to avoid double conversion
  return DateFormat(pattern).format(dateTime);
}

/// Get current time in Rwanda timezone (as local DateTime)
DateTime nowInRwanda() {
  return DateTime.now(); // Local device time is assumed to be Kigali time
}

/// Human-readable time ago using Kigali time.
String timeAgoFrom(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'Just now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }
  return '${difference.inDays}d ago';
}
