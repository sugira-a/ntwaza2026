// lib/screens/customer/create_pickup_order_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/delivery_address.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pickup_order_provider.dart';
import '../../utils/distance.dart';
import '../../utils/location_validator.dart';
import '../../services/google_maps_service.dart';
import '../admin/admin_dashboard_pro.dart';

class CreatePickupOrderScreen extends StatefulWidget {
  const CreatePickupOrderScreen({super.key});

  @override
  State<CreatePickupOrderScreen> createState() => _CreatePickupOrderScreenState();
}

class _CreatePickupOrderScreenState extends State<CreatePickupOrderScreen> {
  final TextEditingController _senderNameController = TextEditingController();
  final TextEditingController _pickupPhoneController = TextEditingController();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _dropoffPhoneController = TextEditingController();
  final TextEditingController _packageDescriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _itemValueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedPackageType = 'Small box';

  DeliveryAddress? _pickupAddress;
  DeliveryAddress? _dropoffAddress;
  DateTime _scheduledPickupTime = DateTime.now().add(const Duration(minutes: 30));
  String _paymentMethod = 'cash';
  bool _isSubmitting = false;
  bool _isCalculatingDistance = false;
  Map<String, dynamic>? _roadDistanceData;

  // Pricing — loaded from backend (admin-editable), with safe defaults
  double _baseFee = 1200;
  double _perKmFee = 200;
  double _distanceThresholdKm = 5;
  double _maxTierKm = 15;
  double _flatFeeAboveMaxKm = 3500;
  double _heavyWeightKg = 10;
  bool _pricingLoaded = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.user?.phone != null && auth.user!.phone!.isNotEmpty) {
      _pickupPhoneController.text = auth.user!.phone!;
    }
    // Prefill sender name from user database
    if (auth.user != null) {
      final firstName = auth.user!.firstName ?? '';
      final lastName = auth.user!.lastName ?? '';
      final fullName = [firstName, lastName].where((e) => e.trim().isNotEmpty).join(' ').trim();
      if (fullName.isNotEmpty) {
        _senderNameController.text = fullName;
      }
    }
    // Fetch pricing from backend (admin-editable)
    _fetchPricing();
  }

  Future<void> _fetchPricing() async {
    try {
      final api = context.read<AuthProvider>().apiService;
      final response = await api.get('/api/pickup-orders/pricing');
      if (response['success'] == true && response['pricing'] != null) {
        final p = response['pricing'] as Map<String, dynamic>;
        setState(() {
          _baseFee = (p['base_fee'] as num?)?.toDouble() ?? 1200;
          _perKmFee = (p['per_km_fee'] as num?)?.toDouble() ?? 200;
          _distanceThresholdKm = (p['distance_threshold_km'] as num?)?.toDouble() ?? 5;
          _maxTierKm = (p['pricing_cap_km'] as num?)?.toDouble() ?? 15;
          _flatFeeAboveMaxKm = (p['pricing_cap_price'] as num?)?.toDouble() ?? 3500;
          _heavyWeightKg = (p['heavy_weight_kg'] as num?)?.toDouble() ?? 10;
          _pricingLoaded = true;
        });
      }
    } catch (e) {
      print('⚠️ Failed to fetch pickup pricing, using defaults: $e');
    }
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    _pickupPhoneController.dispose();
    _receiverNameController.dispose();
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
    if (!mounted) return;
    if (result != null && result is DeliveryAddress) {
      setState(() => _pickupAddress = result);
      _calculateRoadDistance();
    }
  }

  Future<void> _selectDropoffLocation() async {
    final result = await context.push('/location-picker');
    if (!mounted) return;
    if (result != null && result is DeliveryAddress) {
      setState(() => _dropoffAddress = result);
      _calculateRoadDistance();
    }
  }

  Future<void> _selectSchedule() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledPickupTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
              dayOverlayColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
              dayForegroundColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return isDark ? Colors.white : Colors.black87;
              }),
              yearForegroundColor: MaterialStateColor.resolveWith((states) {
                return isDark ? Colors.white : Colors.black87;
              }),
              surfaceTintColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledPickupTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
              dialBackgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
              dialHandColor: AppColors.primary,
              dialTextColor: isDark ? Colors.white : Colors.black87,
              entryModeIconColor: AppColors.primary,
              hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return isDark ? Colors.white70 : Colors.black54;
              }),
              hourMinuteColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppColors.primary;
                }
                return isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
              }),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null || !mounted) return;

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

  Future<void> _calculateRoadDistance() async {
    if (_pickupAddress == null || _dropoffAddress == null) {
      setState(() {
        _roadDistanceData = null;
        _isCalculatingDistance = false;
      });
      return;
    }

    setState(() => _isCalculatingDistance = true);

    try {
      // Use actual GPS position as starting point
      final position = Position(
        latitude: _pickupAddress!.latitude,
        longitude: _pickupAddress!.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      final result = await GoogleMapsService.getRoadDistance(
        userLocation: position,
        destinationLat: _dropoffAddress!.latitude,
        destinationLng: _dropoffAddress!.longitude,
      );

      if (!mounted) return;

      setState(() {
        _roadDistanceData = result;
        _isCalculatingDistance = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCalculatingDistance = false);
    }
  }

  double? _calculateDistanceKm() {
    if (_roadDistanceData != null) {
      return _roadDistanceData!['distanceKm'] as double?;
    }
    // Fallback to Haversine if API fails
    if (_pickupAddress == null || _dropoffAddress == null) return null;
    return calculateDistanceKm(
      _pickupAddress!.latitude,
      _pickupAddress!.longitude,
      _dropoffAddress!.latitude,
      _dropoffAddress!.longitude,
    ) * 1.4; // Apply road factor
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
    if (_senderNameController.text.trim().isEmpty) {
      _showSnack('Add sender name');
      return false;
    }
    if (_pickupPhoneController.text.trim().isEmpty) {
      _showSnack('Add sender phone number');
      return false;
    }
    if (_receiverNameController.text.trim().isEmpty) {
      _showSnack('Add receiver name');
      return false;
    }
    if (_dropoffPhoneController.text.trim().isEmpty) {
      _showSnack('Add receiver phone number');
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
      'personName': _senderNameController.text.trim(),
    };

    final dropoffLocation = {
      'address': _dropoffAddress!.fullAddress,
      'latitude': _dropoffAddress!.latitude,
      'longitude': _dropoffAddress!.longitude,
      'phoneNumber': _dropoffPhoneController.text.trim(),
      'notes': _buildLocationNotes(_dropoffAddress!),
      'personName': _receiverNameController.text.trim(),
    };

    final items = [
      {
        'id': 'package-1',
        'description': '$_selectedPackageType${_packageDescriptionController.text.trim().isNotEmpty ? ' - ${_packageDescriptionController.text.trim()}' : ''}',
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
    final result = await provider.createPickupOrder(
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

    final resultMap = result as Map<String, dynamic>?;
    final order = resultMap?['order'];
    if (order != null) {
      if (mounted) {
        final vendorCode = resultMap?['vendorCode']?.toString() ?? 'N/A';
        final customerCode = resultMap?['customerCode']?.toString() ?? 'N/A';
        final emailsSent = resultMap?['emailsSent'] as Map<String, dynamic>? ?? {};

        try {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.verified, color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  const Text('Order Confirmed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your order has been created successfully. Two verification codes have been generated:',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Vendor Pickup Code
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.7), width: 1),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'VENDOR PICKUP CODE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Colors.orange),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          vendorCode,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.orange,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Show this to the rider at pickup',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Customer Dropoff Code
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.7), width: 1),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'DELIVERY CODE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Colors.blue),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          customerCode,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.blue,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Verify with rider at delivery',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Email status
                  if (emailsSent['errors'] != null && (emailsSent['errors'] as List).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Codes not emailed. Check your email settings.',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '✓ Codes sent to your email',
                        style: TextStyle(fontSize: 11, color: Colors.green),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        } catch (e) {
          print('⚠️ Dialog error: $e');
        }
      }
      
      if (!mounted) return;
      
      // Show success snackbar first, then navigate
      _showSnack('Pickup order created successfully');
      
      // Small delay to ensure dialog is fully closed, then navigate
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      
      try {
        // Navigate to My Orders (Pickup tab) — use push so back works
        context.push('/my-orders');
      } catch (e) {
        // Fallback: go to home if push fails
        print('⚠️ Navigation error, going home: $e');
        if (mounted) context.go('/');
      }
    } else {
      if (!mounted) return;
      final errorMsg = provider.error ?? 'Failed to create pickup order. Please try again.';
      _showSnack(errorMsg);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFECECEC);
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text(
          'Ntwaza Now Pickup',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeaderRow('Pickup details', Icons.my_location, textColor, subtextColor),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                      )
                    : null,
                color: isDark ? null : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAddressTile(
                      title: 'Pickup location',
                      subtitle: _pickupAddress?.fullAddress ?? 'Choose pickup point',
                      onTap: _selectPickupLocation,
                      textColor: isDark ? Colors.white : Colors.black,
                      subtextColor: isDark ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _senderNameController,
                      label: 'Sender name',
                      hint: 'Full name',
                      textColor: isDark ? Colors.white : Colors.black,
                      subtextColor: isDark ? Colors.white70 : Colors.black54,
                      borderColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8),
                      prefixIcon: Icons.person_outline,
                      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _pickupPhoneController,
                      label: 'Sender phone number',
                      hint: 'e.g. 0780000000',
                      keyboardType: TextInputType.phone,
                      textColor: isDark ? Colors.white : Colors.black,
                      subtextColor: isDark ? Colors.white70 : Colors.black54,
                      borderColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8),
                      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
                    ),
                  ],
                ),
              ),
            ),
            _buildSectionHeaderRow('Dropoff details', Icons.flag_rounded, textColor, subtextColor),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                      )
                    : null,
                color: isDark ? null : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAddressTile(
                      title: 'Dropoff location',
                      subtitle: _dropoffAddress?.fullAddress ?? 'Choose destination',
                      onTap: _selectDropoffLocation,
                      textColor: isDark ? Colors.white : Colors.black,
                      subtextColor: isDark ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _receiverNameController,
                      label: 'Receiver name',
                      hint: 'Full name',
                      textColor: isDark ? Colors.white : Colors.black,
                      subtextColor: isDark ? Colors.white70 : Colors.black54,
                      borderColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8),
                      prefixIcon: Icons.person,
                      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _dropoffPhoneController,
                      label: 'Receiver phone number',
                      hint: 'e.g. 0780000000',
                      keyboardType: TextInputType.phone,
                      textColor: isDark ? Colors.white : Colors.black,
                      subtextColor: isDark ? Colors.white70 : Colors.black54,
                      borderColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8),
                      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeaderRow('Package details', Icons.inventory_2_outlined, textColor, subtextColor),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                      )
                    : null,
                color: isDark ? null : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPackageTypeSelector(isDark ? Colors.white : Colors.black, isDark ? Colors.white70 : Colors.black54, isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8)),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _packageDescriptionController,
                      label: 'Additional details',
                      hint: 'Optional notes about the package',
                      textColor: isDark ? Colors.white : Colors.black,
                      subtextColor: isDark ? Colors.white70 : Colors.black54,
                      borderColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8),
                      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
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
                            textColor: isDark ? Colors.white : Colors.black,
                            subtextColor: isDark ? Colors.white70 : Colors.black54,
                            borderColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8),
                            backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
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
                            textColor: isDark ? Colors.white : Colors.black,
                            subtextColor: isDark ? Colors.white70 : Colors.black54,
                            borderColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8),
                            backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
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
                      textColor: isDark ? Colors.white : Colors.black,
                      subtextColor: isDark ? Colors.white70 : Colors.black54,
                      borderColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8),
                      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _buildFeeRow(
                      textColor: isDark ? Colors.white : Colors.black,
                      subtextColor: isDark ? Colors.white70 : Colors.black54,
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
                        textColor: Colors.white,
                        subtextColor: Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildSectionHeaderRow('Schedule', Icons.schedule, textColor, subtextColor),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: const Text('Pickup time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(_scheduledPickupTime),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    trailing: TextButton(
                      onPressed: _selectSchedule,
                      child: const Text('Change', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            _buildSectionHeaderRow('Payment', Icons.payments_outlined, textColor, subtextColor),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                      )
                    : null,
                color: isDark ? null : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
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
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8), width: 1.5),
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                  dropdownColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
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
            _buildSectionHeaderRow('Notes (optional)', Icons.edit_note_outlined, textColor, subtextColor),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                      )
                    : null,
                color: isDark ? null : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildTextField(
                  controller: _notesController,
                  label: 'Additional notes',
                  hint: 'Pickup instructions or package details',
                  textColor: isDark ? Colors.white : Colors.black,
                  subtextColor: isDark ? Colors.white70 : Colors.black54,
                  borderColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8),
                  backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFEFF),
                  maxLines: 3,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                      )
                    : null,
                color: isDark ? null : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE3E5E8)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Estimated total', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w700)),
                    Text(
                      'RWF ${total.toStringAsFixed(0)}',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageTypeSelector(Color textColor, Color subtextColor, Color borderColor) {
    const packageTypes = ['Small box', 'Documents', 'Clothing', 'Electronics', 'Food', 'Books', 'Other'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dropdownBackground = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Package type',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedPackageType,
          items: packageTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type, style: TextStyle(color: textColor, fontSize: 14)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedPackageType = value);
            }
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: dropdownBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: TextStyle(color: textColor, fontSize: 14),
          dropdownColor: dropdownBackground,
        ),
      ],
    );
  }

  Widget _buildSectionHeaderRow(
    String title,
    IconData icon,
    Color textColor,
    Color subtextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
    String distanceLabel;
    Widget? distanceIcon;
    
    if (_isCalculatingDistance) {
      distanceLabel = 'Calculating road distance...';
      distanceIcon = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(accentColor),
        ),
      );
    } else if (distanceKm == null) {
      distanceLabel = 'Select pickup and dropoff to calculate';
      distanceIcon = null;
    } else {
      final isAccurate = _roadDistanceData?['isAccurate'] ?? false;
      distanceLabel = isAccurate 
          ? '${distanceKm.toStringAsFixed(1)} km (road distance)'
          : '${distanceKm.toStringAsFixed(1)} km (estimated)';
      distanceIcon = Icon(
        isAccurate ? Icons.verified : Icons.warning_amber_rounded,
        size: 14,
        color: isAccurate ? accentColor : Colors.orange,
      );
    }

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
                Row(
                  children: [
                    if (distanceIcon != null) ...[
                      distanceIcon,
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        distanceLabel,
                        style: TextStyle(color: subtextColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
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
    final surface = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final border = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE3E5E8);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0F0F),
                  Color(0xFF1A1A1A),
                ],
              )
            : null,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.location_on, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
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
    IconData? prefixIcon,
    Color? backgroundColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Match card background completely
    final bgColor = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: subtextColor.withOpacity(0.5), fontSize: 13),
        labelStyle: TextStyle(color: subtextColor, fontSize: 13, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: bgColor,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.primary, size: 20)
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Invisible borders
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
