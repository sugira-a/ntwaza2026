import 'package:flutter/material.dart';
import 'package:ntwaza/config/app_colors.dart';

/// Widget for verifying vendor pickup code or customer dropoff code
class CodeVerificationWidget extends StatefulWidget {
  final String orderId;
  final String codeType; // 'vendor_pickup' or 'customer_dropoff'
  final VoidCallback? onSuccess;
  final Function(String)? onError;
  final bool isLoading;

  const CodeVerificationWidget({
    Key? key,
    required this.orderId,
    required this.codeType,
    this.onSuccess,
    this.onError,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<CodeVerificationWidget> createState() => _CodeVerificationWidgetState();
}

class _CodeVerificationWidgetState extends State<CodeVerificationWidget> {
  late TextEditingController _codeController;
  bool _showError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleVerify() {
    final code = _codeController.text.trim();
    
    if (code.isEmpty) {
      setState(() {
        _showError = true;
        _errorMessage = 'Please enter the code';
      });
      return;
    }

    if (code.length != 4 || !RegExp(r'^\d{4}$').hasMatch(code)) {
      setState(() {
        _showError = true;
        _errorMessage = 'Code must be 4 digits';
      });
      return;
    }

    // Call the verification function passed from parent
    widget.onSuccess?.call();
  }

  String get _title {
    return widget.codeType == 'vendor_pickup' 
      ? 'Vendor Pickup Verification'
      : 'Customer Delivery Verification';
  }

  String get _description {
    return widget.codeType == 'vendor_pickup'
      ? 'Ask the vendor for their verification code'
      : 'Ask the customer for their delivery code';
  }

  Color get _accentColor {
    return widget.codeType == 'vendor_pickup'
      ? Colors.orange
      : Colors.blue;
  }

  IconData get _icon {
    return widget.codeType == 'vendor_pickup'
      ? Icons.storefront_rounded
      : Icons.home_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(_icon, color: _accentColor, size: 32),
              const SizedBox(height: 8),
              Text(
                _title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _accentColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Code Input Field
        TextField(
          controller: _codeController,
          enabled: !widget.isLoading,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: '0000',
            hintStyle: TextStyle(
              fontSize: 36,
              color: Colors.grey.withOpacity(0.3),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _showError ? Colors.red : Colors.grey.shade300,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _showError ? Colors.red : _accentColor,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _showError ? Colors.red : Colors.grey.shade300,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            counterText: '',
          ),
          onChanged: (_) {
            if (_showError) {
              setState(() => _showError = false);
            }
          },
        ),

        const SizedBox(height: 8),

        // Error Message
        if (_showError)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Verify Button
        FilledButton(
          onPressed: widget.isLoading ? null : _handleVerify,
          style: FilledButton.styleFrom(
            backgroundColor: _accentColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: widget.isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _accentColor.withOpacity(0.7),
                  ),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Verify Code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
        ),

        const SizedBox(height: 8),

        // Info message
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.codeType == 'vendor_pickup'
              ? '✓ This confirms you picked up the package from the vendor'
              : '✓ This confirms the customer received the package',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
