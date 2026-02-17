// lib/widgets/vendor_card.dart
// ⭐ SIMPLIFIED - Cleaner design with icons only

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/vendor.dart';

class VendorCard extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback? onTap;

  const VendorCard({super.key, required this.vendor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () {
          context.push('/vendor-detail/${vendor.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _banner(),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Single row: Rating, ETA, Delivery Fee
                  Row(
                    children: [
                      _rating(),
                      const Spacer(),
                      _deliveryTime(),
                      const SizedBox(width: 8),
                      _deliveryFee(),
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

  Widget _banner() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SizedBox(
        height: 120,
        child: Stack(
          children: [
            Positioned.fill(
              child: vendor.bannerUrl != null && vendor.bannerUrl!.isNotEmpty
                  ? Image.network(
                      vendor.bannerUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.store, size: 40, color: Colors.grey),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.store, size: 40, color: Colors.grey),
                    ),
            ),
            // Status badge - based on backend isOpen property
            Positioned(
              top: 6,
              right: 6,
              child: _status(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _status() {
    // Backend controls open/closed status via vendor.isOpen
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: vendor.isOpen ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        vendor.isOpen ? 'OPEN' : 'CLOSED',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _rating() {
    return Row(
      children: [
        const Icon(Icons.star, size: 13, color: Colors.amber),
        const SizedBox(width: 3),
        Text(
          vendor.isNew ? 'New' : vendor.rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        if (vendor.totalRatings > 0) ...[
          const SizedBox(width: 2),
          Text(
            '(${vendor.totalRatings})',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ]
      ],
    );
  }

  Widget _deliveryTime() {
    final displayTime = vendor.estimatedDeliveryDisplay ?? '${vendor.deliveryTime}m';
    
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 13,
          color: vendor.isOpen ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 3),
        Text(
          displayTime,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: vendor.isOpen ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _deliveryFee() {
    return Text(
      'DF ${vendor.deliveryFee.toStringAsFixed(0)}',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.orange,
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  color: Colors.grey[200],
                  child: vendor.logoUrl.isNotEmpty
                      ? Image.network(
                          vendor.logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.restaurant, size: 24, color: Colors.grey[400]);
                          },
                        )
                      : Icon(Icons.restaurant, size: 24, color: Colors.grey[400]),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Info row - icons only
                    Row(
                      children: [
                        const Icon(Icons.star, size: 11, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(vendor.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time, size: 11, color: Colors.green),
                        const SizedBox(width: 2),
                        Text(
                          '${vendor.deliveryTime}m',
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DF ${vendor.deliveryFee.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Status - backend controlled
              if (!vendor.isOpen)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Text(
                    'CLOSED',
                    style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}