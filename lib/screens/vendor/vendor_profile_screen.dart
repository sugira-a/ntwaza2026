// lib/screens/vendor/vendor_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key});

  // Neutral palette
  static const Color primaryColor = Color(0xFF111111);
  static const Color primaryLight = Color(0xFFDADDE2);
  static const Color darkGray = Color(0xFF0B0B0B);
  static const Color lightGray = Color(0xFFDADDE2);
  static const Color accentGreen = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDarkMode;
    final user = authProvider.user;

    final backgroundColor = isDark ? const Color(0xFF202124) : const Color(0xFFDADDE2);
    final cardColor = isDark ? const Color(0xFF202124) : const Color(0xFFDADDE2);
    final textColor = isDark ? Colors.white : darkGray;
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF202124) : Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              }
            },
          ),
          title: Text(
            'Profile & Settings',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'No user data available',
            style: TextStyle(color: subtextColor, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile & Settings',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header - Compact & Clean
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF050505),
                    Color(0xFF1B1B1B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -8,
                    top: -20,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentGreen.withOpacity(0.28),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: const Icon(
                          Icons.store_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.businessName ?? user.email.split('@')[0] ?? 'Vendor',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

            // Business Information
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12),
                collapsedIconColor: textColor,
                iconColor: textColor,
                title: Text(
                  'Business Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                children: [
                  _buildInfoTile(
                    icon: Icons.badge_rounded,
                    title: 'Vendor ID',
                    value: user.id != null ? 'Vendor #${user.id}' : 'Not assigned',
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons.phone_rounded,
                    title: 'Phone',
                    value: user.phone ?? 'Not provided',
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons.location_on_rounded,
                    title: 'Address',
                    value: user.businessAddress ?? user.address ?? 'Not provided',
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons.category_rounded,
                    title: 'Business Type',
                    value: user.businessType ?? user.vendorType ?? 'Not provided',
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Performance Stats
            Text(
              'Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Rating',
                    value: '${user.avgRating?.toStringAsFixed(1) ?? "N/A"}',
                    icon: Icons.star_rounded,
                    color: isDark ? Colors.amber[300]! : Colors.amber[600]!,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Reviews',
                    value: '${user.totalReviews ?? 0}',
                    icon: Icons.rate_review_rounded,
                    color: isDark ? Colors.green[300]! : Colors.green[700]!,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Settings
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.5,
              ),
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
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),

            const SizedBox(height: 12),

            _buildSettingTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              isDark: isDark,
              onTap: () => _showChangePasswordDialog(
                context,
                authProvider,
                cardColor,
                textColor,
                subtextColor,
              ),
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      'About Ntwaza Vendor',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.store_rounded,
                          size: 64,
                          color: primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ntwaza Vendor App',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Manage your business, track orders, and grow your revenue with Ntwaza.',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              cardColor: cardColor,
              textColor: textColor,
              subtextColor: subtextColor,
              iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),

            const SizedBox(height: 28),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final screenContext = context;
                  final shouldLogout = await showDialog<bool>(
                    context: screenContext,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        'Are you sure you want to logout from your account?',
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: subtextColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Logout',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.red, width: 1),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : const Color(0xFFDADDE2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : const Color(0xFFDADDE2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subtextColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
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
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
    required Color iconColor,
  }) {
    return Material(
      color: isDark ? Colors.transparent : const Color(0xFFDADDE2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: subtextColor,
                ),
            ],
          ),
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
                        borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
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
                        borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
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
                        borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
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
                        borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
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
                child: Text('Back', style: TextStyle(color: subtextColor, fontWeight: FontWeight.w700)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: subtextColor, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                setState(() => errorMessage = null);

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
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password changed successfully!'),
                          backgroundColor: Color(0xFF4CAF50),
                        ),
                      );
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      step == 1 ? 'Send Code' : 'Change Password',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        ),
      ),
    );
  }
}