/// Environment configuration for API keys.
///
/// Keys are injected at build time via --dart-define flags:
///   flutter run \
///     --dart-define=GOOGLE_MAPS_WEB_KEY=AIza... \
///     --dart-define=GOOGLE_MAPS_ANDROID_KEY=AIza... \
///     --dart-define=GOOGLE_MAPS_IOS_KEY=AIza...
///
/// For development without --dart-define, keys are imported from lib/.env.dart
/// (which is gitignored for security). Copy lib/.env.dart.example to lib/.env.dart
/// and add your actual keys.
library;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

// Import API keys from gitignored file (for development)
// If this import fails, copy .env.dart.example to .env.dart
import '../.env.dart' as env_keys;

class EnvConfig {
  EnvConfig._();

  // Injected via --dart-define at build time, falls back to .env.dart
  static const String googleMapsWebKey =
      String.fromEnvironment('GOOGLE_MAPS_WEB_KEY', defaultValue: '');
  static const String googleMapsAndroidKey =
      String.fromEnvironment('GOOGLE_MAPS_ANDROID_KEY', defaultValue: '');
  static const String googleMapsIosKey =
      String.fromEnvironment('GOOGLE_MAPS_IOS_KEY', defaultValue: '');

  /// Returns the correct Google Maps API key for the current platform.
  static String get googleMapsApiKey {
    // Try --dart-define keys first
    if (kIsWeb && googleMapsWebKey.isNotEmpty) return googleMapsWebKey;

    try {
      final platform = _PlatformHelper.operatingSystem;
      if (platform == 'android' && googleMapsAndroidKey.isNotEmpty) {
        return googleMapsAndroidKey;
      }
      if (platform == 'ios' && googleMapsIosKey.isNotEmpty) {
        return googleMapsIosKey;
      }
    } catch (_) {
      // Platform detection failed
    }

    // Fall back to .env.dart key (for development)
    return env_keys.googleMapsApiKey;
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
