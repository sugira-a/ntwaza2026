// lib/providers/address_provider.dart
// Updated with centralized Kigali validation

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/delivery_address.dart';
import '../utils/location_validator.dart';

class AddressProvider with ChangeNotifier {
  List<DeliveryAddress> _savedAddresses = [];
  DeliveryAddress? _selectedAddress;
  bool _isLoading = false;

  List<DeliveryAddress> get savedAddresses => _savedAddresses;
  DeliveryAddress? get selectedAddress => _selectedAddress;
  DeliveryAddress? get defaultAddress =>
      _savedAddresses.where((a) => a.isDefault).firstOrNull;
  bool get isLoading => _isLoading;
  bool get hasAddresses => _savedAddresses.isNotEmpty;

  // Initialize and load saved addresses
  Future<void> initialize() async {
    await loadAddresses();
  }

  // Load addresses from SharedPreferences
  Future<void> loadAddresses() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final addressesJson = prefs.getString('saved_addresses');

      if (addressesJson != null) {
        final List<dynamic> decoded = json.decode(addressesJson);
        final allAddresses = decoded
            .map((json) => DeliveryAddress.fromJson(json))
            .toList();

        // FILTER OUT addresses outside Kigali using centralized validator
        _savedAddresses = allAddresses.where((address) {
          final isValid = LocationValidator.isWithinServiceArea(
            address.latitude, 
            address.longitude
          );
          
          if (!isValid) {
            final distance = LocationValidator.getDistanceFromKigali(
              address.latitude, 
              address.longitude
            );
            print('⚠️ Filtered out address outside Kigali: ${address.shortAddress} '
                  '(${distance.toStringAsFixed(1)}km from center)');
          }
          return isValid;
        }).toList();

        // Sort by last used date (most recent first)
        _savedAddresses.sort((a, b) {
          if (a.lastUsedAt == null) return 1;
          if (b.lastUsedAt == null) return -1;
          return b.lastUsedAt!.compareTo(a.lastUsedAt!);
        });

        // Save the filtered list back to prefs (removes invalid addresses permanently)
        if (_savedAddresses.length != allAddresses.length) {
          await _saveToPrefs();
          print('🗑️ Removed ${allAddresses.length - _savedAddresses.length} addresses outside service area');
        }

        print('✅ Loaded ${_savedAddresses.length} valid addresses in Kigali');
      }
    } catch (e) {
      print('❌ Error loading addresses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save addresses to SharedPreferences
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressesJson =
          json.encode(_savedAddresses.map((a) => a.toJson()).toList());
      await prefs.setString('saved_addresses', addressesJson);
      print('✅ Saved ${_savedAddresses.length} addresses');
    } catch (e) {
      print('❌ Error saving addresses: $e');
    }
  }

  // Add new address with validation
  Future<void> addAddress(DeliveryAddress address) async {
    try {
      // VALIDATE: Check if address is in Kigali
      final validation = LocationValidator.validate(
        address.latitude, 
        address.longitude
      );
      
      if (!validation.isValid) {
        print('❌ Cannot add address outside Kigali: ${address.shortAddress}');
        throw Exception(validation.message);
      }

      // If this is the first address, make it default
      if (_savedAddresses.isEmpty) {
        address = address.copyWith(isDefault: true);
      }

      // If setting as default, remove default from others
      if (address.isDefault) {
        _savedAddresses = _savedAddresses
            .map((a) => a.copyWith(isDefault: false))
            .toList();
      }

      // Check if address already exists (same coordinates)
      final existingIndex = _savedAddresses.indexWhere((a) =>
          (a.latitude - address.latitude).abs() < 0.0001 &&
          (a.longitude - address.longitude).abs() < 0.0001);

      if (existingIndex != -1) {
        // Update existing address
        _savedAddresses[existingIndex] = address.copyWith(
          lastUsedAt: DateTime.now(),
        );
        print('📍 Updated existing address in Kigali (${validation.distanceFromCenter.toStringAsFixed(1)}km from center)');
      } else {
        // Add new address
        _savedAddresses.insert(
          0,
          address.copyWith(lastUsedAt: DateTime.now()),
        );
        print('📍 Added new address in Kigali (${validation.distanceFromCenter.toStringAsFixed(1)}km from center)');
      }

      await _saveToPrefs();
      notifyListeners();
    } catch (e) {
      print('❌ Error adding address: $e');
      rethrow; // Re-throw so UI can handle it
    }
  }

  // Update address with validation
  Future<void> updateAddress(DeliveryAddress address) async {
    try {
      // VALIDATE: Check if address is in Kigali
      final validation = LocationValidator.validate(
        address.latitude, 
        address.longitude
      );
      
      if (!validation.isValid) {
        print('❌ Cannot update to address outside Kigali: ${address.shortAddress}');
        throw Exception(validation.message);
      }

      final index = _savedAddresses.indexWhere((a) => a.id == address.id);
      if (index != -1) {
        // If setting as default, remove default from others
        if (address.isDefault) {
          _savedAddresses = _savedAddresses
              .map((a) => a.copyWith(isDefault: false))
              .toList();
        }

        _savedAddresses[index] = address;
        await _saveToPrefs();
        notifyListeners();
        print('✅ Updated address: ${address.id}');
      }
    } catch (e) {
      print('❌ Error updating address: $e');
      rethrow;
    }
  }

  // Delete address
  Future<void> deleteAddress(String addressId) async {
    try {
      final address = _savedAddresses.firstWhere((a) => a.id == addressId);
      final wasDefault = address.isDefault;

      _savedAddresses.removeWhere((a) => a.id == addressId);

      // If deleted address was default, make first address default
      if (wasDefault && _savedAddresses.isNotEmpty) {
        _savedAddresses[0] = _savedAddresses[0].copyWith(isDefault: true);
      }

      await _saveToPrefs();
      notifyListeners();
      print('✅ Deleted address: $addressId');
    } catch (e) {
      print('❌ Error deleting address: $e');
    }
  }

  // Set default address
  Future<void> setDefaultAddress(String addressId) async {
    try {
      _savedAddresses = _savedAddresses.map((a) {
        return a.copyWith(isDefault: a.id == addressId);
      }).toList();

      await _saveToPrefs();
      notifyListeners();
      print('✅ Set default address: $addressId');
    } catch (e) {
      print('❌ Error setting default address: $e');
    }
  }

  // Mark address as used (updates lastUsedAt)
  Future<void> markAddressAsUsed(String addressId) async {
    try {
      final index = _savedAddresses.indexWhere((a) => a.id == addressId);
      if (index != -1) {
        _savedAddresses[index] = _savedAddresses[index].copyWith(
          lastUsedAt: DateTime.now(),
        );

        // Move to top of list
        final address = _savedAddresses.removeAt(index);
        _savedAddresses.insert(0, address);

        await _saveToPrefs();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error marking address as used: $e');
    }
  }

  // Select address for current order with validation
  void selectAddress(DeliveryAddress address) {
    // VALIDATE before selecting
    if (!LocationValidator.isWithinServiceArea(address.latitude, address.longitude)) {
      print('❌ Cannot select address outside Kigali: ${address.shortAddress}');
      return;
    }
    
    _selectedAddress = address;
    notifyListeners();
  }

  // Clear selected address
  void clearSelection() {
    _selectedAddress = null;
    notifyListeners();
  }

  // Get recently used addresses (last 5, only those in Kigali)
  List<DeliveryAddress> get recentAddresses {
    return _savedAddresses
        .where((a) => LocationValidator.isWithinServiceArea(a.latitude, a.longitude))
        .take(5)
        .toList();
  }

  // Clean up invalid addresses (can be called manually if needed)
  Future<void> cleanupInvalidAddresses() async {
    try {
      final originalCount = _savedAddresses.length;
      _savedAddresses = _savedAddresses
          .where((a) => LocationValidator.isWithinServiceArea(a.latitude, a.longitude))
          .toList();
      
      if (_savedAddresses.length < originalCount) {
        await _saveToPrefs();
        notifyListeners();
        print('🗑️ Cleaned up ${originalCount - _savedAddresses.length} invalid addresses');
      }
    } catch (e) {
      print('❌ Error cleaning up addresses: $e');
    }
  }
}