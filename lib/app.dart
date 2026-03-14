import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

/// Custom page transitions that enable swipe-back gesture on all platforms
class _SwipeBackPageTransitionsTheme extends PageTransitionsTheme {
  const _SwipeBackPageTransitionsTheme();

  @override
  Map<TargetPlatform, PageTransitionsBuilder> get builders => const {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(), // iOS-style swipe back
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
  };
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    // Get the base theme and add swipe-back transitions
    final baseTheme = AppTheme.light();
    final themeWithSwipeBack = baseTheme.copyWith(
      pageTransitionsTheme: const _SwipeBackPageTransitionsTheme(),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "NTWAZA",
      theme: themeWithSwipeBack,
      scrollBehavior: const _NoScrollbarBehavior(),
      routerConfig: AppRouter.router,
    );
  }
}
