// lib/widgets/vendor_card.dart
// Clean, professional card design

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/vendor.dart';

class VendorCard extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback? onTap;

  const VendorCard({super.key, required this.vendor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final borderCol = isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade200;
    final statusColor = vendor.isOpen
        ? (isDarkMode ? const Color(0xFF81C784) : const Color(0xFF4CAF50))
        : (isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF9E9E9E));

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.15 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () {
          context.push('/vendor-detail/${vendor.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 120,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: vendor.isOpen
                            ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                            : ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                        child: vendor.bannerUrl != null && vendor.bannerUrl!.isNotEmpty
                            ? Image.network(
                                vendor.bannerUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[200],
                                    child: Icon(Icons.store_outlined, size: 36, color: subtextColor),
                                  );
                                },
                              )
                            : Container(
                                color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[200],
                                child: Icon(Icons.store_outlined, size: 36, color: subtextColor),
                              ),
                      ),
                    ),
                    // Status badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5, height: 5,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              vendor.isOpen ? 'Open' : 'Closed',
                              style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Row 1: Rating | Distance
                  Row(
                    children: [
                      Expanded(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star_rounded, size: 12, color: isDarkMode ? const Color(0xFFFFD54F) : Colors.amber.shade700),
                          const SizedBox(width: 3),
                          Text(
                            vendor.isNew ? 'New' : vendor.rating.toStringAsFixed(1),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor),
                          ),
                          if (vendor.totalRatings > 0)
                            Text(' (${vendor.totalRatings})', style: TextStyle(fontSize: 10, color: subtextColor.withOpacity(0.7))),
                        ]),
                      ),
                      Expanded(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.near_me_outlined, size: 11, color: subtextColor),
                          const SizedBox(width: 3),
                          Flexible(child: Text(vendor.formattedDistance, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor), overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Row 2: Delivery time | Delivery fee
                  Row(
                    children: [
                      Expanded(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.schedule_outlined, size: 11, color: subtextColor),
                          const SizedBox(width: 3),
                          Flexible(child: Text(vendor.formattedDeliveryTime, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subtextColor), overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                      Expanded(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            'DF ${vendor.deliveryFee.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDarkMode ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32)),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// COMPACT VERSION FOR LISTS
// =====================================================

class VendorCardCompact extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback? onTap;

  const VendorCardCompact({super.key, required this.vendor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final borderCol = isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade200;
    final statusColor = vendor.isOpen
        ? (isDarkMode ? const Color(0xFF81C784) : const Color(0xFF4CAF50))
        : (isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF9E9E9E));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.12 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap ?? () {
          context.push('/vendor-detail/${vendor.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 50,
                  height: 50,
                  color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
                  child: vendor.logoUrl.isNotEmpty
                      ? Image.network(
                          vendor.logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.store_outlined, size: 22, color: subtextColor);
                          },
                        )
                      : Icon(Icons.store_outlined, size: 22, color: subtextColor),
                ),
              ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor, letterSpacing: -0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 11, color: isDarkMode ? const Color(0xFFFFD54F) : Colors.amber.shade700),
                        const SizedBox(width: 2),
                        Text(vendor.rating.toStringAsFixed(1), style: TextStyle(fontSize: 10, color: subtextColor, fontWeight: FontWeight.w500)),
                        Text('  ·  ', style: TextStyle(color: subtextColor.withOpacity(0.5), fontSize: 10)),
                        Text(
                          'DF ${vendor.deliveryFee.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 10, color: subtextColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Status indicator - subtle dot
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}