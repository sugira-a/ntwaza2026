import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Lightweight connectivity checker — no extra packages needed.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  bool _lastKnownStatus = true;
  bool get isOnline => _lastKnownStatus;

  /// Quick check: try to resolve a well-known hostname.
  Future<bool> checkConnectivity() async {
    if (kIsWeb) {
      // On web, we cannot use dart:io DNS lookup — assume online and let
      // the HTTP layer surface errors.
      _lastKnownStatus = true;
      return true;
    }

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateStatus(online);
      return online;
    } on SocketException catch (_) {
      _updateStatus(false);
      return false;
    } on TimeoutException catch (_) {
      _updateStatus(false);
      return false;
    } catch (_) {
      _updateStatus(false);
      return false;
    }
  }

  void _updateStatus(bool online) {
    if (_lastKnownStatus != online) {
      _lastKnownStatus = online;
      _connectivityController.add(online);
    }
  }

  /// Returns `true` if the error looks like a network/connectivity issue.
  static bool isNetworkError(dynamic error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('connection timed out') ||
        msg.contains('network is unreachable') ||
        msg.contains('no internet') ||
        msg.contains('failed to fetch') ||
        msg.contains('clientexception') ||
        msg.contains('handshake') ||
        msg.contains('errno = 7') ||
        msg.contains('errno = 101') ||
        msg.contains('errno = 110') ||
        msg.contains('no address associated') ||
        msg.contains('no route to host');
  }

  void dispose() {
    _connectivityController.close();
  }
}
