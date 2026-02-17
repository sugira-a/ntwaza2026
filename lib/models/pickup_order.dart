// lib/models/pickup_order.dart
import 'package:intl/intl.dart';
import '../utils/helpers.dart';

enum PickupOrderStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  assignedToRider('Assigned to Rider'),
  pickedUp('Picked Up'),
  inTransit('In Transit'),
  delivered('Delivered'),
  cancelled('Cancelled');

  final String displayName;
  const PickupOrderStatus(this.displayName);
}

class Location {
  final String address;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final String? notes;

  Location({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.notes,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      phoneNumber: json['phoneNumber'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phoneNumber': phoneNumber,
      'notes': notes,
    };
  }
}

class PickupItem {
  final String id;
  final String description;
  final int quantity;
  final String category;
  final double estimatedWeight; // in kg

  PickupItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.category,
    required this.estimatedWeight,
  });

  factory PickupItem.fromJson(Map<String, dynamic> json) {
    return PickupItem(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      category: json['category'] as String? ?? '',
      estimatedWeight: (json['estimatedWeight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'quantity': quantity,
      'category': category,
      'estimatedWeight': estimatedWeight,
    };
  }
}

class PickupOrder {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final Location pickupLocation;
  final Location dropoffLocation;
  final List<PickupItem> items;
  final double amount;
  final double deliveryFee;
  final double totalAmount;
  final PickupOrderStatus status;
  final DateTime scheduledPickupTime;
  final DateTime? scheduledDeliveryTime;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final String paymentMethod;
  final String? paymentStatus;
  final bool isPaid;
  final String? notes;
  final double? riderLatitude;
  final double? riderLongitude;

  PickupOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.items,
    required this.amount,
    required this.deliveryFee,
    required this.totalAmount,
    required this.status,
    required this.scheduledPickupTime,
    this.scheduledDeliveryTime,
    required this.createdAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.riderId,
    this.riderName,
    this.riderPhone,
    required this.paymentMethod,
    this.paymentStatus,
    this.isPaid = false,
    this.notes,
    this.riderLatitude,
    this.riderLongitude,
  });

  // Computed properties
  String get statusDisplay => status.displayName;

  String get itemCountDisplay => '${items.fold<int>(0, (sum, item) => sum + item.quantity)} items';

  String get totalWeightKg =>
      items.fold<double>(0, (sum, item) => sum + (item.estimatedWeight * item.quantity)).toStringAsFixed(2);

  String get formattedScheduledTime =>
      formatRwandaTime(scheduledPickupTime, 'MMM dd, yyyy HH:mm');

  bool get canAssignRider => status == PickupOrderStatus.confirmed;
  bool get canStartPickup => status == PickupOrderStatus.assignedToRider;
  bool get canCompletePickup => status == PickupOrderStatus.pickedUp;
  bool get canCompleteDelivery => status == PickupOrderStatus.inTransit;
  bool get canCancel => status == PickupOrderStatus.pending || status == PickupOrderStatus.confirmed;

  factory PickupOrder.fromJson(Map<String, dynamic> json) {
    return PickupOrder(
      id: json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      customerEmail: json['customerEmail'] as String? ?? '',
      pickupLocation: Location.fromJson(json['pickupLocation'] as Map<String, dynamic>? ?? {}),
      dropoffLocation: Location.fromJson(json['dropoffLocation'] as Map<String, dynamic>? ?? {}),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => PickupItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(json['status'] as String?),
      scheduledPickupTime: parseServerTime(json['scheduledPickupTime'] as String? ?? ''),
      scheduledDeliveryTime:
          DateTime.tryParse(json['scheduledDeliveryTime'] as String? ?? ''),
      createdAt: parseServerTime(json['createdAt'] as String? ?? ''),
      acceptedAt: DateTime.tryParse(json['acceptedAt'] as String? ?? ''),
      pickedUpAt: DateTime.tryParse(json['pickedUpAt'] as String? ?? ''),
      deliveredAt: DateTime.tryParse(json['deliveredAt'] as String? ?? ''),
      riderId: json['riderId'] as String?,
      riderName: json['riderName'] as String?,
      riderPhone: json['riderPhone'] as String?,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      paymentStatus: json['paymentStatus'] as String?,
      isPaid: json['isPaid'] as bool? ?? false,
      notes: json['notes'] as String?,
      riderLatitude: (json['riderLatitude'] as num?)?.toDouble(),
      riderLongitude: (json['riderLongitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'pickupLocation': pickupLocation.toJson(),
      'dropoffLocation': dropoffLocation.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'amount': amount,
      'deliveryFee': deliveryFee,
      'totalAmount': totalAmount,
      'status': status.name,
      'scheduledPickupTime': scheduledPickupTime.toIso8601String(),
      'scheduledDeliveryTime': scheduledDeliveryTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'riderId': riderId,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'isPaid': isPaid,
      'notes': notes,
      'riderLatitude': riderLatitude,
      'riderLongitude': riderLongitude,
    };
  }

  PickupOrder copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    Location? pickupLocation,
    Location? dropoffLocation,
    List<PickupItem>? items,
    double? amount,
    double? deliveryFee,
    double? totalAmount,
    PickupOrderStatus? status,
    DateTime? scheduledPickupTime,
    DateTime? scheduledDeliveryTime,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    String? riderId,
    String? riderName,
    String? riderPhone,
    String? paymentMethod,
    String? paymentStatus,
    bool? isPaid,
    String? notes,
    double? riderLatitude,
    double? riderLongitude,
  }) {
    return PickupOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      items: items ?? this.items,
      amount: amount ?? this.amount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      scheduledPickupTime: scheduledPickupTime ?? this.scheduledPickupTime,
      scheduledDeliveryTime: scheduledDeliveryTime ?? this.scheduledDeliveryTime,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isPaid: isPaid ?? this.isPaid,
      notes: notes ?? this.notes,
      riderLatitude: riderLatitude ?? this.riderLatitude,
      riderLongitude: riderLongitude ?? this.riderLongitude,
    );
  }
}

PickupOrderStatus _parseStatus(String? status) {
  if (status == null) return PickupOrderStatus.pending;
  
  try {
    return PickupOrderStatus.values.firstWhere(
      (s) => s.name == status.toLowerCase(),
      orElse: () => PickupOrderStatus.pending,
    );
  } catch (e) {
    return PickupOrderStatus.pending;
  }
}
