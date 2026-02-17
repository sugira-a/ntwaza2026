// lib/models/order.dart - COMPLETE FIXED VERSION
import '../utils/helpers.dart';
class Order {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String vendorId;
  final String vendorName;
  final String? vendorPhone;
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final OrderStatus status;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final List<OrderItem> items;
  final DeliveryInfo? deliveryInfo;
  final String? specialInstructions;
  final String paymentMethod;
  final String? paymentStatus;
  // 🆕 Vendor location for maps
  final double? latitude;
  final double? longitude;
  // 🆕 Vendor location fields
  final double? vendorLatitude;
  final double? vendorLongitude;
  // 🆕 ETA & Late Tracking
  final DateTime? estimatedArrivalTime;
  final int? minutesRemaining;
  final bool isRunningLate;
  final double deliveryDistanceKm;

  Order({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.vendorId,
    required this.vendorName,
    this.vendorPhone,
    this.riderId,
    this.riderName,
    this.riderPhone,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.createdAt,
    this.acceptedAt,
    this.readyAt,
    this.completedAt,
    required this.items,
    this.deliveryInfo,
    this.specialInstructions,
    required this.paymentMethod,
    this.paymentStatus,
    this.latitude,
    this.longitude,
    this.vendorLatitude,
    this.vendorLongitude,
    this.estimatedArrivalTime,
    this.minutesRemaining,
    this.isRunningLate = false,
    this.deliveryDistanceKm = 0.0,
  });

  // Helper getters
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  
  String get statusDisplay => status.displayName;
  
  String get timeAgo {
    return timeAgoFrom(createdAt);
  }

  // ✅ UPDATED: Use 'confirmed' instead of 'accepted'
  bool get canAccept => status == OrderStatus.pending;
  bool get canReject => status == OrderStatus.pending;
  bool get canMarkPreparing => status == OrderStatus.confirmed;
  bool get canMarkReady => status == OrderStatus.preparing;
  bool get canMarkCompleted => status == OrderStatus.ready;

  factory Order.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse double values
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    final dynamic riderObj = json['rider'];
    final Map<String, dynamic>? rider =
        riderObj is Map ? Map<String, dynamic>.from(riderObj) : null;
    
    return Order(
      id: json['id']?.toString() ?? json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber'] ?? json['order_number'] ?? json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? json['customer_id']?.toString() ?? '',
      customerName: json['customerName'] ?? json['customer_name'] ?? 'Customer',
      customerPhone: json['customerPhone'] ?? json['customer_phone'],
      vendorId: json['vendorId']?.toString() ?? json['vendor_id']?.toString() ?? '',
      vendorName: json['vendorName'] ?? json['vendor_name'] ?? '',
      vendorPhone: json['vendorPhone'] ?? json['vendor_phone'],
      riderId: json['riderId']?.toString() ?? json['rider_id']?.toString() ?? rider?['id']?.toString(),
      riderName: json['riderName'] ?? json['rider_name'] ?? rider?['name'],
      riderPhone: json['riderPhone'] ?? json['rider_phone'] ?? rider?['phone'],
      status: OrderStatus.fromString(json['status'] ?? 'pending'),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? json['delivery_fee'] ?? 0).toDouble(),
      total: (json['totalPrice'] ?? json['total'] ?? 0).toDouble(),
        createdAt: parseServerTime(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
        acceptedAt: json['acceptedAt'] != null
          ? parseServerTime(json['acceptedAt'])
          : json['accepted_at'] != null
            ? parseServerTime(json['accepted_at'])
            : null,
        readyAt: json['readyAt'] != null
          ? parseServerTime(json['readyAt'])
          : json['ready_at'] != null
            ? parseServerTime(json['ready_at'])
            : null,
        completedAt: json['completedAt'] != null
          ? parseServerTime(json['completedAt'])
          : json['completed_at'] != null
            ? parseServerTime(json['completed_at'])
            : null,
      items: (json['items'] as List?)?.map((i) => OrderItem.fromJson(i)).toList() ?? [],
      deliveryInfo: json['delivery_info'] != null 
        ? DeliveryInfo.fromJson(json['delivery_info']) 
        : (json['deliveryAddress'] != null || json['deliveryLatitude'] != null)
          ? DeliveryInfo(
              address: json['deliveryAddress'] ?? json['delivery_address'] ?? '',
              latitude: parseDouble(json['deliveryLatitude'] ?? json['delivery_latitude']),
              longitude: parseDouble(json['deliveryLongitude'] ?? json['delivery_longitude']),
            )
          : null,
      specialInstructions: json['specialInstructions'] ?? json['special_instructions'],
      paymentMethod: json['paymentMethod'] ?? json['payment_method'] ?? 'cash',
      paymentStatus: json['paymentStatus'] ?? json['payment_status'],
      latitude: parseDouble(json['latitude'] ?? json['deliveryLatitude']),
      longitude: parseDouble(json['longitude'] ?? json['deliveryLongitude']),
      vendorLatitude: parseDouble(json['vendorLatitude'] ?? json['vendor_latitude']),
      vendorLongitude: parseDouble(json['vendorLongitude'] ?? json['vendor_longitude']),
        estimatedArrivalTime: json['estimatedArrivalTime'] != null
          ? parseServerTime(json['estimatedArrivalTime'])
          : json['estimated_arrival_time'] != null
            ? parseServerTime(json['estimated_arrival_time'])
            : null,
      minutesRemaining: json['minutesRemaining'] ?? json['minutes_remaining'],
      isRunningLate: json['isRunningLate'] ?? json['is_running_late'] ?? false,
      deliveryDistanceKm: (json['deliveryDistance'] ?? json['delivery_distance_km'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'vendor_phone': vendorPhone,
      'rider_id': riderId,
      'rider_name': riderName,
      'rider_phone': riderPhone,
      'status': status.value,
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'total': total,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'ready_at': readyAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
      'delivery_info': deliveryInfo?.toJson(),
      'special_instructions': specialInstructions,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'latitude': latitude,
      'longitude': longitude,
      'vendor_latitude': vendorLatitude,
      'vendor_longitude': vendorLongitude,
      'estimated_arrival_time': estimatedArrivalTime?.toIso8601String(),
      'minutes_remaining': minutesRemaining,
      'is_running_late': isRunningLate,
      'delivery_distance_km': deliveryDistanceKm,
    };
  }
}

// ✅ FIXED: Order Status Enum - matches backend status values
// ✅ FIXED: Order Status Enum - matches backend status values
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  pickedUp,
  completed,
  cancelled;
  
