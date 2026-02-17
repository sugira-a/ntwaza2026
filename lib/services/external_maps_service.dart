// lib/services/external_maps_service.dart
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class ExternalMapsService {
  static final _logger = Logger();

  /// Open any location in Google Maps
  /// Reduces API calls by using external app
  static Future<bool> openLocationInMaps({
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    try {
      final mapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
      );

      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(
          mapsUrl,
          mode: LaunchMode.externalApplication,
        );
        _logger.i('Opened maps location: $label');
        return true;
      } else {
        _logger.w('Could not launch Google Maps');
        return false;
      }
    } catch (e) {
      _logger.e('Error opening location: $e');
      return false;
    }
  }

  /// Open customer location in Google Maps
  /// Reduces API calls by using external app
  static Future<bool> openCustomerLocationInMaps({
    required double latitude,
    required double longitude,
    required String customerName,
  }) async {
    try {
      final mapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
      );

      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(
          mapsUrl,
          mode: LaunchMode.externalApplication,
        );
        _logger.i('📍 Opened customer location in Google Maps: $customerName');
        return true;
      } else {
        _logger.w('⚠️ Could not launch Google Maps');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error opening customer location: $e');
      return false;
    }
  }

  /// Open vendor location in Google Maps
  /// Reduces API calls by using external app
  static Future<bool> openVendorLocationInMaps({
    required double latitude,
    required double longitude,
    required String vendorName,
  }) async {
    try {
      final mapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
      );

      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(
          mapsUrl,
          mode: LaunchMode.externalApplication,
        );
        _logger.i('🏪 Opened vendor location in Google Maps: $vendorName');
        return true;
      } else {
        _logger.w('⚠️ Could not launch Google Maps');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error opening vendor location: $e');
      return false;
    }
  }

  /// Open directions from rider location to destination
  static Future<bool> openDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String destName,
  }) async {
    try {
      final mapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng'
      );

      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(
          mapsUrl,
          mode: LaunchMode.externalApplication,
        );
        _logger.i('🗺️ Opened directions to: $destName');
        return true;
      } else {
        _logger.w('⚠️ Could not launch Google Maps');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error opening directions: $e');
      return false;
    }
  }

  /// Call customer
  static Future<bool> callCustomer(String phoneNumber) async {
    try {
      final uri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _logger.i('📞 Calling customer: $phoneNumber');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error calling customer: $e');
      return false;
    }
  }

  /// WhatsApp message to customer
  static Future<bool> sendWhatsAppMessage(String phoneNumber, String message) async {
    try {
      final uri = Uri.parse(
        'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}'
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger.i('💬 Sent WhatsApp to: $phoneNumber');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error sending WhatsApp: $e');
      return false;
    }
  }
}
