// lib/screens/admin/admin_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  static const Color accentGreen = Color(0xFF22C55E);
  static const Color primaryColor = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDarkMode;
    final user = authProvider.user;

    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F2F4);
    final cardColor = isDark ? const Color(0xFF222222) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: false,
          title: Text(
            'Profile',
            style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ),
        body: Center(child: Text('No user data available', style: TextStyle(color: subtextColor, fontSize: 16))),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Text(
          'Profile & Settings',
          style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF050505), Color(0xFF1B1B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -8, top: -20,
                    child: Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [accentGreen.withOpacity(0.28), Colors.transparent]),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.firstName ?? 'Admin',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Administrator',
                                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account Info
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12),
                collapsedIconColor: textColor,
                iconColor: textColor,
                title: Text(
                  'Account Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
                ),
                children: [
                  _buildInfoTile(
                    icon: Icons.badge_rounded,
                    title: 'Admin ID',
                    value: 'Admin #${user.id ?? "N/A"}',
                    isDark: isDark, cardColor: cardColor, textColor: textColor, subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons.email_rounded,
                    title: 'Email',
                    value: user.email,
                    isDark: isDark, cardColor: cardColor, textColor: textColor, subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons.phone_rounded,
                    title: 'Phone',
                    value: user.phone ?? 'Not provided',
                    isDark: isDark, cardColor: cardColor, textColor: textColor, subtextColor: subtextColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Settings
            Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
            ),
            const SizedBox(height: 16),

            _buildSettingTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark Mode',
              isDark: isDark,
              trailing: Switch(
                value: isDark,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeColor: primaryColor,
                activeTrackColor: primaryColor.withOpacity(0.3),
              ),
              onTap: () => themeProvider.toggleTheme(),
              cardColor: cardColor, textColor: textColor, subtextColor: subtextColor,
            ),

            const SizedBox(height: 12),

            _buildSettingTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              isDark: isDark,
              onTap: () => _showChangePasswordDialog(context, authProvider, cardColor, textColor, subtextColor),
              cardColor: cardColor, textColor: textColor, subtextColor: subtextColor,
            ),

            const SizedBox(height: 12),

            _buildSettingTile(
              icon: Icons.info_outline_rounded,
              title: 'About',
              isDark: isDark,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('About NTWAZA Delivery', style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 20)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, size: 64, color: primaryColor),
                        const SizedBox(height: 16),
                        Text('NTWAZA Delivery Admin Panel', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('Version 1.0.0', style: TextStyle(color: subtextColor, fontSize: 14)),
                        const SizedBox(height: 16),
                        Text(
                          'Manage vendors, riders, orders and finances with the NTWAZA Delivery Admin Dashboard.',
                          style: TextStyle(color: subtextColor, fontSize: 13, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close', style: TextStyle(color: accentGreen, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                );
              },
              cardColor: cardColor, textColor: textColor, subtextColor: subtextColor,
            ),

            const SizedBox(height: 28),

            // Logout
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final screenContext = context;
                  final shouldLogout = await showDialog<bool>(
                    context: screenContext,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text('Logout', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: textColor, letterSpacing: -0.5)),
                        ],
                      ),
                      content: Text('Are you sure you want to logout from your admin account?', style: TextStyle(color: subtextColor, fontSize: 15, height: 1.4)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text('Cancel', style: TextStyle(color: subtextColor, fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        ),
                      ],
                      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    ),
                  );
                  if (shouldLogout == true && screenContext.mounted) {
                    await authProvider.logout();
                    if (screenContext.mounted) screenContext.go('/login');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.red, width: 1)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final iconColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final iconColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222222) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700))),
            trailing ?? Icon(Icons.chevron_right_rounded, color: subtextColor),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    AuthProvider authProvider,
    Color cardColor,
    Color textColor,
    Color subtextColor,
  ) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Change Password', style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PasswordField(controller: currentPasswordController, hint: 'Current Password', isDark: isDark),
                  const SizedBox(height: 12),
                  _PasswordField(controller: newPasswordController, hint: 'New Password', isDark: isDark),
                  const SizedBox(height: 12),
                  _PasswordField(controller: confirmPasswordController, hint: 'Confirm New Password', isDark: isDark),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: TextStyle(color: subtextColor, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (newPasswordController.text != confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Passwords do not match'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      return;
                    }
                    try {
                      await authProvider.changePassword(
                        currentPasswordController.text,
                        newPasswordController.text,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Password changed successfully'),
                            backgroundColor: accentGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            );
          },
        );
      },
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;

  const _PasswordField({required this.controller, required this.hint, required this.isDark});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      style: TextStyle(color: widget.isDark ? Colors.white : const Color(0xFF0B0B0B)),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: widget.isDark ? Colors.white38 : Colors.black38),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
