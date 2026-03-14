import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api/api_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _api = ApiService();
  final List<TextEditingController> _digitControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  int _resendCooldown = 0;
  Timer? _timer;

  static const _brand = Color(0xFF1B5E20);
  static const _brandLight = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _startCooldown(60);
  }

  @override
  void dispose() {
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _resendCooldown = seconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  String get _code => _digitControllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final code = _code;
    if (code.length != 6) {
      _showSnackBar('Enter all 6 digits', Colors.orange);
      return;
    }
    setState(() => _loading = true);

    try {
      final res = await _api.verifyEmail(email: widget.email, code: code);
      if (!mounted) return;

      if (res['verified'] == true || res['already_verified'] == true) {
        _showSnackBar('Email verified! Please log in.', Colors.green);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go('/login');
      } else {
        _showSnackBar(res['error'] ?? 'Verification failed', Colors.red);
        if (res['expired'] == true) {
          _clearCode();
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(_parseError(e.toString()), Colors.red);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await _api.resendOtp(email: widget.email);
      if (!mounted) return;
      _showSnackBar('New code sent to ${widget.email}', Colors.green);
      _clearCode();
      _startCooldown(60);
    } catch (e) {
      if (mounted) _showSnackBar('Failed to resend. Try again.', Colors.red);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _clearCode() {
    for (final c in _digitControllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  String _parseError(String e) {
    if (e.contains('Connection') || e.contains('Network') || e.contains('No internet')) return 'No internet connection. Please check your Wi-Fi or mobile data.';
    return e.replaceAll('Exception: ', '').replaceAll('Failed to perform POST request: ', '');
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final ts = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tp),
          onPressed: () => context.go('/register'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_brand, _brandLight]),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: _brand.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 28),

              // Title
              Text('Verify your email', style: TextStyle(
                color: tp, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5,
              )),
              const SizedBox(height: 8),
              Text('We sent a 6-digit code to', style: TextStyle(color: ts, fontSize: 14)),
              const SizedBox(height: 4),
              Text(widget.email, style: TextStyle(
                color: _brandLight, fontSize: 15, fontWeight: FontWeight.w700,
              )),

              const SizedBox(height: 36),

              // 6-digit OTP input boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => _otpBox(i, isDark, tp)),
              ),

              const SizedBox(height: 32),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 20),

              // Resend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Didn't receive it?  ", style: TextStyle(color: ts, fontSize: 13)),
                  GestureDetector(
                    onTap: _resendCooldown > 0 ? null : _resend,
                    child: _resending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _brandLight))
                        : Text(
                            _resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend code',
                            style: TextStyle(
                              color: _resendCooldown > 0 ? ts : _brandLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Back to login
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to login', style: TextStyle(color: _brandLight, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index, bool isDark, Color tp) {
    return Container(
      width: 46,
      height: 56,
      margin: EdgeInsets.only(right: index < 5 ? 8 : 0),
      child: TextField(
        controller: _digitControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(
          color: tp, fontSize: 22, fontWeight: FontWeight.w800,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brandLight, width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          // Auto-submit when all 6 filled
          if (_code.length == 6) {
            _verify();
          }
        },
      ),
    );
  }
}
