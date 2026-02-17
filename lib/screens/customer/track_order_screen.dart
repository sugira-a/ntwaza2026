// lib/screens/customer/track_order_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../providers/pickup_order_provider.dart';
import '../../models/pickup_order.dart';

class TrackOrderScreen extends StatefulWidget {
  final String orderId;
  
  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  GoogleMapController? _mapController;
  Timer? _refreshTimer;
  PickupOrder? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    // Refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadOrder());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Do NOT call dispose() on GoogleMapController for web builds.
    // Web implementation may assert if dispose is called before the underlying
    // JS view is ready. Just clear the reference.
    if (!kIsWeb) {
      _mapController?.dispose();
    } else {
      _mapController = null;
    }
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final provider = context.read<PickupOrderProvider>();
      await provider.fetchOrderById(widget.orderId);
      
      if (mounted) {
        setState(() {
          _order = provider.selectedOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final pageColor = isDark ? const Color(0xFF0E0F12) : const Color(0xFFF7F7FA);
    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        title: const Text('Track Order'),
        backgroundColor: pageColor,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _order == null
              ? _buildErrorState()
              : _buildTrackingView(),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Order not found', style: TextStyle(color: colorScheme.onSurface)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingView() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: _buildMap(),
        ),
        Expanded(
          child: _buildOrderDetails(),
        ),
      ],
    );
  }

  Widget _buildMap() {
    final pickupLocation = _order!.pickupLocation;
    final dropoffLocation = _order!.dropoffLocation;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: CameraPosition(
            target: LatLng(pickupLocation.latitude, pickupLocation.longitude),
            zoom: 13,
          ),
          onMapCreated: (controller) => _mapController = controller,
          markers: {
            Marker(
              markerId: const MarkerId('pickup'),
              position: LatLng(
                pickupLocation.latitude,
                pickupLocation.longitude,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'Pickup Location'),
            ),
            Marker(
              markerId: const MarkerId('dropoff'),
              position: LatLng(
                dropoffLocation.latitude,
                dropoffLocation.longitude,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              infoWindow: const InfoWindow(title: 'Dropoff Location'),
            ),
          },
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15171C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Number
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E0F12) : Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Order #${_order!.orderNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Status
            _buildStatusTimeline(),
            
            const SizedBox(height: 24),
            
            // Details
            _buildDetailRow('Items', '${_order!.items.length}', Icons.inventory_2),
            const SizedBox(height: 12),
            _buildDetailRow('Amount', 'RWF ${_order!.amount.toStringAsFixed(0)}', Icons.payment),
            const SizedBox(height: 12),
            _buildDetailRow('Status', _order!.status.toString().split('.').last.toUpperCase(), Icons.info),
            
            if (_order!.riderId != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Rider Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Rider', 'Assigned', Icons.person),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Call rider
                      },
                      icon: const Icon(Icons.phone),
                      label: const Text('Call Rider'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_order!.status == PickupOrderStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Row(
          children: const [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This pickup order was cancelled.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final steps = [
      {
        'status': PickupOrderStatus.pending,
        'title': 'Request Received',
        'description': 'We received your pickup request',
        'icon': Icons.receipt_long,
      },
      {
        'status': PickupOrderStatus.confirmed,
        'title': 'Confirmed',
        'description': 'Your pickup has been confirmed',
        'icon': Icons.verified,
      },
      {
        'status': PickupOrderStatus.assignedToRider,
        'title': 'Rider Assigned',
        'description': 'A rider is heading to the pickup location',
        'icon': Icons.pedal_bike,
      },
      {
        'status': PickupOrderStatus.pickedUp,
        'title': 'Picked Up',
        'description': 'Package picked up successfully',
        'icon': Icons.inventory_2,
      },
      {
        'status': PickupOrderStatus.inTransit,
        'title': 'In Transit',
        'description': 'On the way to the drop-off location',
        'icon': Icons.local_shipping,
      },
      {
        'status': PickupOrderStatus.delivered,
        'title': 'Delivered',
        'description': 'Package delivered to destination',
        'icon': Icons.home,
      },
    ];

    int currentIndex;
    switch (_order!.status) {
      case PickupOrderStatus.pending:
        currentIndex = 0;
        break;
      case PickupOrderStatus.confirmed:
        currentIndex = 1;
        break;
      case PickupOrderStatus.assignedToRider:
        currentIndex = 2;
        break;
      case PickupOrderStatus.pickedUp:
        currentIndex = 3;
        break;
      case PickupOrderStatus.inTransit:
        currentIndex = 4;
        break;
      case PickupOrderStatus.delivered:
        currentIndex = 5;
        break;
      case PickupOrderStatus.cancelled:
        currentIndex = 0;
        break;
    }

    return Column(
      children: List.generate(steps.length, (index) {
        final isCompleted = index < currentIndex;
        final isCurrent = index == currentIndex;
        final step = steps[index];

        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (isCompleted || isCurrent) ? colorScheme.primary : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : step['icon'] as IconData,
                    color: (isCompleted || isCurrent) ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 30,
                    color: isCompleted ? colorScheme.primary : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['title'] as String,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      color: isCompleted || isCurrent
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step['description'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted || isCurrent
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
