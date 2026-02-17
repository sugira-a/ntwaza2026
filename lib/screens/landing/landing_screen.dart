import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/customer/customer_home_content.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

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

        // Show the same landing screen whether logged in or not
        return const CustomerHomeContent();
      },
    );
  }
}
