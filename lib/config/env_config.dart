/// Environment configuration for API keys.
///
/// Keys are injected at build time via --dart-define flags:
///   flutter run \
///     --dart-define=GOOGLE_MAPS_WEB_KEY=AIza... \
///     --dart-define=GOOGLE_MAPS_ANDROID_KEY=AIza... \
///     --dart-define=GOOGLE_MAPS_IOS_KEY=AIza...
///
/// For convenience during development, create a `.env.local` file
/// (git-ignored) at the project root and use a helper script.
library;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class EnvConfig {
  EnvConfig._();

  // Injected via --dart-define at build time
  static const String googleMapsWebKey =
      String.fromEnvironment('GOOGLE_MAPS_WEB_KEY');
  static const String googleMapsAndroidKey =
      String.fromEnvironment('GOOGLE_MAPS_ANDROID_KEY');
  static const String googleMapsIosKey =
      String.fromEnvironment('GOOGLE_MAPS_IOS_KEY');

  /// Returns the correct Google Maps API key for the current platform.
  static String get googleMapsApiKey {
    if (kIsWeb) return googleMapsWebKey;

    try {
      // ignore: avoid_classes_with_only_static_members
      final platform = _PlatformHelper.operatingSystem;
      if (platform == 'android') return googleMapsAndroidKey;
      if (platform == 'ios') return googleMapsIosKey;
    } catch (_) {
      // Platform not available – fall back to web key
    }

    return googleMapsWebKey;
  }
}

/// Thin wrapper so `dart:io` is never imported on web.
class _PlatformHelper {
  static String get operatingSystem {
    // dart:io Platform is not available on web; this getter is only
    // reached on mobile/desktop where the import succeeds at runtime.
    // ignore: undefined_prefixed_name
    return _operatingSystem();
  }

  static String _operatingSystem() {
    // Use foundation's defaultTargetPlatform instead of dart:io
    // to stay web-compatible.
    return kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            _ => 'unknown',
          };
  }
}
