// lib/models/delivery_address.dart
import '../utils/helpers.dart';

class DeliveryAddress {
  final String id;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String? label; // 'Home', 'Work', 'Other'
  final String? additionalInfo; // Apartment number, gate code, etc.
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  DeliveryAddress({
    required this.id,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    this.label,
    this.additionalInfo,
    this.isDefault = false,
    required this.createdAt,
    this.lastUsedAt,
  });

  // Create from JSON
  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id'] ?? '',
      fullAddress: json['full_address'] ?? json['fullAddress'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      label: json['label'],
      additionalInfo: json['additional_info'] ?? json['additionalInfo'],
      isDefault: json['is_default'] ?? json['isDefault'] ?? false,
        createdAt: json['created_at'] != null
          ? parseServerTime(json['created_at'])
          : nowInRwanda(),
        lastUsedAt: json['last_used_at'] != null
          ? parseServerTime(json['last_used_at'])
          : null,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_address': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
      'additional_info': additionalInfo,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'last_used_at': lastUsedAt?.toIso8601String(),
    };
  }

  // Create copy with updated fields
  DeliveryAddress copyWith({
    String? id,
    String? fullAddress,
    double? latitude,
    double? longitude,
    String? label,
    String? additionalInfo,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return DeliveryAddress(
      id: id ?? this.id,
      fullAddress: fullAddress ?? this.fullAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  // Get short address (first line)
  String get shortAddress {
    final parts = fullAddress.split(',');
    return parts.isNotEmpty ? parts[0].trim() : fullAddress;
  }

  // Get display name
  String get displayName {
    if (label != null && label!.isNotEmpty) {
      return '$label - $shortAddress';
    }
    return shortAddress;
  }

  @override
  String toString() {
    return 'DeliveryAddress(id: $id, address: $fullAddress, label: $label)';
  }
}