// lib/widgets/admin/modern_admin_header.dart
// Modern, Creative Admin Dashboard Header
// Features: Hamburger menu drawer, notification bell, dark/light mode + logout in drawer

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class ModernAdminHeader extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onNotifications;
  final int unreadNotifications;

  const ModernAdminHeader({
    super.key,
    required this.onNotifications,
    this.unreadNotifications = 0,
  });

  @override
  State<ModernAdminHeader> createState() => _ModernAdminHeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

class _ModernAdminHeaderState extends State<ModernAdminHeader>
    with TickerProviderStateMixin {
  late AnimationController _notificationIconController;

  @override
  void initState() {
    super.initState();
    _notificationIconController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _notificationIconController.dispose();
    super.dispose();
  }

  void _animateIcon(AnimationController controller) {
    controller.forward().then((_) {
      controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF0B0B0B),
                  const Color(0xFF1A1A1A),
                ]
              : [
                  const Color(0xFFFFFFFF),
                  const Color(0xFFFAFAFA),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.5)
                : Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Side - Logo/Title
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50),
                          const Color(0xFF45a049),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),

              // Right Side - Notification Bell + Hamburger Menu
              Row(
                children: [
                  // Notifications Button
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            _animateIcon(_notificationIconController);
                            widget.onNotifications();
                          },
                          child: ScaleTransition(
                            scale: Tween(begin: 1.0, end: 1.15)
                                .animate(CurvedAnimation(
                                  parent: _notificationIconController,
                                  curve: Curves.elasticOut,
                                )),
                            child: Icon(
                              Icons.notifications_rounded,
                              color: const Color(0xFFFF6B6B),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      if (widget.unreadNotifications > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B6B),
                                  Color(0xFFEF4444),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B6B).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.unreadNotifications > 9
                                  ? '9+'
                                  : '${widget.unreadNotifications}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  // Hamburger Menu
                  _HamburgerMenuButton(isDarkMode: isDarkMode),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Modern Hamburger Menu Drawer Button
class _HamburgerMenuButton extends StatefulWidget {
  final bool isDarkMode;

  const _HamburgerMenuButton({required this.isDarkMode});

  @override
  State<_HamburgerMenuButton> createState() => _HamburgerMenuButtonState();
}

class _HamburgerMenuButtonState extends State<_HamburgerMenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openDrawer() {
    if (_isDrawerOpen) return;
    
    _animController.forward();
    _isDrawerOpen = true;
    Scaffold.of(context).openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    // Check if drawer is open and reverse animation if not
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isDrawerOpen && !Scaffold.of(context).isEndDrawerOpen) {
        _isDrawerOpen = false;
        _animController.reverse();
      }
    });

    return GestureDetector(
      onTap: _openDrawer,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: AnimatedIcon(
          icon: AnimatedIcons.menu_close,
          progress: _animController,
          color: const Color(0xFF4CAF50),
          size: 24,
        ),
      ),
    );
  }
}
