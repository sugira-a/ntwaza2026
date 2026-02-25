import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

/// Custom scroll behavior that hides scrollbar indicators on all screens
class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // No scrollbar indicator
  }
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "Ntwaza",
      theme: AppTheme.light(),
      scrollBehavior: const _NoScrollbarBehavior(),
      routerConfig: AppRouter.router,
    );
  }
}
