// lib/screens/customer/create_pickup_order_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/delivery_address.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pickup_order_provider.dart';
import '../../utils/distance.dart';
import '../../utils/location_validator.dart';
import '../admin/admin_dashboard_pro.dart';

class CreatePickupOrderScreen extends StatefulWidget {
  const CreatePickupOrderScreen({super.key});

  @override
  State<CreatePickupOrderScreen> createState() => _CreatePickupOrderScreenState();
}

class _CreatePickupOrderScreenState extends State<CreatePickupOrderScreen> {
  final TextEditingController _pickupPhoneController = TextEditingController();
  final TextEditingController _dropoffPhoneController = TextEditingController();
  final TextEditingController _packageDescriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _itemValueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DeliveryAddress? _pickupAddress;
  DeliveryAddress? _dropoffAddress;
  DateTime _scheduledPickupTime = DateTime.now().add(const Duration(minutes: 30));
  String _paymentMethod = 'cash';
  bool _isSubmitting = false;
  static const double _baseFee = 1200;
  static const double _perKmFee = 200;
  static const double _distanceThresholdKm = 5;
  static const double _maxTierKm = 15;
  static const double _flatFeeAboveMaxKm = 3500;
  static const double _heavyWeightKg = 10;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.user?.phone != null && auth.user!.phone!.isNotEmpty) {
      _pickupPhoneController.text = auth.user!.phone!;
    }
  }

  @override
  void dispose() {
    _pickupPhoneController.dispose();
    _dropoffPhoneController.dispose();
    _packageDescriptionController.dispose();
    _quantityController.dispose();
    _weightController.dispose();
    _itemValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectPickupLocation() async {
    final result = await context.push('/location-picker');
    if (result != null && result is DeliveryAddress) {
      setState(() => _pickupAddress = result);
    }
  }

  Future<void> _selectDropoffLocation() async {
    final result = await context.push('/location-picker');
    if (result != null && result is DeliveryAddress) {
      setState(() => _dropoffAddress = result);
    }
  }

  Future<void> _selectSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledPickupTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledPickupTime),
    );
    if (time == null) return;

    setState(() {
      _scheduledPickupTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  double _parseMoney(String input) {
    final normalized = input.replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0.0;
  }

  int _parseInt(String input, {int fallback = 1}) {
    final value = int.tryParse(input.trim());
    return value == null || value <= 0 ? fallback : value;
  }

  double _parseDouble(String input) {
    final value = double.tryParse(input.trim());
    return value == null || value <= 0 ? 0.0 : value;
  }

  double? _calculateDistanceKm() {
    if (_pickupAddress == null || _dropoffAddress == null) return null;
    return calculateDistanceKm(
      _pickupAddress!.latitude,
      _pickupAddress!.longitude,
      _dropoffAddress!.latitude,
      _dropoffAddress!.longitude,
    );
  }

  bool _isWithinKigali(DeliveryAddress? address) {
    if (address == null) return false;
    return LocationValidator.isWithinServiceArea(address.latitude, address.longitude);
  }

  double _calculateDeliveryFee() {
    final distance = _calculateDistanceKm();
    if (distance == null) return 0.0;
    if (distance <= _distanceThresholdKm) return _baseFee;
    if (distance <= _maxTierKm) {
      final extraKm = (distance - _distanceThresholdKm).ceil();
      return _baseFee + (extraKm * _perKmFee);
    }
    return _flatFeeAboveMaxKm;
  }

  bool _requiresCallBeforePayment() {
    return _parseDouble(_weightController.text) >= _heavyWeightKg;
  }

  String _generatePickupCode() {
    final random = Random.secure();
    final code = 1000 + random.nextInt(9000);
    return code.toString();
  }

  String? _composeNotes(String? userNotes, String pickupCode, bool requireCall) {
    final parts = <String>[];
    if (userNotes != null && userNotes.trim().isNotEmpty) {
      parts.add(userNotes.trim());
    }
    parts.add('Pickup code: $pickupCode');
    if (requireCall) {
      parts.add('Heavy package: call before payment');
    }
    return parts.join(' | ');
  }

  bool _validate() {
    if (_pickupAddress == null) {
      _showSnack('Select a pickup location to continue');
      return false;
    }
    if (_dropoffAddress == null) {
      _showSnack('Select a dropoff location to continue');
      return false;
    }
    if (_pickupPhoneController.text.trim().isEmpty) {
      _showSnack('Add a pickup phone number');
      return false;
    }
    if (_dropoffPhoneController.text.trim().isEmpty) {
      _showSnack('Add a dropoff phone number');
      return false;
    }
    if (_packageDescriptionController.text.trim().isEmpty) {
      _showSnack('Add a short package description');
      return false;
    }
    if (_parseInt(_quantityController.text) <= 0) {
      _showSnack('Quantity must be at least 1');
      return false;
    }
    if (!_isWithinKigali(_pickupAddress) || !_isWithinKigali(_dropoffAddress)) {
      _showSnack('Pickup and dropoff must be within Kigali');
      return false;
    }
    return true;
  }

  String _buildLocationNotes(DeliveryAddress address) {
    final parts = <String>[];
    if (address.label != null && address.label!.isNotEmpty) {
      parts.add(address.label!);
    }
    if (address.additionalInfo != null && address.additionalInfo!.isNotEmpty) {
      parts.add(address.additionalInfo!);
    }
    return parts.join(' - ');
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.user == null) {
      _showSnack('Please log in to continue');
      context.go('/login');
      return;
    }

    setState(() => _isSubmitting = true);

    final customer = auth.user!;
    final customerName = [customer.firstName, customer.lastName]
        .where((value) => value != null && value!.trim().isNotEmpty)
        .map((value) => value!.trim())
        .join(' ');

    final pickupLocation = {
      'address': _pickupAddress!.fullAddress,
      'latitude': _pickupAddress!.latitude,
      'longitude': _pickupAddress!.longitude,
      'phoneNumber': _pickupPhoneController.text.trim(),
      'notes': _buildLocationNotes(_pickupAddress!),
    };

    final dropoffLocation = {
      'address': _dropoffAddress!.fullAddress,
      'latitude': _dropoffAddress!.latitude,
      'longitude': _dropoffAddress!.longitude,
      'phoneNumber': _dropoffPhoneController.text.trim(),
      'notes': _buildLocationNotes(_dropoffAddress!),
    };

    final items = [
      {
        'id': 'package-1',
        'description': _packageDescriptionController.text.trim(),
        'quantity': _parseInt(_quantityController.text),
        'category': 'package',
        'estimatedWeight': _parseDouble(_weightController.text),
      }
    ];

    final amount = _parseMoney(_itemValueController.text);
    final deliveryFee = _calculateDeliveryFee();

    final provider = context.read<PickupOrderProvider>();
    final requireCall = _requiresCallBeforePayment();
    final pickupCode = _generatePickupCode();
    final paymentMethod = requireCall ? 'cash' : _paymentMethod;
    final notes = _composeNotes(_notesController.text, pickupCode, requireCall);
    final order = await provider.createPickupOrder(
      customerId: customer.id ?? '',
      customerName: customerName.isEmpty ? customer.email : customerName,
      customerPhone: _pickupPhoneController.text.trim(),
      customerEmail: customer.email,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      items: items,
      amount: amount,
      deliveryFee: deliveryFee,
      scheduledPickupTime: _scheduledPickupTime,
      paymentMethod: paymentMethod,
      notes: notes,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (order != null) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pickup Code'),
            content: Text(
              'Share this code with the rider to confirm pickup:\n\n$pickupCode',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
      _showSnack('Pickup order created successfully');
      context.go('/my-orders');
    } else {
      _showSnack(provider.error ?? 'Failed to create pickup order');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.getBackground(context);
    final cardColor = AppColors.getSurface(context);
    final textColor = AppColors.getTextPrimary(context);
    final subtextColor = AppColors.getTextSecondary(context);
    final borderColor = AppColors.getBorder(context);
    final accentColor = AppColors.primary;

    final distanceKm = _calculateDistanceKm();
    final deliveryFee = _calculateDeliveryFee();
    final total = _parseMoney(_itemValueController.text) + deliveryFee;
    final pickupInKigali = _isWithinKigali(_pickupAddress);
    final dropoffInKigali = _isWithinKigali(_dropoffAddress);
    final outsideServiceArea = (_pickupAddress != null && !pickupInKigali) ||
        (_dropoffAddress != null && !dropoffInKigali);
    final requireCall = _requiresCallBeforePayment();
    final effectivePaymentMethod = requireCall ? 'cash' : _paymentMethod;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Ntwaza Now Pickup',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Pickup details', textColor),
            _buildGradientCard(
              Column(
                children: [
                  _buildAddressTile(
                    title: 'Pickup location',
                    subtitle: _pickupAddress?.fullAddress ?? 'Choose pickup point',
                    onTap: _selectPickupLocation,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _pickupPhoneController,
                    label: 'Pickup phone number',
                    hint: 'e.g. 0780000000',
                    keyboardType: TextInputType.phone,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    borderColor: borderColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Dropoff details', textColor),
            _buildGradientCard(
              Column(
                children: [
                  _buildAddressTile(
                    title: 'Dropoff location',
                    subtitle: _dropoffAddress?.fullAddress ?? 'Choose destination',
                    onTap: _selectDropoffLocation,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _dropoffPhoneController,
                    label: 'Dropoff phone number',
                    hint: 'e.g. 0780000000',
                    keyboardType: TextInputType.phone,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    borderColor: borderColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Package details', textColor),
            _buildGradientCard(
              Column(
                children: [
                  _buildTextField(
                    controller: _packageDescriptionController,
                    label: 'Package description',
                    hint: 'Small box, documents, clothing',
                    textColor: textColor,
                    subtextColor: subtextColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _quantityController,
                          label: 'Quantity',
                          hint: '1',
                          keyboardType: TextInputType.number,
                          textColor: textColor,
                          subtextColor: subtextColor,
                          borderColor: borderColor,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _weightController,
                          label: 'Weight (kg)',
                          hint: '2.0',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textColor: textColor,
                          subtextColor: subtextColor,
                          borderColor: borderColor,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _itemValueController,
                    label: 'Package value (RWF)',
                    hint: 'Optional',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textColor: textColor,
                    subtextColor: subtextColor,
                    borderColor: borderColor,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _buildFeeRow(
                    textColor: textColor,
                    subtextColor: subtextColor,
                    accentColor: accentColor,
                    distanceKm: distanceKm,
                    deliveryFee: deliveryFee,
                  ),
                  if (requireCall) ...[
                    const SizedBox(height: 12),
                    _buildCallout(
                      icon: Icons.support_agent,
                      title: 'Heavy package alert',
                      message: 'For large or heavy items, please call us before making payment.',
                      color: accentColor,
                      textColor: textColor,
                      subtextColor: subtextColor,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Schedule', textColor),
            _buildGradientCard(
              Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Pickup time', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${_scheduledPickupTime.toLocal()}'.split('.').first,
                      style: TextStyle(color: subtextColor),
                    ),
                    trailing: TextButton(
                      onPressed: _selectSchedule,
                      child: const Text('Change'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Payment', textColor),
            _buildGradientCard(
              DropdownButtonFormField<String>(
                value: effectivePaymentMethod,
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash on delivery')),
                  DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                ],
                onChanged: requireCall
                    ? null
                    : (value) {
                        if (value != null) setState(() => _paymentMethod = value);
                      },
                decoration: InputDecoration(
                  labelText: 'Payment method',
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
            ),
            if (outsideServiceArea) ...[
              const SizedBox(height: 16),
              _buildCallout(
                icon: Icons.location_off,
                title: 'Outside Kigali service area',
                message: 'Both pickup and dropoff must be within Kigali to place an order.',
                color: Colors.red,
                textColor: textColor,
                subtextColor: subtextColor,
              ),
            ],
            const SizedBox(height: 20),
            _buildSectionTitle('Notes (optional)', textColor),
            _buildGradientCard(
              _buildTextField(
                controller: _notesController,
                label: 'Additional notes',
                hint: 'Pickup instructions or package details',
                textColor: textColor,
                subtextColor: subtextColor,
                borderColor: borderColor,
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 20),
            _buildGradientCard(
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimated total', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                  Text(
                    'RWF ${total.toStringAsFixed(0)}',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting || outsideServiceArea ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide.none,
                  overlayColor: Colors.transparent,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm pickup order', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
      ),
    );
  }

  Widget _buildFeeRow({
    required Color textColor,
    required Color subtextColor,
    required Color accentColor,
    required double? distanceKm,
    required double deliveryFee,
  }) {
    final distanceLabel = distanceKm == null
        ? 'Select pickup and dropoff to calculate'
        : '${distanceKm.toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping, color: accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Distance & fee', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(distanceLabel, style: TextStyle(color: subtextColor, fontSize: 12)),
              ],
            ),
          ),
          Text(
            'RWF ${deliveryFee.toStringAsFixed(0)}',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildCallout({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: subtextColor, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Color cardColor, Color borderColor, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: child,
    );
  }

  Widget _buildGradientCard(Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.green.withOpacity(0.12),
                  Colors.cyan.withOpacity(0.08),
                ]
              : [
                  Colors.green.withOpacity(0.06),
                  Colors.cyan.withOpacity(0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(isDark ? 0.5 : 0.3),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }

  Widget _buildAddressTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textColor,
    required Color subtextColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorder(context), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: subtextColor, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: subtextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color textColor,
    required Color subtextColor,
    required Color borderColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: subtextColor),
        labelStyle: TextStyle(color: subtextColor),
        filled: true,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor, width: 1.5),
        ),
      ),
    );
  }
}
