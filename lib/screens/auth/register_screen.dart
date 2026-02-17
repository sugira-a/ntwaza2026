import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/api_service.dart';
import '../../services/local_storage.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  
  final _api = ApiService();
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Enter valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'At least 6 characters';
    return null;
  }

  String _parseRegistrationError(String error) {
    error = error.replaceAll('Exception: Failed to perform POST request: ', '')
                .replaceAll('Exception: API Error: ', '')
                .replaceAll('Exception: ', '');
    
    if (error.contains('already exists') || error.contains('Email already registered')) {
      return 'This email is already registered. Try logging in instead.';
    }
    if (error.contains('invalid email') || error.contains('Invalid email format')) {
      return 'Please enter a valid email address.';
    }
    if (error.contains('password') && error.contains('weak')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (error.contains('Network') || error.contains('Connection') || error.contains('Failed host lookup')) {
      return 'Network error. Please check your internet connection.';
    }
    if (error.contains('timeout') || error.contains('Timeout')) {
      return 'Request timeout. Please try again.';
    }
    if (error.contains('500') || error.contains('Internal Server Error')) {
      return 'Server error. Please try again later.';
    }
    if (error.contains('400') || error.contains('Bad Request')) {
      return 'Invalid information. Please check all fields.';
    }
    return error.isEmpty ? 'Registration failed. Please try again.' : error;
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showError('Passwords don\'t match');
      return;
    }
    
    setState(() => _loading = true);
    
    try {
      final response = await _api.registerCustomer(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      
      final token = response['access_token'];
      if (token == null) throw Exception('No token received');
      
      await LocalStorage.saveUser(
        'customer',
        token,
        _emailCtrl.text.trim(),
        '${_firstNameCtrl.text} ${_lastNameCtrl.text}'
      );
      
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        authProvider.apiService.setToken(token);
        await authProvider.initialize();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${_firstNameCtrl.text}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      _showError(_parseRegistrationError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required ThemeProvider theme,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool hasToggle = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
  }) {
    final isDark = theme.isDarkMode;
    final bgColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: theme.textColor, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.subtextColor, fontSize: 14),
        suffixIcon: hasToggle
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: theme.subtextColor,
                  size: 20,
                ),
                onPressed: onToggle,
              )
            : null,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;
    final bgColor = isDark ? Colors.black : Colors.white;
    
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Clean header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/'),
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

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign up to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.subtextColor,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Name row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _firstNameCtrl,
                              label: 'First Name',
                              theme: theme,
                              validator: (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _lastNameCtrl,
                              label: 'Last Name',
                              theme: theme,
                              validator: (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _emailCtrl,
                        label: 'Email',
                        theme: theme,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _phoneCtrl,
                        label: 'Phone Number',
                        theme: theme,
                        keyboardType: TextInputType.phone,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _passwordCtrl,
                        label: 'Password',
                        theme: theme,
                        obscureText: !_showPassword,
                        hasToggle: true,
                        onToggle: () => setState(() => _showPassword = !_showPassword),
                        validator: _validatePassword,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _confirmPasswordCtrl,
                        label: 'Confirm Password',
                        theme: theme,
                        obscureText: !_showConfirmPassword,
                        hasToggle: true,
                        onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Register button
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.textColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(bgColor),
                                  ),
                                )
                              : Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: bgColor,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Login link
                      Center(
                        child: GestureDetector(
                          onTap: () => context.go('/login'),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: theme.subtextColor, fontSize: 14),
                              children: [
                                const TextSpan(text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Sign In',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
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