import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rider_provider.dart';

class AdminRidersScreen extends StatefulWidget {
  const AdminRidersScreen({super.key});

  @override
  State<AdminRidersScreen> createState() => _AdminRidersScreenState();
}

class _AdminRidersScreenState extends State<AdminRidersScreen> {
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color pureBlack = Color(0xFF0B0B0B);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color mutedGray = Color(0xFF6B7280);
  static const Color borderGray = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF1F1F1F);
  static const Color cardDark = Color(0xFF111111);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    context.read<RiderProvider>().fetchRiders();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _vehicleCtrl.dispose();
    _licenseCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRider() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'vehicle': _vehicleCtrl.text.trim(),
      'license_number': _licenseCtrl.text.trim(),
      'password': _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
      'role': 'rider',
    }..removeWhere((k, v) => v == null || (v is String && v.isEmpty));

    final ok = await context.read<RiderProvider>().createRider(data);
    setState(() => _submitting = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rider created')));
      _formKey.currentState!.reset();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _vehicleCtrl.clear();
      _licenseCtrl.clear();
      _passwordCtrl.clear();
    } else {
      final err = context.read<RiderProvider>().error ?? 'Failed to create rider';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? pureBlack : const Color(0xFFF4F5F7);
    final cardColor = isDark ? cardDark : Colors.white;
    final textColor = isDark ? pureWhite : pureBlack;
    final subtextColor = isDark ? Colors.white70 : mutedGray;
    final borderColor = isDark ? borderDark : borderGray;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Riders • Admin'),
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: textColor,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Consumer<RiderProvider>(builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (prov.error != null) {
            return Center(child: Text('Error: ${prov.error}', style: TextStyle(color: subtextColor)));
          }
          if (prov.riders.isEmpty) {
            return Center(child: Text('No riders yet', style: TextStyle(color: subtextColor)));
          }
          return ListView.separated(
            itemCount: prov.riders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 18),
            itemBuilder: (context, i) {
              final r = prov.riders[i];
              final orders = r['orders'] as List<dynamic>? ?? [];
              final status = (r['status'] ?? 'offline').toString();
              final statusColor = status == 'online' ? accentGreen : status == 'busy' ? Colors.orange : Colors.grey;
              return Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor.withOpacity(0.13)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: statusColor.withOpacity(0.13),
                          child: Icon(Icons.delivery_dining, color: statusColor, size: 28),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    r['name'] ?? r['email'] ?? 'Rider',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.13),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if ((r['email'] ?? '') != '') Text(r['email'], style: TextStyle(color: subtextColor, fontSize: 13)),
                              if ((r['phone'] ?? '') != '') Text(r['phone'], style: TextStyle(color: subtextColor, fontSize: 13)),
                              if ((r['vehicle'] ?? '') != '') Text('Vehicle: ${r['vehicle']}', style: TextStyle(color: subtextColor, fontSize: 13)),
                              if ((r['license'] ?? '') != '') Text('License: ${r['license']}', style: TextStyle(color: subtextColor, fontSize: 13)),
                              if ((r['rating'] ?? '') != '') Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Text('${r['rating']}', style: TextStyle(fontSize: 13, color: subtextColor)),
                                ],
                              ),
                              if ((r['deliveries'] ?? '') != '') Text('Deliveries: ${r['deliveries']}', style: TextStyle(color: subtextColor, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (orders.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text('Current Orders', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
                      const SizedBox(height: 8),
                      ...orders.map((o) {
                        final overdue = o['overdue'] as int? ?? 0;
                        final eta = o['eta'] as String?;
                        final orderStatus = o['status'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor.withOpacity(0.09)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('#${o['order_number'] ?? o['id']}', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: orderStatus == 'delivered' ? accentGreen.withOpacity(0.13) : Colors.orange.withOpacity(0.13),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(orderStatus.toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: orderStatus == 'delivered' ? accentGreen : Colors.orange)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if ((o['customer'] ?? '') != '') Text('Customer: ${o['customer']}', style: TextStyle(fontSize: 13, color: subtextColor)),
                              if ((o['address'] ?? '') != '') Text('Address: ${o['address']}', style: TextStyle(fontSize: 13, color: subtextColor)),
                              if (eta != null) Text('ETA: $eta', style: TextStyle(fontSize: 13, color: subtextColor)),
                              if (overdue > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Overdue by $overdue min', style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
