// lib/screens/customer/profile_screen.dart
// Modern 2026 Profile & Settings - All-in-One

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _accountExpanded = false;
  bool _settingsExpanded = false;
  bool _supportExpanded = false;
  bool _actionsExpanded = false;
  int _selectedNavIndex = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final colorScheme = theme.colorScheme;
    final pageColor = isDark ? const Color(0xFF121212) : Colors.white;
    final surfaceColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;
    final textMainColor = isDark ? Colors.white : Colors.black;
    final textSecondaryColor = isDark ? Colors.grey[300]! : Colors.grey[700]!;
    final avatarBgColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: pageColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with Profile Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: pageColor,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/');
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [pageColor, surfaceColor],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Profile Avatar
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: avatarBgColor,
                          border: Border.all(
                            color: isDark ? Colors.white : Colors.black,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getUserInitials(user),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: textMainColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getUserDisplayName(user),
                        style: theme.textTheme.headlineSmall?.copyWith(color: textMainColor, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'user@example.com',
                        style: theme.textTheme.bodySmall?.copyWith(color: textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Account Section
                _CollapsibleSection(
                  title: 'Account',
                  icon: Icons.person,
                  isExpanded: _accountExpanded,
                  onToggle: () => setState(() => _accountExpanded = !_accountExpanded),
                  cardColor: surfaceColor,
                  textColor: colorScheme.onSurface,
                  children: [
                    _SettingsTile(
                      icon: Icons.person_outline,
                      title: 'Edit Profile',
                      subtitle: 'Update your personal information',
                      onTap: () => _showEditProfileDialog(context),
                    ),
                    _SettingsTile(
                      icon: Icons.location_on_outlined,
                      title: 'Addresses',
                      subtitle: 'Manage delivery addresses',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address management coming soon')),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // App Settings Section
                _CollapsibleSection(
                  title: 'App Settings',
                  icon: Icons.settings,
                  isExpanded: _settingsExpanded,
                  onToggle: () => setState(() => _settingsExpanded = !_settingsExpanded),
                  cardColor: surfaceColor,
                  textColor: colorScheme.onSurface,
                  children: [
                    _SettingsTile(
                      icon: isDark ? Icons.light_mode : Icons.dark_mode,
                      title: 'Dark Mode',
                      subtitle: isDark ? 'Switch to light theme' : 'Switch to dark theme',
                      trailing: Switch(
                        value: isDark,
                        onChanged: (value) => themeProvider.toggleTheme(),
                      ),
                      onTap: () => themeProvider.toggleTheme(),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Support Section
                _CollapsibleSection(
                  title: 'Support',
                  icon: Icons.help_outline,
                  isExpanded: _supportExpanded,
                  onToggle: () => setState(() => _supportExpanded = !_supportExpanded),
                  cardColor: surfaceColor,
                  textColor: colorScheme.onSurface,
                  children: [
                    _SettingsTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      subtitle: 'FAQs and customer service',
                      onTap: () => context.push('/help-support'),
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'How we handle your data',
                        onTap: () => context.push('/privacy-policy'),
                    ),
                    _SettingsTile(
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      subtitle: 'Read our terms',
                        onTap: () => context.push('/terms-of-service'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Account Actions
                _CollapsibleSection(
                  title: 'Account Actions',
                  icon: Icons.exit_to_app,
                  isExpanded: _actionsExpanded,
                  onToggle: () => setState(() => _actionsExpanded = !_actionsExpanded),
                  cardColor: surfaceColor,
                  textColor: colorScheme.onSurface,
                  children: [
                    _SettingsTile(
                      icon: Icons.lock,
                      title: 'Change Password',
                      subtitle: 'Update your password',
                      iconColor: Colors.orange,
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                    _SettingsTile(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      iconColor: Colors.red,
                      onTap: () => _showLogoutDialog(context, authProvider),
                    ),
                  ],
                ),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final isDarkMode = themeProvider.isDarkMode;
          final cardColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
          final textColor = isDarkMode ? Colors.white : Colors.black;
          final subtextColor = isDarkMode ? Colors.grey[500]! : Colors.grey[600]!;

          return Container(
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0, textColor, subtextColor),
                    _buildNavItem(Icons.restaurant_outlined, Icons.restaurant, 'Restaurants', 1, textColor, subtextColor),
                    _buildNavItem(Icons.shopping_bag_outlined, Icons.shopping_bag, 'Markets', 2, textColor, subtextColor),
                    _buildNavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Cart', 3, textColor, subtextColor),
                    _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 4, textColor, subtextColor),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getUserDisplayName(UserModel? user) {
    if (user == null) return 'User';
    if (user.firstName != null && user.firstName!.isNotEmpty) {
      return user.lastName != null && user.lastName!.isNotEmpty
          ? '${user.firstName} ${user.lastName}'
          : user.firstName!;
    }
    return user.email.split('@')[0];
  }

  String _getUserInitials(UserModel? user) {
    if (user == null) return 'U';
    if (user.firstName != null && user.firstName!.isNotEmpty) {
      final first = user.firstName!.substring(0, 1).toUpperCase();
      final last = user.lastName != null && user.lastName!.isNotEmpty
          ? user.lastName!.substring(0, 1).toUpperCase()
          : '';
      return first + last;
    }
    return user.email.substring(0, 1).toUpperCase();
  }

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final nameController = TextEditingController(
      text: authProvider.user?.firstName ?? authProvider.user?.email.split('@')[0],
    );
    final lastNameController = TextEditingController(text: authProvider.user?.lastName);
    final phoneController = TextEditingController(text: authProvider.user?.phone ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          titleTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.w600),
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'First Name',
                  labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  prefixIcon: Icon(Icons.person, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  prefixIcon: Icon(Icons.person_outline, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Phone',
                  labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  prefixIcon: Icon(Icons.phone, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      
                      final success = await authProvider.updateProfile({
                        'first_name': nameController.text,
                        'last_name': lastNameController.text,
                        'phone': phoneController.text,
                      });
                      
                      if (mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(authProvider.error ?? 'Failed to update profile'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    final oldPasswordController = TextEditingController();
    final verificationCodeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool showOldPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;
    int step = 1; // Step 1: Enter old password → Step 2: Enter code + new password
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            step == 1 ? 'Change Password' : 'Enter Verification Code',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step == 1) ...[
                  Text(
                    'We\'ll send a verification code to your email to confirm it\'s you.',
                    style: TextStyle(color: subtextColor, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: oldPasswordController,
                    obscureText: !showOldPassword,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: TextStyle(color: subtextColor, fontSize: 14),
                      prefixIcon: Icon(Icons.lock_outline, color: subtextColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showOldPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: subtextColor, size: 20,
                        ),
                        onPressed: () => setState(() => showOldPassword = !showOldPassword),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined, color: Color(0xFF4CAF50), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Code sent! Check your email.',
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: verificationCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TextStyle(color: textColor, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      labelStyle: TextStyle(color: subtextColor, fontSize: 14),
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: !showNewPassword,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: TextStyle(color: subtextColor, fontSize: 14),
                      helperText: '8+ chars, 1 uppercase, 1 number',
                      helperStyle: TextStyle(color: subtextColor, fontSize: 11),
                      prefixIcon: Icon(Icons.lock_outline, color: subtextColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: subtextColor, size: 20,
                        ),
                        onPressed: () => setState(() => showNewPassword = !showNewPassword),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !showConfirmPassword,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: TextStyle(color: subtextColor, fontSize: 14),
                      prefixIcon: Icon(Icons.lock_outline, color: subtextColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: subtextColor, size: 20,
                        ),
                        onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            if (step == 2)
              TextButton(
                onPressed: () => setState(() { step = 1; errorMessage = null; }),
                child: Text('Back', style: TextStyle(color: subtextColor)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: subtextColor)),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                setState(() => errorMessage = null);
                final authProvider = context.read<AuthProvider>();

                if (step == 1) {
                  // Step 1: Validate old password and request verification code
                  if (oldPasswordController.text.trim().isEmpty) {
                    setState(() => errorMessage = 'Please enter your current password');
                    return;
                  }
                  setState(() => isLoading = true);
                  try {
                    final response = await authProvider.apiService.post(
                      '/api/auth/request-password-change-code',
                      {'old_password': oldPasswordController.text},
                    );
                    if (response['success'] == true) {
                      setState(() { step = 2; isLoading = false; });
                    } else {
                      setState(() {
                        errorMessage = response['error'] ?? 'Incorrect password';
                        isLoading = false;
                      });
                    }
                  } catch (e) {
                    setState(() {
                      errorMessage = 'Failed to send code. Try again.';
                      isLoading = false;
                    });
                  }
                } else {
                  // Step 2: Verify code + change password
                  final code = verificationCodeController.text.trim();
                  final newPass = newPasswordController.text;
                  final confirmPass = confirmPasswordController.text;

                  if (code.isEmpty || code.length < 6) {
                    setState(() => errorMessage = 'Enter the 6-digit code');
                    return;
                  }
                  if (newPass.isEmpty) {
                    setState(() => errorMessage = 'Enter a new password');
                    return;
                  }
                  if (newPass.length < 8) {
                    setState(() => errorMessage = 'Password must be at least 8 characters');
                    return;
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(newPass)) {
                    setState(() => errorMessage = 'Password must contain an uppercase letter');
                    return;
                  }
                  if (!RegExp(r'[0-9]').hasMatch(newPass)) {
                    setState(() => errorMessage = 'Password must contain a number');
                    return;
                  }
                  if (newPass != confirmPass) {
                    setState(() => errorMessage = 'Passwords do not match');
                    return;
                  }

                  setState(() => isLoading = true);
                  try {
                    final response = await authProvider.apiService.post(
                      '/api/auth/verify-and-change-password',
                      {
                        'verification_code': code,
                        'new_password': newPass,
                      },
                    );
                    if (response['success'] == true) {
                      Navigator.pop(dialogContext);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Password changed successfully!'),
                            backgroundColor: Color(0xFF4CAF50),
                          ),
                        );
                      }
                    } else {
                      setState(() {
                        errorMessage = response['error'] ?? 'Failed to change password';
                        isLoading = false;
                      });
                    }
                  } catch (e) {
                    setState(() {
                      errorMessage = 'Failed to change password. Try again.';
                      isLoading = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(step == 1 ? 'Send Code' : 'Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        titleTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.w600),
        title: const Text('Logout'),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          ),
          ElevatedButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pop(context);
              context.go('/');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedNavIndex = index);
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/');
        break;
      case 2:
        context.go('/');
        break;
      case 3:
        context.go('/cart');
        break;
      case 4:
        // Already on profile
        break;
    }
  }

  Widget _buildNavItem(IconData outlinedIcon, IconData filledIcon, String label, int index, Color textColor, Color subtextColor) {
    final isSelected = _selectedNavIndex == index;
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    
    return InkWell(
      onTap: () => _onNavItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected ? (isDarkMode ? Colors.black : Colors.black) : subtextColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? (isDarkMode ? Colors.black : Colors.black) : subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

class _CollapsibleSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final Color? cardColor;
  final Color? textColor;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
    this.cardColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final colorScheme = theme.colorScheme;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final iconBgColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final cardBgColor = isDarkMode ? Colors.grey[900]! : Colors.white;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      color: cardBgColor,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: textColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Column(children: children),
                ),
              ],
            ),
            crossFadeState: isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final colorScheme = theme.colorScheme;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final resolvedIconColor = iconColor ?? textColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: resolvedIconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: resolvedIconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) 
                trailing!
              else
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final String type;
  final String details;
  final IconData icon;

  const _PaymentCard({
    required this.type,
    required this.details,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    return Card(
      color: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(type, style: TextStyle(color: textColor)),
        subtitle: Text(details, style: TextStyle(color: subtextColor)),
        trailing: Icon(Icons.chevron_right, color: subtextColor),
      ),
    );
  }
}