  String get value {
    switch (this) {
      case OrderStatus.pending: return 'pending';
      case OrderStatus.confirmed: return 'confirmed';
      case OrderStatus.preparing: return 'preparing';
      case OrderStatus.ready: return 'ready';
      case OrderStatus.pickedUp: return 'picked_up';
      case OrderStatus.completed: return 'completed';
      case OrderStatus.cancelled: return 'cancelled';
    }
  }
  
  // ✅ Added displayName getter
  String get displayName {
    switch (this) {
      case OrderStatus.pending: return 'Pending';
      case OrderStatus.confirmed: return 'Confirmed';
      case OrderStatus.preparing: return 'Preparing';
      case OrderStatus.ready: return 'Ready';
      case OrderStatus.pickedUp: return 'Picked Up';
      case OrderStatus.completed: return 'Completed';
      case OrderStatus.cancelled: return 'Cancelled';
    }
  }
  
  static OrderStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
      case 'ready_for_pickup':
        return OrderStatus.ready;
      case 'picked_up':
      case 'in_transit':
      case 'out_for_delivery':
        return OrderStatus.pickedUp;
      case 'completed':
      case 'delivered':
        return OrderStatus.completed;
      case 'canceled':
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

// Order Item
class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final String? imageUrl;
  final int quantity;
  final double price;
  final double total;
  final String? notes;
  final List<OrderItemModifier>? modifiers;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.imageUrl,
    required this.quantity,
    required this.price,
    required this.total,
    this.notes,
    this.modifiers,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? json['product_id']?.toString() ?? '',
      productName: json['name'] ?? json['productName'] ?? json['product_name'] ?? 'Item',
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? json['product_image'],
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? json['unit_price'] ?? 0).toDouble(),
      total: (json['total'] ?? json['total_price'] ?? (json['price'] ?? 0) * (json['quantity'] ?? 1)).toDouble(),
      notes: json['notes'] ?? json['special_instructions'],
      modifiers: (json['modifiers'] as List?)
        ?.map((m) => OrderItemModifier.fromJson(m))
        .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'image_url': imageUrl,
      'quantity': quantity,
      'price': price,
      'total': total,
      'notes': notes,
      'modifiers': modifiers?.map((m) => m.toJson()).toList(),
    };
  }
}

// Order Item Modifier
class OrderItemModifier {
  final String name;
  final String value;
  final double priceAdjustment;

  OrderItemModifier({
    required this.name,
    required this.value,
    required this.priceAdjustment,
  });

  factory OrderItemModifier.fromJson(Map<String, dynamic> json) {
    return OrderItemModifier(
      name: json['name'] ?? '',
      value: json['value'] ?? '',
      priceAdjustment: (json['price_adjustment'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'price_adjustment': priceAdjustment,
    };
  }
}

// Delivery Info
class DeliveryInfo {
  final String address;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;

  DeliveryInfo({
    required this.address,
    this.latitude,
    this.longitude,
    this.notes,
    this.driverId,
    this.driverName,
    this.driverPhone,
  });

  factory DeliveryInfo.fromJson(Map<String, dynamic> json) {
    return DeliveryInfo(
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      notes: json['notes'],
      driverId: json['driver_id']?.toString(),
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'driver_id': driverId,
      'driver_name': driverName,
      'driver_phone': driverPhone,
    };
  }
}
