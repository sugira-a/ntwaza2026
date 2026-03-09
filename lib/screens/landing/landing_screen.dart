import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/customer/customer_home_content.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<bool> _showExitConfirmation(BuildContext context) async {
    final isDarkMode = context.read<ThemeProvider>().isDarkMode;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFF2E7D32), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Exit App?',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to exit Ntwaza?',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      SystemNavigator.pop();
    }
    return false; // Always return false to prevent default back behavior
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Redirect vendors to their dashboard
        if (authProvider.isAuthenticated && authProvider.isVendor) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/vendor');
          });
        }

        // Wrap with PopScope for exit confirmation
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _showExitConfirmation(context);
            }
          },
          child: const CustomerHomeContent(),
        );
      },
    );
  }
}
