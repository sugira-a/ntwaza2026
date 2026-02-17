import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../utils/helpers.dart';

/// Order tracking timeline widget showing order progress with estimated time
class OrderTrackingTimeline extends StatelessWidget {
  final Order order;
  final bool showEstimatedTime;

  const OrderTrackingTimeline({
    super.key,
    required this.order,
    this.showEstimatedTime = true,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _getTrackingSteps();
    final currentStepIndex = _getCurrentStepIndex();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showEstimatedTime && currentStepIndex < steps.length - 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          _getEstimatedTime(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Progress line
            Row(
              children: List.generate(
                steps.length,
                (index) => Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: index <= currentStepIndex
                          ? Colors.green
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Timeline steps
            ...List.generate(steps.length, (index) {
              final step = steps[index];
              final isCompleted = index < currentStepIndex;
              final isCurrent = index == currentStepIndex;
              final isPending = index > currentStepIndex;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step indicator
                    Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCompleted || isCurrent
                                ? Colors.green
                                : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCompleted
                                ? Icons.check
                                : isCurrent
                                    ? step['icon']
                                    : step['icon'],
                            color: isCompleted || isCurrent
                                ? Colors.white
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                        ),
                        if (index < steps.length - 1)
                          Container(
                            width: 2,
                            height: 30,
                            color: index < currentStepIndex
                                ? Colors.green
                                : Colors.grey.shade300,
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    
                    // Step content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['title'],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCompleted || isCurrent
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isCompleted || isCurrent
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade500,
                            ),
                          ),
                          if (step['timestamp'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              formatRwandaTime(step['timestamp'], 'MMM dd, h:mm a'),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (isCurrent && showEstimatedTime) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getTrackingSteps() {
    return [
      {
        'icon': Icons.receipt,
        'title': 'Order Placed',
        'description': 'Your order has been received',
        'timestamp': order.createdAt,
      },
      {
        'icon': Icons.restaurant,
        'title': 'Preparing Food',
        'description': '${order.vendorName} is preparing your order',
        'timestamp': order.status.value == 'pending' ? null : order.createdAt,
      },
      {
        'icon': Icons.check_circle,
        'title': 'Ready for Pickup',
        'description': 'Order is ready, waiting for rider',
        'timestamp': order.readyAt,
      },
      {
        'icon': Icons.delivery_dining,
        'title': 'On the Way',
        'description': 'Rider is delivering your order',
        'timestamp': order.acceptedAt,
      },
      {
        'icon': Icons.home,
        'title': 'Delivered',
        'description': 'Order delivered successfully',
        'timestamp': order.completedAt,
      },
    ];
  }

  int _getCurrentStepIndex() {
    switch (order.status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        return 1;
      case OrderStatus.ready:
        return 2;
      case OrderStatus.pickedUp:
        return 3;
      case OrderStatus.completed:
        return 4;
      default:
        return 0;
    }
  }

  String _getEstimatedTime() {
    final now = nowInRwanda();
    final orderCreated = toRwandaTime(order.createdAt);
    final orderAge = now.difference(orderCreated).inMinutes;
    
    switch (order.status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        final prepTime = 20 - orderAge; // Assume 20 min prep time
        return prepTime > 0 ? '~$prepTime min' : 'Soon';
      
      case OrderStatus.ready:
        return '~5-10 min'; // Waiting for rider
        
      case OrderStatus.pickedUp:
        return '~10-15 min'; // Delivery time
        
      default:
        return 'Completed';
    }
  }
}
