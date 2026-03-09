// lib/screens/rider/rider_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class RiderProfileScreen extends StatelessWidget {
  const RiderProfileScreen({super.key});

  static const Color accentGreen = Color(0xFF22C55E);

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
    final iconColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text('Profile & Settings',
              style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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
        title: Text('Profile & Settings',
            style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header â€” gradient card
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
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 8)),
                ],
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
                  Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.firstName ?? 'Rider',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(user.email,
                            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Personal Information â€” collapsible
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12),
                collapsedIconColor: textColor,
                iconColor: textColor,
                title: Text('Personal Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5)),
                children: [
                  _buildInfoTile(Icons.badge_rounded, 'Rider ID',
                      user.riderId != null ? 'Rider #${user.riderId}' : 'Not assigned',
                      iconColor, textColor, subtextColor),
                  const SizedBox(height: 12),
                  _buildInfoTile(Icons.phone_rounded, 'Phone',
                      user.phone ?? 'Not provided', iconColor, textColor, subtextColor),
                  const SizedBox(height: 12),
                  _buildInfoTile(Icons.location_on_rounded, 'Address',
                      user.address ?? 'Not provided', iconColor, textColor, subtextColor),
                  const SizedBox(height: 12),
                  _buildInfoTile(Icons.two_wheeler_rounded, 'Vehicle',
                      user.vehicleType ?? 'Not provided', iconColor, textColor, subtextColor),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Performance
            Text('Performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _buildStatCard(
                'Rating', '${user.rating?.toStringAsFixed(1) ?? "N/A"}',
                Icons.star_rounded, isDark ? Colors.amber[300]! : Colors.amber[600]!, textColor, subtextColor, isDark,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                'Deliveries', '${user.completedDeliveries ?? 0}',
                Icons.two_wheeler_rounded, isDark ? Colors.green[300]! : Colors.green[700]!, textColor, subtextColor, isDark,
              )),
            ]),

            const SizedBox(height: 28),

            // Settings
            Text('Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5)),
            const SizedBox(height: 16),

            _buildSettingTile(Icons.dark_mode_rounded, 'Dark Mode',
                iconColor, textColor, subtextColor,
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) => themeProvider.toggleTheme(),
                  activeColor: Colors.black,
                  activeTrackColor: Colors.black.withOpacity(0.3),
                ),
                onTap: () => themeProvider.toggleTheme()),
            const SizedBox(height: 12),
            _buildSettingTile(Icons.lock_outline_rounded, 'Change Password',
                iconColor, textColor, subtextColor,
                onTap: () => _showChangePasswordDialog(context, authProvider, cardColor, textColor, subtextColor)),
            const SizedBox(height: 12),
            _buildSettingTile(Icons.info_outline_rounded, 'About',
                iconColor, textColor, subtextColor,
                onTap: () => _showAboutDialog(context, cardColor, textColor, subtextColor)),

            const SizedBox(height: 28),

            // Logout
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleLogout(context, authProvider, cardColor, textColor, subtextColor),
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
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value,
      Color iconColor, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      Color textColor, Color subtextColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center,
            style: TextStyle(color: subtextColor, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(value, textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
      ]),
    );
  }

  Widget _buildSettingTile(IconData icon, String title,
      Color iconColor, Color textColor, Color subtextColor,
      {Widget? trailing, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(title,
                style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2))),
            if (trailing != null) trailing else Icon(Icons.arrow_forward_ios_rounded, size: 16, color: subtextColor),
          ]),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, Color card, Color text, Color sub) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('About Ntwaza', style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.two_wheeler_rounded, size: 64, color: text),
          const SizedBox(height: 16),
          Text('Ntwaza Rider App', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Version 1.0.0', style: TextStyle(color: sub, fontSize: 14)),
          const SizedBox(height: 16),
          Text('Deliver with confidence and earn more with Ntwaza.',
              style: TextStyle(color: sub, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthProvider authProvider, Color card, Color text, Color sub) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 12),
          Text('Logout', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: text, letterSpacing: -0.5)),
        ]),
        content: Text('Are you sure you want to logout?', style: TextStyle(color: sub, fontSize: 15, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text('Cancel', style: TextStyle(color: sub, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );
    if (shouldLogout == true && context.mounted) {
      await authProvider.logout();
      if (context.mounted) context.go('/login');
    }
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider authProvider, Color card, Color text, Color sub) {
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
          backgroundColor: card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            step == 1 ? 'Change Password' : 'Enter Verification Code',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: text),
          ),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (step == 1) ...[
                Text('We\'ll send a verification code to your email.',
                    style: TextStyle(color: sub, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextField(
                  controller: oldPasswordController,
                  obscureText: !showOldPassword,
                  style: TextStyle(color: text, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: TextStyle(color: sub, fontSize: 14),
                    prefixIcon: Icon(Icons.lock_outline, color: sub, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(showOldPassword ? Icons.visibility : Icons.visibility_off, color: sub, size: 20),
                      onPressed: () => setState(() => showOldPassword = !showOldPassword),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: sub.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.email, color: Color(0xFF22C55E), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Code sent! Check your email.', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w500))),
                  ]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: verificationCodeController,
                  keyboardType: TextInputType.number, maxLength: 6,
                  style: TextStyle(color: text, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Verification Code', labelStyle: TextStyle(color: sub, fontSize: 14),
                    counterText: '',
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: sub.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNewPassword,
                  style: TextStyle(color: text, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'New Password', labelStyle: TextStyle(color: sub, fontSize: 14),
                    helperText: '8+ chars, 1 uppercase, 1 number',
                    helperStyle: TextStyle(color: sub, fontSize: 11),
                    prefixIcon: Icon(Icons.lock_outline, color: sub, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(showNewPassword ? Icons.visibility : Icons.visibility_off, color: sub, size: 20),
                      onPressed: () => setState(() => showNewPassword = !showNewPassword),
                    ),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: sub.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  style: TextStyle(color: text, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password', labelStyle: TextStyle(color: sub, fontSize: 14),
                    prefixIcon: Icon(Icons.lock_outline, color: sub, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(showConfirmPassword ? Icons.visibility : Icons.visibility_off, color: sub, size: 20),
                      onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                    ),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: sub.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ]),
          ),
          actions: [
            if (step == 2)
              TextButton(
                onPressed: () => setState(() { step = 1; errorMessage = null; }),
                child: Text('Back', style: TextStyle(color: sub, fontWeight: FontWeight.w700)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: sub, fontWeight: FontWeight.w700)),
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
                      setState(() { errorMessage = response['error'] ?? 'Incorrect password'; isLoading = false; });
                    }
                  } catch (e) {
                    setState(() { errorMessage = 'Failed to send code. Try again.'; isLoading = false; });
                  }
                } else {
                  final code = verificationCodeController.text.trim();
                  final newPass = newPasswordController.text;
                  final confirmPass = confirmPasswordController.text;
                  if (code.isEmpty || code.length < 6) { setState(() => errorMessage = 'Enter the 6-digit code'); return; }
                  if (newPass.isEmpty) { setState(() => errorMessage = 'Enter a new password'); return; }
                  if (newPass.length < 8) { setState(() => errorMessage = 'Password must be at least 8 characters'); return; }
                  if (!RegExp(r'[A-Z]').hasMatch(newPass)) { setState(() => errorMessage = 'Must contain an uppercase letter'); return; }
                  if (!RegExp(r'[0-9]').hasMatch(newPass)) { setState(() => errorMessage = 'Must contain a number'); return; }
                  if (newPass != confirmPass) { setState(() => errorMessage = 'Passwords do not match'); return; }

                  setState(() => isLoading = true);
                  try {
                    final response = await authProvider.apiService.post(
                      '/api/auth/verify-and-change-password',
                      {'verification_code': code, 'new_password': newPass},
                    );
                    if (response['success'] == true) {
                      Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Color(0xFF22C55E)),
                        );
                      }
                    } else {
                      setState(() { errorMessage = response['error'] ?? 'Failed to change password'; isLoading = false; });
                    }
                  } catch (e) {
                    setState(() { errorMessage = 'Something went wrong. Try again.'; isLoading = false; });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(step == 1 ? 'Send Code' : 'Change Password', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
