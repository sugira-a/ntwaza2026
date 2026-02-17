// lib/models/user_model.dart
import 'package:flutter/material.dart';

class UserModel {
  final String? id;
  final String email;
  final String? role;
  final String? token;
  
  // Personal Information
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? alternativePhone;
  final String? address;
  final String? city;
  final String? country;
  final String? postalCode;
  
  // Profile
  final String? profileImage;
  
  // Account Status
  final bool? isVerified;
  final bool? isActive;
  final bool? emailVerified;
  final bool? phoneVerified;
  
  // Notifications
  final bool? pushEnabled;
  
  // Vendor Information (if role is vendor)
  final String? businessName;
  final String? businessType;
  final String? vendorType;
  final String? vendorCategory;
  final bool? usesMenuSystem;
  final bool? isOpen;
  final bool? acceptsOrders;
  final double? avgRating;
  final int? totalReviews;
  final double? latitude;
  final double? longitude;
  final String? businessAddress;
  final double? deliveryRadius;
  final double? minimumOrder;
  final double? deliveryFee;
  final String? logo;
  final String? banner;
  
  // Rider Information (if role is rider)
  final String? riderId;
  final String? riderApplicationStatus;
  final bool? onboardingCompleted;
  final bool? isOnline;
  final String? driverStatus;
  final String? vehicleType;
  final int? totalDeliveries;
  final int? completedDeliveries;
  final double? rating;
  final int? totalRatings;
  
  // Timestamps
  final String? createdAt;
  final String? updatedAt;
  final String? lastLogin;

  UserModel({
    this.id,
    required this.email,
    this.role,
    this.token,
    this.firstName,
    this.lastName,
    this.phone,
    this.alternativePhone,
    this.address,
    this.city,
    this.country,
    this.postalCode,
    this.profileImage,
    this.isVerified,
    this.isActive,
    this.emailVerified,
    this.phoneVerified,
    this.pushEnabled,
    this.businessName,
    this.businessType,
    this.vendorType,
    this.vendorCategory,
    this.usesMenuSystem,
    this.isOpen,
    this.acceptsOrders,
    this.avgRating,
    this.totalReviews,
    this.latitude,
    this.longitude,
    this.businessAddress,
    this.deliveryRadius,
    this.minimumOrder,
    this.deliveryFee,
    this.logo,
    this.banner,
    this.riderId,
    this.riderApplicationStatus,
    this.onboardingCompleted,
    this.isOnline,
    this.driverStatus,
    this.vehicleType,
    this.totalDeliveries,
    this.completedDeliveries,
    this.rating,
    this.totalRatings,
    this.createdAt,
    this.updatedAt,
    this.lastLogin,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"]?.toString(),
      email: json["email"] ?? '',
      role: json["role"],
      token: json["token"] ?? json["access_token"],
      
      // Personal Information
      firstName: json["first_name"],
      lastName: json["last_name"],
      phone: json["phone"],
      alternativePhone: json["alternative_phone"],
      address: json["address"],
      city: json["city"],
      country: json["country"],
      postalCode: json["postal_code"],
      
      // Profile
      profileImage: json["profile_image"],
      
      // Account Status
      isVerified: json["is_verified"],
      isActive: json["is_active"],
      emailVerified: json["email_verified"],
      phoneVerified: json["phone_verified"],
      
      // Notifications
      pushEnabled: json["push_enabled"],
      
      // Vendor Information
      businessName: json["business_name"],
      businessType: json["business_type"],
      vendorType: json["vendor_type"],
      vendorCategory: json["vendor_category"],
      usesMenuSystem: json["uses_menu_system"],
      isOpen: json["is_open"],
      acceptsOrders: json["accepts_orders"],
      avgRating: json["avg_rating"]?.toDouble(),
      totalReviews: json["total_reviews"],
      latitude: json["latitude"]?.toDouble(),
      longitude: json["longitude"]?.toDouble(),
      businessAddress: json["business_address"],
      deliveryRadius: json["delivery_radius"]?.toDouble(),
      minimumOrder: json["minimum_order"]?.toDouble(),
      deliveryFee: json["delivery_fee"]?.toDouble(),
      logo: json["logo"],
      banner: json["banner"],
      
      // Rider Information
      riderId: json["rider_id"],
      riderApplicationStatus: json["rider_application_status"],
      onboardingCompleted: json["onboarding_completed"],
      isOnline: json["is_online"],
      driverStatus: json["driver_status"],
      vehicleType: json["vehicle_type"],
      totalDeliveries: json["total_deliveries"],
      completedDeliveries: json["completed_deliveries"],
      rating: json["rating"]?.toDouble(),
      totalRatings: json["total_ratings"],
      
      // Timestamps
      createdAt: json["created_at"],
      updatedAt: json["updated_at"],
      lastLogin: json["last_login"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "email": email,
      "role": role,
      "token": token,
      "first_name": firstName,
      "last_name": lastName,
      "phone": phone,
      "alternative_phone": alternativePhone,
      "address": address,
      "city": city,
      "country": country,
      "postal_code": postalCode,
      "profile_image": profileImage,
      "is_verified": isVerified,
      "is_active": isActive,
      "email_verified": emailVerified,
      "phone_verified": phoneVerified,
      "push_enabled": pushEnabled,
      "business_name": businessName,
      "business_type": businessType,
      "vendor_type": vendorType,
      "vendor_category": vendorCategory,
      "uses_menu_system": usesMenuSystem,
      "is_open": isOpen,
      "accepts_orders": acceptsOrders,
      "avg_rating": avgRating,
      "total_reviews": totalReviews,
      "latitude": latitude,
      "longitude": longitude,
      "business_address": businessAddress,
      "delivery_radius": deliveryRadius,
      "minimum_order": minimumOrder,
      "delivery_fee": deliveryFee,
      "logo": logo,
      "banner": banner,
      "rider_id": riderId,
      "rider_application_status": riderApplicationStatus,
      "onboarding_completed": onboardingCompleted,
      "is_online": isOnline,
      "driver_status": driverStatus,
      "vehicle_type": vehicleType,
      "total_deliveries": totalDeliveries,
      "completed_deliveries": completedDeliveries,
      "rating": rating,
      "total_ratings": totalRatings,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "last_login": lastLogin,
    };
  }
  
  // Helper getters
  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  
  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (businessName != null) return businessName!;
    return email.split('@').first;
  }
  
