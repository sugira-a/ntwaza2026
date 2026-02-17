import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  final String? resetToken;
  const ResetPasswordScreen({super.key, this.email, this.resetToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.email != null && widget.email!.isNotEmpty) {
      _emailController.text = widget.email!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final api = Provider.of<AuthProvider>(context, listen: false).apiService;
      final response = await api.post('/api/auth/forgot-password/verify', {
        'email': _emailController.text.trim(),
        'code': _codeController.text.trim(),
        'password': _passwordController.text.trim(),
      });
      if (response['success'] == true) {
        setState(() {
          _message = 'Password reset successful!';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/login');
      } else {
        setState(() {
          _message = response['message'] ?? 'Failed to reset password.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to reset password. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;
    final bgColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/login'),
                    icon: Icon(Icons.arrow_back, color: theme.textColor),
                  ),
                  const Spacer(),
                  Text(
                    'NTWAZA',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: theme.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the verification code sent to your email',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.subtextColor,
                          ),
                        ),
                        
                        const SizedBox(height: 32),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: theme.textColor, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(color: theme.subtextColor, fontSize: 14),
                            filled: true,
                            fillColor: bgColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.green, width: 1.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your email';
                            if (!value.contains('@')) return 'Please enter a valid email';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: theme.textColor, fontSize: 16, letterSpacing: 2),
                          decoration: InputDecoration(
                            labelText: 'Verification Code',
                            labelStyle: TextStyle(color: theme.subtextColor, fontSize: 14),
                            filled: true,
                            fillColor: bgColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.green, width: 1.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter the code';
                            if (value.trim().length < 6) return 'Code must be 6 digits';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          style: TextStyle(color: theme.textColor, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            labelStyle: TextStyle(color: theme.subtextColor, fontSize: 14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: theme.subtextColor,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                            filled: true,
                            fillColor: bgColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.green, width: 1.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter a password';
                            if (value.length < 8) return 'At least 8 characters';
                            if (!value.contains(RegExp(r'[A-Z]'))) return 'Include an uppercase letter';
                            if (!value.contains(RegExp(r'[0-9]'))) return 'Include a number';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_showConfirmPassword,
                          style: TextStyle(color: theme.textColor, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: TextStyle(color: theme.subtextColor, fontSize: 14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: theme.subtextColor,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                            ),
                            filled: true,
                            fillColor: bgColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.green, width: 1.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please confirm password';
                            if (value != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: theme.textColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitNewPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(bgColor),
                                    ),
                                  )
                                : Text(
                                    'Reset Password',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: bgColor,
                                    ),
                                  ),
                          ),
                        ),
                        
                        if (_message != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _message!.contains('successful') ? Colors.green : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
