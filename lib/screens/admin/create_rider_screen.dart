import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rider_provider.dart';

class CreateRiderScreen extends StatefulWidget {
  const CreateRiderScreen({super.key});

  @override
  State<CreateRiderScreen> createState() => _CreateRiderScreenState();
}

class _CreateRiderScreenState extends State<CreateRiderScreen> {
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
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _vehicleCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'vehicle': _vehicleCtrl.text.trim(),
      'license_number': _licenseCtrl.text.trim(),
      'role': 'rider',
    };

    final prov = context.read<RiderProvider>();
    final ok = await prov.createRider(data);
    setState(() => _isSubmitting = false);

    if (ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rider created successfully')));
      Navigator.pop(context, true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${prov.error}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? pureBlack : const Color(0xFFDADDE2);
    final cardColor = isDark ? cardDark : Colors.white;
    final textColor = isDark ? pureWhite : pureBlack;
    final subtextColor = isDark ? Colors.white70 : mutedGray;
    final borderColor = isDark ? borderDark : borderGray;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Create Rider'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentGreen, width: 1.5)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentGreen, width: 1.5)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email required';
                          final email = v.trim();
                          if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentGreen, width: 1.5)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Phone required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _vehicleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Vehicle (e.g., Bike, Motorcycle)',
                          prefixIcon: const Icon(Icons.directions_bike),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentGreen, width: 1.5)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _licenseCtrl,
                        decoration: InputDecoration(
                          labelText: 'License number (optional)',
                          prefixIcon: const Icon(Icons.badge),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentGreen, width: 1.5)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSubmitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Rider', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Riders will receive an invitation email with next steps (backend).',
              style: TextStyle(color: subtextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