  bool get isCustomer => role == 'customer' || role == null;
  bool get isVendor => role == 'vendor';
  bool get isRider => role == 'rider' || role == 'driver';
  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';

  // Profile image helpers
  String? get profileImageUrl {
    if (profileImage == null) return null;
    
    // If it's a full URL, return as is
    if (profileImage!.startsWith('http')) {
      return profileImage;
    }
    
    // If it's an icon avatar
    if (isIconAvatar) {
      return null; // No URL for icon avatars
    }
    
    // If it's a path, construct the full URL
    return profileImage;
  }

  // Check if profile image is an icon avatar
  bool get isIconAvatar {
    if (profileImage == null) return true;
    final iconAvatars = ['male1', 'male2', 'male3', 'female1', 'female2', 'female3'];
    return iconAvatars.contains(profileImage);
  }

  // Get icon for avatar
  IconData get avatarIcon {
    if (profileImage == 'male1') return Icons.person;
    if (profileImage == 'male2') return Icons.face;
    if (profileImage == 'male3') return Icons.boy;
    if (profileImage == 'female1') return Icons.person_outline;
    if (profileImage == 'female2') return Icons.face_outlined;
    if (profileImage == 'female3') return Icons.girl;
    return Icons.person;
  }

  // Manual copyWith method
  UserModel copyWith({
    String? id,
    String? email,
    String? role,
    String? token,
    String? firstName,
    String? lastName,
    String? phone,
    String? alternativePhone,
    String? address,
    String? city,
    String? country,
    String? postalCode,
    String? profileImage,
    bool? isVerified,
    bool? isActive,
    bool? emailVerified,
    bool? phoneVerified,
    bool? pushEnabled,
    String? businessName,
    String? businessType,
    String? vendorType,
    String? vendorCategory,
    bool? usesMenuSystem,
    bool? isOpen,
    bool? acceptsOrders,
    double? avgRating,
    int? totalReviews,
    double? latitude,
    double? longitude,
    String? businessAddress,
    double? deliveryRadius,
    double? minimumOrder,
    double? deliveryFee,
    String? logo,
    String? banner,
    String? riderApplicationStatus,
    bool? onboardingCompleted,
    bool? isOnline,
    String? driverStatus,
    String? vehicleType,
    int? totalDeliveries,
    int? completedDeliveries,
    double? rating,
    int? totalRatings,
    String? createdAt,
    String? updatedAt,
    String? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      token: token ?? this.token,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      alternativePhone: alternativePhone ?? this.alternativePhone,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      profileImage: profileImage ?? this.profileImage,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      vendorType: vendorType ?? this.vendorType,
      vendorCategory: vendorCategory ?? this.vendorCategory,
      usesMenuSystem: usesMenuSystem ?? this.usesMenuSystem,
      isOpen: isOpen ?? this.isOpen,
      acceptsOrders: acceptsOrders ?? this.acceptsOrders,
      avgRating: avgRating ?? this.avgRating,
      totalReviews: totalReviews ?? this.totalReviews,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      businessAddress: businessAddress ?? this.businessAddress,
      deliveryRadius: deliveryRadius ?? this.deliveryRadius,
      minimumOrder: minimumOrder ?? this.minimumOrder,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      logo: logo ?? this.logo,
      banner: banner ?? this.banner,
      riderApplicationStatus: riderApplicationStatus ?? this.riderApplicationStatus,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isOnline: isOnline ?? this.isOnline,
      driverStatus: driverStatus ?? this.driverStatus,
      vehicleType: vehicleType ?? this.vehicleType,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      completedDeliveries: completedDeliveries ?? this.completedDeliveries,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}