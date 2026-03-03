// lib/screens/customer/profile_screen.dart
// Modern 2026 Customer Profile - Clean & Professional

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_model.dart';
import '../../services/api/api_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color accentGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDarkMode;
    final user = authProvider.user;

    final backgroundColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111111);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(context, isDark, textColor),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline_rounded, size: 40, color: subtextColor),
              const SizedBox(height: 10),
              Text('Login to view profile', style: TextStyle(color: subtextColor, fontSize: 14)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Login', style: TextStyle(color: accentGreen, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(context, isDark, textColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            _buildProfileCard(user, isDark, cardColor, textColor, subtextColor),
            
            const SizedBox(height: 20),

            // Account Section
            _buildSectionTitle('Account', textColor),
            const SizedBox(height: 6),
            _buildSettingTile(
              icon: Icons.person_outline_rounded,
              title: 'Edit Profile',
              subtitle: 'Update your personal info',
              onTap: () => _showEditProfileDialog(context, authProvider, isDark, cardColor, textColor, subtextColor),
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: accentGreen,
              isDark: isDark,
            ),
            _buildSettingTile(
              icon: Icons.location_on_outlined,
              title: 'Addresses',
              subtitle: 'Manage delivery addresses',
              onTap: () => context.push('/location-picker'),
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: Colors.blue,
              isDark: isDark,
            ),
            _buildSettingTile(
              icon: Icons.receipt_long_outlined,
              title: 'Orders',
              subtitle: 'View past orders',
              onTap: () => context.push('/my-orders'),
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: Colors.orange,
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Settings Section
            _buildSectionTitle('Settings', textColor),
            const SizedBox(height: 6),
            _buildSettingTile(
              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              title: 'Appearance',
              subtitle: isDark ? 'Switch to light theme' : 'Switch to dark theme',
              trailing: Switch(
                value: isDark,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeColor: accentGreen,
              ),
              onTap: () => themeProvider.toggleTheme(),
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: isDark ? Colors.amber : Colors.indigo,
              isDark: isDark,
            ),
            _buildSettingTile(
              icon: Icons.lock_outline_rounded,
              title: 'Password',
              subtitle: 'Update your password',
              onTap: () => _showChangePasswordDialog(context, authProvider, cardColor, textColor, subtextColor, isDark),
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: Colors.purple,
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Support Section
            _buildSectionTitle('Support', textColor),
            const SizedBox(height: 6),
            _buildSettingTile(
              icon: Icons.help_outline_rounded,
              title: 'Help',
              subtitle: 'FAQs and customer service',
              onTap: () => context.push('/help-support'),
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: Colors.teal,
              isDark: isDark,
            ),
            _buildSettingTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              subtitle: 'How we handle your data',
              onTap: () => context.push('/privacy-policy'),
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: Colors.grey,
              isDark: isDark,
            ),
            _buildSettingTile(
              icon: Icons.description_outlined,
              title: 'Terms',
              subtitle: 'Read our terms',
              onTap: () => context.push('/terms-of-service'),
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: Colors.grey,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // Logout
            Material(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => _showLogoutDialog(context, authProvider, cardColor, textColor, subtextColor),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red[400], size: 20),
                      const SizedBox(width: 14),
                      Text('Logout', style: TextStyle(color: Colors.red[400], fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // App Version
            Center(
              child: Text(
                'v1.0.0',
                style: TextStyle(color: subtextColor.withOpacity(0.5), fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark, Color textColor) {
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardColor = isDark ? const Color(0xFF141414) : Colors.white;
    final authProvider = context.read<AuthProvider>();
    
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
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
      title: Text(
        'Profile',
        style: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: textColor),
          color: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          offset: const Offset(0, 45),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditProfileDialog(context, authProvider, isDark, cardColor, textColor, subtextColor);
                break;
              case 'orders':
                context.push('/my-orders');
                break;
              case 'help':
                context.push('/help-support');
                break;
              case 'about':
                _showAboutDialog(context, isDark, cardColor, textColor, subtextColor);
                break;
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20, color: textColor),
                  const SizedBox(width: 12),
                  Text('Edit Profile', style: TextStyle(color: textColor)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'orders',
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 20, color: textColor),
                  const SizedBox(width: 12),
                  Text('My Orders', style: TextStyle(color: textColor)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help_outline, size: 20, color: textColor),
                  const SizedBox(width: 12),
                  Text('Help Center', style: TextStyle(color: textColor)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'about',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: textColor),
                  const SizedBox(width: 12),
                  Text('About', style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context, bool isDark, Color cardColor, Color textColor, Color subtextColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu, color: accentGreen, size: 24),
            ),
            const SizedBox(width: 12),
            Text('Ntwaza', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0', style: TextStyle(color: subtextColor, fontSize: 14)),
            const SizedBox(height: 12),
            Text(
              'Ntwaza is your go-to food delivery app in Kigali. Order from your favorite restaurants and get fast delivery to your doorstep.',
              style: TextStyle(color: textColor, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text('© 2026 Ntwaza. All rights reserved.', style: TextStyle(color: subtextColor, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: accentGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(UserModel user, bool isDark, Color cardColor, Color textColor, Color subtextColor) {
    final displayName = _getUserDisplayName(user);
    final initials = _getUserInitials(user);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF222222) : const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.phone != null && user.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.phone!,
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor.withOpacity(0.45),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
    required Color iconColor,
    required bool isDark,
    Widget? trailing,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: isDark ? Colors.white70 : const Color(0xFF333333), size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: subtextColor.withOpacity(0.4),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getUserDisplayName(UserModel user) {
    if (user.firstName != null && user.firstName!.isNotEmpty) {
      return user.lastName != null && user.lastName!.isNotEmpty
          ? '${user.firstName} ${user.lastName}'
          : user.firstName!;
    }
    return user.email.split('@')[0];
  }

  String _getUserInitials(UserModel user) {
    if (user.firstName != null && user.firstName!.isNotEmpty) {
      final first = user.firstName!.substring(0, 1).toUpperCase();
      final last = user.lastName != null && user.lastName!.isNotEmpty
          ? user.lastName!.substring(0, 1).toUpperCase()
          : '';
      return first + last;
    }
    return user.email.substring(0, 1).toUpperCase();
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider authProvider, bool isDark, Color cardColor, Color textColor, Color subtextColor) {
    final nameController = TextEditingController(text: authProvider.user?.firstName ?? '');
    final lastNameController = TextEditingController(text: authProvider.user?.lastName ?? '');
    final phoneController = TextEditingController(text: authProvider.user?.phone ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Profile', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, 'First Name', Icons.person_outline, isDark, textColor, subtextColor),
                const SizedBox(height: 14),
                _buildTextField(lastNameController, 'Last Name', Icons.person_outline, isDark, textColor, subtextColor),
                const SizedBox(height: 14),
                _buildTextField(phoneController, 'Phone', Icons.phone_outlined, isDark, textColor, subtextColor, keyboardType: TextInputType.phone),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: subtextColor)),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                setDialogState(() => isLoading = true);
                final success = await authProvider.updateProfile({
                  'first_name': nameController.text,
                  'last_name': lastNameController.text,
                  'phone': phoneController.text,
                });
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Profile updated' : 'Update failed'),
                      backgroundColor: success ? accentGreen : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isDark, Color textColor, Color subtextColor, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subtextColor, fontSize: 14),
        prefixIcon: Icon(icon, color: subtextColor, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accentGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider authProvider, Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    final oldPasswordController = TextEditingController();
    final verificationCodeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool showOldPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;
    int step = 1;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            step == 1 ? 'Change Password' : 'Enter Verification Code',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step == 1) ...[
                  Text(
                    'We\'ll send a verification code to your email.',
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
                        icon: Icon(showOldPassword ? Icons.visibility : Icons.visibility_off, color: subtextColor, size: 20),
                        onPressed: () => setState(() => showOldPassword = !showOldPassword),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: accentGreen, width: 1.5),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined, color: accentGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Code sent! Check your email.', style: TextStyle(color: textColor, fontSize: 13))),
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
                      labelStyle: TextStyle(color: subtextColor),
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: accentGreen, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: !showNewPassword,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: TextStyle(color: subtextColor),
                      helperText: '8+ chars, 1 uppercase, 1 number',
                      helperStyle: TextStyle(color: subtextColor, fontSize: 11),
                      prefixIcon: Icon(Icons.lock_outline, color: subtextColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(showNewPassword ? Icons.visibility : Icons.visibility_off, color: subtextColor, size: 20),
                        onPressed: () => setState(() => showNewPassword = !showNewPassword),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: accentGreen, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !showConfirmPassword,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: TextStyle(color: subtextColor),
                      prefixIcon: Icon(Icons.lock_outline, color: subtextColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(showConfirmPassword ? Icons.visibility : Icons.visibility_off, color: subtextColor, size: 20),
                        onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: accentGreen, width: 1.5),
                      ),
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
                
                if (step == 1) {
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
                        errorMessage = response['message'] ?? 'Invalid password';
                        isLoading = false;
                      });
                    }
                  } catch (e) {
                    setState(() { errorMessage = 'Failed to send code'; isLoading = false; });
                  }
                } else {
                  if (verificationCodeController.text.length != 6) {
                    setState(() => errorMessage = 'Enter 6-digit code');
                    return;
                  }
                  if (newPasswordController.text.length < 8) {
                    setState(() => errorMessage = 'Password must be 8+ characters');
                    return;
                  }
                  if (newPasswordController.text != confirmPasswordController.text) {
                    setState(() => errorMessage = 'Passwords don\'t match');
                    return;
                  }
                  setState(() => isLoading = true);
                  try {
                    final response = await authProvider.apiService.post(
                      '/api/auth/change-password-with-code',
                      {
                        'old_password': oldPasswordController.text,
                        'code': verificationCodeController.text,
                        'new_password': newPasswordController.text,
                      },
                    );
                    if (response['success'] == true) {
                      Navigator.pop(dialogContext);
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Password changed successfully'), backgroundColor: accentGreen),
                        );
                      }
                    } else {
                      setState(() {
                        errorMessage = response['message'] ?? 'Failed to change password';
                        isLoading = false;
                      });
                    }
                  } catch (e) {
                    setState(() { errorMessage = 'An error occurred'; isLoading = false; });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(step == 1 ? 'Continue' : 'Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider, Color cardColor, Color textColor, Color subtextColor) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Text('Logout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: textColor)),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: subtextColor, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: subtextColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              authProvider.logout();
              context.go('/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
